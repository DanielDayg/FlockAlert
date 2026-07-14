import Foundation
import CoreLocation

// Fetches ALPR/surveillance camera data from OpenStreetMap via Overpass API.
// The API requires a User-Agent header — requests without one return 406.

struct OverpassAPIClient {
    static let shared = OverpassAPIClient()

    // Ordered most-reliable first. The public Overpass API is heavily rate-limited,
    // so we spread requests across several mirrors and retry (see fetch()).
    private let endpoints = [
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass-api.de/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://overpass.openstreetmap.ru/api/interpreter"
    ]

    private var session: URLSession = {
        let config = URLSessionConfiguration.default
        // Fail fast: this data loads while the user watches the map. A mirror that
        // hasn't answered in ~18s isn't worth waiting on — another mirror (queried
        // in parallel) has almost certainly already responded.
        config.timeoutIntervalForRequest = 18
        config.timeoutIntervalForResource = 25
        config.httpAdditionalHeaders = [
            "User-Agent": "FlockAlert/1.0 (iOS privacy transparency app; contact@flockalert.app)",
            "Accept": "application/json"
        ]
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    /// Fetch all ALPR cameras within a bounding box. Used for tile-based loading.
    func fetchCameras(in region: MapRegion) async throws -> [OverpassCamera] {
        let query = buildQuery(region: region)
        return try await fetch(query: query)
    }

    /// Fetch cameras within a radius of a coordinate. Used for proximity pre-loading.
    func fetchCameras(around coordinate: CLLocationCoordinate2D, radiusMetres: Double = 5000) async throws -> [OverpassCamera] {
        let query = buildAroundQuery(coordinate: coordinate, radius: radiusMetres)
        return try await fetch(query: query)
    }

    // MARK: - Query Builders

    private func buildQuery(region: MapRegion) -> String {
        let bbox = "\(region.south),\(region.west),\(region.north),\(region.east)"
        return """
        [out:json][timeout:20][bbox:\(bbox)];
        (
          node["surveillance"="camera"]["operator"~"[Ff]lock",i];
          node["surveillance"="camera"]["brand"~"[Ff]lock",i];
          node["surveillance:type"="ALPR"];
          node["camera:type"="ALPR"];
          node["surveillance"="camera"]["surveillance:type"="ALPR"];
        );
        out body;
        """
    }

    private func buildAroundQuery(coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        return """
        [out:json][timeout:20];
        (
          node["surveillance"="camera"]["operator"~"[Ff]lock",i](around:\(Int(radius)),\(coordinate.latitude),\(coordinate.longitude));
          node["surveillance:type"="ALPR"](around:\(Int(radius)),\(coordinate.latitude),\(coordinate.longitude));
          node["camera:type"="ALPR"](around:\(Int(radius)),\(coordinate.latitude),\(coordinate.longitude));
          node["surveillance"="camera"]["brand"~"[Ff]lock",i](around:\(Int(radius)),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
    }

    // MARK: - Network

    private func fetch(query: String) async throws -> [OverpassCamera] {
        // Race all mirrors at once and take the first that answers. Querying them
        // sequentially (the old approach) meant one slow/throttled mirror could
        // stall a city load for over a minute before the next was even tried.
        // Firing them together returns as soon as the fastest healthy mirror
        // responds — typically a few seconds. One retry pass covers the case where
        // every mirror is momentarily rate-limited (429/504), which recovers fast.
        for attempt in 0..<2 {
            if let cameras = await raceMirrors(query: query) {
                return cameras
            }
            if attempt == 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        throw OverpassError.noEndpointAvailable
    }

    /// Queries every mirror concurrently and returns the first successful result,
    /// cancelling the rest. Returns nil only if all mirrors failed.
    private func raceMirrors(query: String) async -> [OverpassCamera]? {
        await withTaskGroup(of: [OverpassCamera]?.self) { group in
            for endpoint in endpoints {
                group.addTask {
                    // Swallow per-mirror failures so one bad mirror doesn't end the race.
                    try? await fetch(query: query, endpoint: endpoint)
                }
            }
            for await result in group {
                if let cameras = result {
                    group.cancelAll()
                    return cameras
                }
            }
            return nil
        }
    }

    private func fetch(query: String, endpoint: String) async throws -> [OverpassCamera] {
        guard let url = URL(string: endpoint) else { throw OverpassError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Encode query as URL param
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "data", value: query)]
        guard let finalURL = comps.url else { throw OverpassError.invalidURL }
        request = URLRequest(url: finalURL)
        request.setValue("FlockAlert/1.0 (iOS privacy transparency; contact@flockalert.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OverpassError.httpError(code)
        }

        let overpassResponse = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return overpassResponse.elements.compactMap { OverpassCamera(from: $0) }
    }
}

// MARK: - Response Models

struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

struct OverpassElement: Decodable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
}

struct OverpassCamera {
    let osmNodeID: Int64
    let latitude: Double
    let longitude: Double
    let tags: [String: String]

    init?(from element: OverpassElement) {
        guard let lat = element.lat, let lon = element.lon else { return nil }
        self.osmNodeID = element.id
        self.latitude = lat
        self.longitude = lon
        self.tags = element.tags ?? [:]
    }

    var operatorName: String? { tags["operator"] ?? tags["brand"] }
    var survType: String? { tags["surveillance:type"] ?? tags["camera:type"] }
    var direction: Double? {
        guard let d = tags["direction"] else { return nil }
        return compassToAngle(d)
    }
    var mountType: String? { tags["camera:mount"] ?? tags["mount"] }
    var note: String? { tags["note"] ?? tags["description"] }

    // Convert compass bearing string ("N", "NE", "90", etc.) to degrees
    private func compassToAngle(_ s: String) -> Double? {
        let map: [String: Double] = [
            "N": 0, "NNE": 22.5, "NE": 45, "ENE": 67.5,
            "E": 90, "ESE": 112.5, "SE": 135, "SSE": 157.5,
            "S": 180, "SSW": 202.5, "SW": 225, "WSW": 247.5,
            "W": 270, "WNW": 292.5, "NW": 315, "NNW": 337.5
        ]
        if let v = map[s.uppercased()] { return v }
        return Double(s)
    }

    /// Convert to app Camera model
    func toCamera() -> Camera {
        let mt: MountType
        switch mountType?.lowercased() {
        case "pole": mt = .utilityPole
        case "traffic_signal", "signal": mt = .trafficSignal
        case "building", "wall": mt = .building
        default: mt = .unknown
        }

        return Camera(
            latitude: latitude,
            longitude: longitude,
            facingDirection: direction,
            fieldOfViewDegrees: 75,
            ownerType: .unknown,
            ownerName: operatorName,
            mountType: mt,
            sourceType: .osmData,
            notes: note,
            osmNodeID: osmNodeID
        )
    }
}

struct MapRegion {
    let south: Double
    let west: Double
    let north: Double
    let east: Double
}

enum OverpassError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case noEndpointAvailable
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Overpass URL"
        case .httpError(let c): return "Overpass HTTP \(c)"
        case .noEndpointAvailable: return "All Overpass mirrors failed"
        case .decodingFailed: return "Failed to decode Overpass response"
        }
    }
}

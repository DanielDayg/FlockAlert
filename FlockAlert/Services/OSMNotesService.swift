import Foundation

/// Contributes camera reports back to OpenStreetMap the community-sanctioned way:
/// by creating an OSM *Note* — a "please verify this" flag for mappers — rather than
/// writing map nodes directly. Direct automated node edits of unverified, possibly
/// duplicate points would pollute the map and get the account blocked by OSM's Data
/// Working Group (which would poison the very data this app reads). Notes are exactly
/// what tools like StreetComplete and OsmAnd use for third-party reports.
struct OSMNotesService {
    static let shared = OSMNotesService()

    private let endpoint = "https://api.openstreetmap.org/api/0.6/notes"

    /// Creates an anonymous OSM Note at the coordinate. Best-effort — any failure is
    /// swallowed so a missed note never blocks the user's local report.
    @discardableResult
    func submitCameraNote(
        latitude: Double,
        longitude: Double,
        ownerType: String? = nil,
        notes: String? = nil
    ) async -> Bool {
        var text = "Possible ALPR / surveillance camera reported via the Flock Alert app. "
            + "Please verify on the ground and, if confirmed, tag as "
            + "man_made=surveillance, surveillance:type=ALPR."
        if let ownerType, !ownerType.isEmpty, ownerType.lowercased() != "unknown" {
            text += "\nReported operator/type: \(ownerType)."
        }
        if let notes, !notes.isEmpty {
            text += "\nReporter notes: \(notes)"
        }

        guard var comps = URLComponents(string: endpoint) else { return false }
        comps.queryItems = [
            URLQueryItem(name: "lat",  value: String(latitude)),
            URLQueryItem(name: "lon",  value: String(longitude)),
            URLQueryItem(name: "text", value: text)
        ]
        guard let url = comps.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("FlockAlert/1.0 (iOS privacy transparency app; contact@flockalert.app)",
                         forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            return (200...201).contains(code)
        } catch {
            return false
        }
    }
}

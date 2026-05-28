import Foundation
import SwiftData
import CoreLocation

// Orchestrates fetching camera data from Overpass + local seed file,
// deduplicates against SwiftData store, and exposes sync state.

@MainActor
final class SyncManager: ObservableObject {
    @Published var state: SyncState = .idle
    @Published var totalCameraCount: Int = 0

    private let overpass = OverpassAPIClient.shared
    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        self.modelContext = context
        loadSeedData(context: context)
        countCameras(context: context)
    }

    // MARK: - Seed Data (bundled JSON — loads once on first launch)

    private func loadSeedData(context: ModelContext) {
        let key = "seedDataLoadedV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        guard let url = Bundle.main.url(forResource: "SeedCameras", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seeds = try? JSONDecoder().decode([SeedCamera].self, from: data)
        else { return }

        for seed in seeds {
            let cam = Camera(
                latitude: seed.lat,
                longitude: seed.lng,
                facingDirection: seed.facing,
                ownerType: OwnerType(rawValue: seed.ownerType) ?? .unknown,
                ownerName: seed.ownerName,
                verificationCount: seed.verifications,
                confidenceScore: seed.confidence,
                dataRetentionDays: seed.retentionDays,
                sourceType: SourceType(rawValue: seed.source) ?? .publicRecords,
                sourceURL: seed.sourceURL,
                streetAddress: seed.address,
                city: seed.city,
                state: seed.state
            )
            context.insert(cam)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Overpass Sync

    func syncRegion(center: CLLocationCoordinate2D, radiusKm: Double = 10) async {
        guard let context = modelContext else { return }
        state = .syncing

        do {
            let cameras = try await overpass.fetchCameras(
                around: center,
                radiusMetres: radiusKm * 1000
            )

            var inserted = 0
            for oc in cameras {
                // Deduplicate by OSM node ID and proximity (within 15m)
                if !isDuplicate(osmID: oc.osmNodeID, lat: oc.latitude, lng: oc.longitude, context: context) {
                    context.insert(oc.toCamera())
                    inserted += 1
                }
            }

            if inserted > 0 { try? context.save() }
            countCameras(context: context)
            state = .done(count: inserted)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func isDuplicate(osmID: Int64, lat: Double, lng: Double, context: ModelContext) -> Bool {
        let desc = FetchDescriptor<Camera>(
            predicate: #Predicate { $0.osmNodeID == osmID }
        )
        if let count = try? context.fetchCount(desc), count > 0 { return true }

        // Proximity check — consider within 15m a duplicate
        let latDelta = 0.000135   // ~15m in latitude degrees
        let lngDelta = latDelta
        let desc2 = FetchDescriptor<Camera>(
            predicate: #Predicate { cam in
                cam.latitude > lat - latDelta &&
                cam.latitude < lat + latDelta &&
                cam.longitude > lng - lngDelta &&
                cam.longitude < lng + lngDelta
            }
        )
        return (try? context.fetchCount(desc2) ?? 0) ?? 0 > 0
    }

    private func countCameras(context: ModelContext) {
        let desc = FetchDescriptor<Camera>(predicate: #Predicate { $0.isActive })
        totalCameraCount = (try? context.fetchCount(desc)) ?? 0
    }
}

// MARK: - Seed JSON model

struct SeedCamera: Decodable {
    let lat: Double
    let lng: Double
    let facing: Double?
    let ownerType: String
    let ownerName: String?
    let verifications: Int
    let confidence: Double
    let retentionDays: Int?
    let source: String
    let sourceURL: String?
    let address: String?
    let city: String?
    let state: String?
}

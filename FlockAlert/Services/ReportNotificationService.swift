import Foundation

// Sends push notifications to the owner when camera reports or verifications
// are submitted. Uses ntfy.sh — free, no account required.
//
// To receive notifications:
//   1. Install the ntfy app (iOS/Android/Web): https://ntfy.sh
//   2. Subscribe to the topic: flockalert-elevateai-7x4k
//
// That's it. Every report will ping your device instantly.

struct ReportNotificationService {
    static let shared = ReportNotificationService()

    private let topic = "flockalert-elevateai-7x4k"
    private let baseURL = "https://ntfy.sh"

    private var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    // MARK: - Camera Report

    func notifyCameraReport(
        latitude: Double,
        longitude: Double,
        ownerType: String,
        notes: String?,
        photoCount: Int
    ) {
        var lines = [
            "Owner: \(ownerType)",
            "Photos: \(photoCount)",
            "Location: \(String(format: "%.5f", latitude)), \(String(format: "%.5f", longitude))",
            "Maps: https://maps.apple.com/?ll=\(latitude),\(longitude)"
        ]
        if let notes, !notes.isEmpty {
            lines.append("Notes: \(notes)")
        }
        send(
            title: "📷 New Camera Report",
            body: lines.joined(separator: "\n"),
            tags: ["camera", "flock", "report"],
            priority: 3
        )
    }

    // MARK: - Camera Verification

    func notifyCameraVerification(
        cameraID: String,
        userName: String,
        hasPhoto: Bool,
        note: String?
    ) {
        var lines = [
            "Submitted by: \(userName)",
            "Photo attached: \(hasPhoto ? "Yes ✓" : "No")",
            "Camera ID: \(cameraID)"
        ]
        if let note, !note.isEmpty {
            lines.append("Note: \(note)")
        }
        send(
            title: "✅ Camera Verified\(hasPhoto ? " + Photo" : "")",
            body: lines.joined(separator: "\n"),
            tags: ["white_check_mark", "camera", "verify"],
            priority: hasPhoto ? 4 : 3
        )
    }

    // MARK: - Internal

    private func send(title: String, body: String, tags: [String], priority: Int) {
        guard let url = URL(string: "\(baseURL)/\(topic)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(tags.joined(separator: ","), forHTTPHeaderField: "Tags")
        request.setValue(String(priority), forHTTPHeaderField: "Priority")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { _, _, _ in }.resume()
    }
}

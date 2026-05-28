import UserNotifications
import AVFoundation
import UIKit

final class AlertDispatcher {
    private let synthesizer = AVSpeechSynthesizer()
    private var cooldowns: [UUID: Date] = [:]
    private let cooldownInterval: TimeInterval = 120  // 2 min between repeat alerts for same camera

    func dispatch(camera: Camera, distance: Double, mode: AlertMode, voice: Bool) {
        // Debounce — don't re-alert the same camera within cooldown window
        if let last = cooldowns[camera.id], Date().timeIntervalSince(last) < cooldownInterval {
            return
        }
        cooldowns[camera.id] = Date()

        switch mode {
        case .banner:
            sendNotification(camera: camera, distance: distance)
            HapticManager.notification(.warning)
        case .silent:
            HapticManager.notification(.warning)
        case .hapticOnly:
            HapticManager.impact(.heavy)
        case .voice:
            sendNotification(camera: camera, distance: distance)
            if voice { speakAlert(camera: camera, distance: distance) }
        }
    }

    // MARK: - Push Notification

    private func sendNotification(camera: Camera, distance: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Surveillance Camera Ahead"
        content.body = buildBody(camera: camera, distance: distance)
        content.sound = .default
        content.categoryIdentifier = "CAMERA_ALERT"
        content.userInfo = ["cameraID": camera.id.uuidString]

        // Attach owner color as interruption level hint
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "cam-\(camera.id.uuidString)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func buildBody(camera: Camera, distance: Double) -> String {
        let ft = Int(distance * 3.281)
        let owner = camera.ownerLabel
        return "Active ALPR zone in \(ft) ft · \(owner)"
    }

    // MARK: - Voice Alert (CarPlay / driving mode)

    private func speakAlert(camera: Camera, distance: Double) {
        let ft = Int(distance * 3.281)
        let owner = camera.ownerName ?? camera.ownerType.rawValue
        let text = "Flock camera in \(ft) feet. \(owner)."

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.volume = 0.9
        utterance.pitchMultiplier = 1.0

        // Duck audio briefly
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        synthesizer.speak(utterance)
    }
}

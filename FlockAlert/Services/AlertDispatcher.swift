import UserNotifications
import AVFoundation
import UIKit

@MainActor
final class AlertDispatcher {

    private let chirpPlayer = BirdChirpPlayer()
    private let synthesizer = AVSpeechSynthesizer()

    // Separate cooldowns so approach + in-view can each fire once per pass
    private var approachCooldowns: [UUID: Date] = [:]
    private var inViewCooldowns:   [UUID: Date] = [:]
    private let approachCooldown: TimeInterval = 90   // 1.5 min per camera
    private let inViewCooldown:   TimeInterval = 120  // 2 min per camera

    // MARK: - Stage 1: Camera Approaching (~500 ft out)

    func dispatchApproach(camera: Camera, distance: Double, mode: AlertMode, voice: Bool) {
        // All proximity alerts require Pro
        guard SubscriptionManager.shared.isPro else { return }

        guard !onCooldown(camera: camera, cooldowns: &approachCooldowns, interval: approachCooldown)
        else { return }
        stamp(camera: camera, in: &approachCooldowns)

        if mode != .silent && mode != .hapticOnly {
            chirpPlayer.chirp()
        }

        switch mode {
        case .banner, .voice:
            sendApproachNotification(camera: camera, distance: distance)
            if mode == .voice && voice { speakApproach(camera: camera, distance: distance) }
            HapticManager.notification(.warning)
        case .silent:
            HapticManager.notification(.warning)
        case .hapticOnly:
            HapticManager.impact(.medium)
        }
    }

    // MARK: - Stage 2: In Camera View — Pro only

    func dispatchInView(camera: Camera, mode: AlertMode, voice: Bool) {
        guard SubscriptionManager.shared.isPro else { return }   // Pro feature
        guard !onCooldown(camera: camera, cooldowns: &inViewCooldowns, interval: inViewCooldown)
        else { return }
        stamp(camera: camera, in: &inViewCooldowns)

        if mode != .silent && mode != .hapticOnly {
            chirpPlayer.chirp()
        }

        switch mode {
        case .banner, .voice:
            sendInViewNotification(camera: camera)
            if mode == .voice && voice { speakInView(camera: camera) }
            HapticManager.impact(.heavy)
        case .silent:
            HapticManager.impact(.heavy)
        case .hapticOnly:
            HapticManager.impact(.heavy)
        }
    }

    // MARK: - Notifications

    private func sendApproachNotification(camera: Camera, distance: Double) {
        let ft = Int(distance * 3.281)
        let content = UNMutableNotificationContent()
        content.title = "🚨 Flock Camera Ahead"
        content.body  = "Active ALPR in \(ft) ft · \(camera.ownerLabel)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("tweet.caf"))
        content.categoryIdentifier  = "CAMERA_APPROACH"
        content.interruptionLevel   = .timeSensitive
        content.userInfo = ["cameraID": camera.id.uuidString, "stage": "approach"]
        deliver(content, id: "approach-\(camera.id)-\(Int(Date().timeIntervalSince1970))")
    }

    private func sendInViewNotification(camera: Camera) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ You Are In Camera View"
        content.body  = "\(camera.ownerLabel) ALPR is scanning your plate now"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("tweet.caf"))
        content.categoryIdentifier  = "CAMERA_IN_VIEW"
        // .critical requires the critical-alerts entitlement (manual Apple approval) which this app
        // doesn't hold — iOS downgrades it and App Review flags it. Use .timeSensitive, which matches
        // our com.apple.developer.usernotifications.time-sensitive entitlement and still breaks through
        // Focus modes.
        content.interruptionLevel   = .timeSensitive
        content.userInfo = ["cameraID": camera.id.uuidString, "stage": "inView"]
        deliver(content, id: "inview-\(camera.id)-\(Int(Date().timeIntervalSince1970))")
    }

    private func deliver(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Voice

    private func speakApproach(camera: Camera, distance: Double) {
        let ft    = Int(distance * 3.281)
        let owner = camera.ownerName ?? "Flock Safety"
        speak("Flock camera ahead in \(ft) feet. \(owner).")
    }

    private func speakInView(camera: Camera) {
        speak("Warning. You are now in camera view.")
    }

    private func speak(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: text)
        u.voice            = AVSpeechSynthesisVoice(language: "en-US")
        u.rate             = 0.48
        u.volume           = 0.95
        u.pitchMultiplier  = 1.0
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(u)
    }

    // MARK: - Cooldown Helpers

    private func onCooldown(camera: Camera, cooldowns: inout [UUID: Date], interval: TimeInterval) -> Bool {
        guard let last = cooldowns[camera.id] else { return false }
        return Date().timeIntervalSince(last) < interval
    }

    private func stamp(camera: Camera, in cooldowns: inout [UUID: Date]) {
        cooldowns[camera.id] = Date()
    }
}

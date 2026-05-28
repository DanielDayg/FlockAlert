import SwiftData
import Foundation

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var appleUserID: String
    var displayName: String
    var email: String?
    var points: Int
    var camerasReported: Int
    var photosUploaded: Int
    var joinDate: Date

    init(appleUserID: String, displayName: String, email: String? = nil) {
        self.id = UUID()
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.email = email
        self.points = 0
        self.camerasReported = 0
        self.photosUploaded = 0
        self.joinDate = Date()
    }

    // Badge system
    var badgeTier: BadgeTier {
        switch points {
        case ..<50:    return .scout
        case ..<200:   return .watcher
        case ..<500:   return .investigator
        case ..<1000:  return .guardian
        default:       return .watchdog
        }
    }

    var pointsToNextBadge: Int {
        switch badgeTier {
        case .scout:        return 50 - points
        case .watcher:      return 200 - points
        case .investigator: return 500 - points
        case .guardian:     return 1000 - points
        case .watchdog:     return 0
        }
    }

    var nextBadgeTotal: Int {
        switch badgeTier {
        case .scout:        return 50
        case .watcher:      return 200
        case .investigator: return 500
        case .guardian:     return 1000
        case .watchdog:     return 1000
        }
    }

    var currentBadgeStart: Int {
        switch badgeTier {
        case .scout:        return 0
        case .watcher:      return 50
        case .investigator: return 200
        case .guardian:     return 500
        case .watchdog:     return 1000
        }
    }

    enum BadgeTier: String {
        case scout        = "Scout"
        case watcher      = "Watcher"
        case investigator = "Investigator"
        case guardian     = "Guardian"
        case watchdog     = "Watchdog"

        var icon: String {
            switch self {
            case .scout:        return "binoculars"
            case .watcher:      return "eye.fill"
            case .investigator: return "magnifyingglass"
            case .guardian:     return "shield.fill"
            case .watchdog:     return "bolt.shield.fill"
            }
        }

        var color: String {
            switch self {
            case .scout:        return "00D4FF"
            case .watcher:      return "00D68F"
            case .investigator: return "FFB800"
            case .guardian:     return "FF6B00"
            case .watchdog:     return "FF3B30"
            }
        }
    }
}

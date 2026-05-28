import Foundation
import SwiftData

@Model
final class AlertEvent {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var cameraID: UUID
    var cameraOwnerLabel: String
    var cameraCity: String?
    var triggerDistanceMetres: Double
    var alertTypeRaw: String
    var wasRead: Bool

    init(
        cameraID: UUID,
        cameraOwnerLabel: String,
        cameraCity: String?,
        triggerDistanceMetres: Double,
        alertType: AlertType
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.cameraID = cameraID
        self.cameraOwnerLabel = cameraOwnerLabel
        self.cameraCity = cameraCity
        self.triggerDistanceMetres = triggerDistanceMetres
        self.alertTypeRaw = alertType.rawValue
        self.wasRead = false
    }

    var alertType: AlertType {
        AlertType(rawValue: alertTypeRaw) ?? .entering
    }

    var distanceFeet: Int { Int(triggerDistanceMetres * 3.281) }

    enum AlertType: String, Codable {
        case approaching    = "Approaching"
        case entering       = "Entering Range"
        case highDensity    = "High Density Zone"
    }
}

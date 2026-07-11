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
    var cameraLatitude: Double
    var cameraLongitude: Double

    init(
        cameraID: UUID,
        cameraOwnerLabel: String,
        cameraCity: String?,
        triggerDistanceMetres: Double,
        alertType: AlertType,
        cameraLatitude: Double = 0.0,
        cameraLongitude: Double = 0.0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.cameraID = cameraID
        self.cameraOwnerLabel = cameraOwnerLabel
        self.cameraCity = cameraCity
        self.triggerDistanceMetres = triggerDistanceMetres
        self.alertTypeRaw = alertType.rawValue
        self.wasRead = false
        self.cameraLatitude = cameraLatitude
        self.cameraLongitude = cameraLongitude
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

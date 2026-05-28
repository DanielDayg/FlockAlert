import Foundation
import SwiftData

@Model
final class CameraReport {
    @Attribute(.unique) var id: UUID
    var localCameraID: UUID?         // Nil means new camera report
    var latitude: Double
    var longitude: Double
    var reportTypeRaw: String
    var ownerTypeRaw: String
    var ownerName: String?
    var mountTypeRaw: String
    var facingDirection: Double?
    var notes: String?
    var photoData: [Data]            // Stored locally until uploaded
    var statusRaw: String
    var submittedAt: Date
    var serverID: String?            // Set after successful server upload

    init(
        localCameraID: UUID? = nil,
        latitude: Double,
        longitude: Double,
        reportType: ReportType,
        ownerType: OwnerType = .unknown,
        ownerName: String? = nil,
        mountType: MountType = .unknown,
        facingDirection: Double? = nil,
        notes: String? = nil,
        photoData: [Data] = []
    ) {
        self.id = UUID()
        self.localCameraID = localCameraID
        self.latitude = latitude
        self.longitude = longitude
        self.reportTypeRaw = reportType.rawValue
        self.ownerTypeRaw = ownerType.rawValue
        self.ownerName = ownerName
        self.mountTypeRaw = mountType.rawValue
        self.facingDirection = facingDirection
        self.notes = notes
        self.photoData = photoData
        self.statusRaw = ReportStatus.pending.rawValue
        self.submittedAt = Date()
    }

    var reportType: ReportType { ReportType(rawValue: reportTypeRaw) ?? .newCamera }
    var status: ReportStatus { ReportStatus(rawValue: statusRaw) ?? .pending }

    enum ReportType: String, Codable, CaseIterable {
        case newCamera      = "New Camera"
        case verifyExisting = "Verify Existing"
        case reportRemoved  = "Camera Removed"
        case correctInfo    = "Correct Info"
    }

    enum ReportStatus: String, Codable {
        case pending    = "pending"
        case uploaded   = "uploaded"
        case approved   = "approved"
        case rejected   = "rejected"
    }
}

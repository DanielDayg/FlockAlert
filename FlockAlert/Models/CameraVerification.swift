import SwiftData
import Foundation

@Model
final class CameraVerification {
    @Attribute(.unique) var id: UUID
    var cameraID: UUID
    var userAppleID: String
    var userName: String
    var photoData: Data?
    var note: String?
    var submittedAt: Date
    var pointsAwarded: Int

    init(cameraID: UUID, userAppleID: String, userName: String, photoData: Data? = nil, note: String? = nil) {
        self.id = UUID()
        self.cameraID = cameraID
        self.userAppleID = userAppleID
        self.userName = userName
        self.photoData = photoData
        self.note = note
        self.submittedAt = Date()
        self.pointsAwarded = photoData != nil ? 25 : 10
    }
}

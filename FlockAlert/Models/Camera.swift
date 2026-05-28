import Foundation
import SwiftData
import CoreLocation

@Model
final class Camera {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var facingDirection: Double?      // 0–360 degrees (north = 0)
    var fieldOfViewDegrees: Double?   // typically 60–90 for ALPR
    var ownerTypeRaw: String
    var ownerName: String?
    var installedDateRaw: Double?     // timeIntervalSince1970
    var lastVerified: Date
    var verificationCount: Int
    var confidenceScore: Double       // 0.0–1.0
    var cameraModel: String?          // e.g. "Flock Safety Falcon"
    var mountTypeRaw: String
    var dataRetentionDays: Int?
    var sourceTypeRaw: String
    var sourceURL: String?
    var isActive: Bool
    var photoURLs: [String]
    var notes: String?
    var osmNodeID: Int64?             // OSM node ID if sourced from Overpass
    var streetAddress: String?
    var city: String?
    var state: String?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        facingDirection: Double? = nil,
        fieldOfViewDegrees: Double? = 75,
        ownerType: OwnerType = .unknown,
        ownerName: String? = nil,
        installedDate: Date? = nil,
        lastVerified: Date = Date(),
        verificationCount: Int = 1,
        confidenceScore: Double = 0.5,
        cameraModel: String? = "Flock Safety",
        mountType: MountType = .utilityPole,
        dataRetentionDays: Int? = 30,
        sourceType: SourceType = .communityReport,
        sourceURL: String? = nil,
        isActive: Bool = true,
        photoURLs: [String] = [],
        notes: String? = nil,
        osmNodeID: Int64? = nil,
        streetAddress: String? = nil,
        city: String? = nil,
        state: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.facingDirection = facingDirection
        self.fieldOfViewDegrees = fieldOfViewDegrees
        self.ownerTypeRaw = ownerType.rawValue
        self.ownerName = ownerName
        self.installedDateRaw = installedDate?.timeIntervalSince1970
        self.lastVerified = lastVerified
        self.verificationCount = verificationCount
        self.confidenceScore = confidenceScore
        self.cameraModel = cameraModel
        self.mountTypeRaw = mountType.rawValue
        self.dataRetentionDays = dataRetentionDays
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceURL = sourceURL
        self.isActive = isActive
        self.photoURLs = photoURLs
        self.notes = notes
        self.osmNodeID = osmNodeID
        self.streetAddress = streetAddress
        self.city = city
        self.state = state
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    var ownerType: OwnerType {
        OwnerType(rawValue: ownerTypeRaw) ?? .unknown
    }
    var mountType: MountType {
        MountType(rawValue: mountTypeRaw) ?? .unknown
    }
    var sourceType: SourceType {
        SourceType(rawValue: sourceTypeRaw) ?? .communityReport
    }
    var installedDate: Date? {
        installedDateRaw.map { Date(timeIntervalSince1970: $0) }
    }
    var locationLabel: String {
        [streetAddress, city, state].compactMap { $0 }.joined(separator: ", ")
    }
    var ownerLabel: String {
        ownerName ?? ownerType.rawValue
    }
}

enum OwnerType: String, Codable, CaseIterable {
    case municipalPolice    = "Municipal Police"
    case sheriffDept        = "Sheriff's Dept"
    case statePolice        = "State Police"
    case federalAgency      = "Federal Agency"
    case hoa                = "HOA"
    case school             = "School / University"
    case privateBusiness    = "Private Business"
    case unknown            = "Unknown"

    var color: String {
        switch self {
        case .municipalPolice, .sheriffDept, .statePolice, .federalAgency: return "alertRed"
        case .hoa: return "cautionYellow"
        case .school: return "skyBlue"
        case .privateBusiness: return "primaryCyan"
        case .unknown: return "textSub"
        }
    }
}

enum MountType: String, Codable, CaseIterable {
    case utilityPole    = "Utility Pole"
    case trafficSignal  = "Traffic Signal"
    case building       = "Building"
    case dedicatedPole  = "Dedicated Pole"
    case streetLight    = "Street Light"
    case unknown        = "Unknown"
}

enum SourceType: String, Codable, CaseIterable {
    case publicRecords  = "Public Records"
    case foiaRequest    = "FOIA Request"
    case cityContract   = "City Contract"
    case communityReport = "Community Report"
    case newsArticle    = "News Article"
    case gisData        = "GIS Dataset"
    case osmData        = "OpenStreetMap"
    case procurement    = "Procurement Document"
}

// MARK: - CLLocation bearing extension

extension CLLocation {
    func bearing(to coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = self.coordinate.latitude.toRadians
        let lon1 = self.coordinate.longitude.toRadians
        let lat2 = coordinate.latitude.toRadians
        let lon2 = coordinate.longitude.toRadians
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        return (radians.toDegrees + 360).truncatingRemainder(dividingBy: 360)
    }
}

extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}

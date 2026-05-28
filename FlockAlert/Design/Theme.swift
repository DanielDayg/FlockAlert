import SwiftUI

// MARK: - Color Palette

extension Color {
    // Brand
    static let flockPrimary  = Color(hex: "00D4FF")   // Electric cyan
    static let flockSecondary = Color(hex: "7B2FBE")  // Deep violet
    static let flockAccent   = Color(hex: "FF6B35")   // Alert orange

    // Backgrounds
    static let flockBG       = Color(hex: "080C14")   // Deep navy black
    static let flockSurface  = Color(hex: "0F1520")   // Card surface
    static let flockSurface2 = Color(hex: "162030")   // Elevated surface

    // Text
    static let flockText     = Color(hex: "E8F4FD")   // Primary text
    static let flockTextSub  = Color(hex: "6A8BAA")   // Secondary text

    // Status
    static let flockSafe     = Color(hex: "00D68F")   // No cameras nearby
    static let flockCaution  = Color(hex: "FFB800")   // Approaching
    static let flockAlert    = Color(hex: "FF3B30")   // In range / law enforcement owned
    static let skyBlue       = Color(hex: "4FC3F7")   // School cameras

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

extension Font {
    static let flockTitle    = Font.system(size: 28, weight: .bold, design: .rounded)
    static let flockHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let flockBody     = Font.system(size: 15, weight: .regular)
    static let flockCaption  = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let flockMono     = Font.system(size: 13, weight: .regular, design: .monospaced)
}

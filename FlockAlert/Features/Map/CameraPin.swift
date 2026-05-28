import SwiftUI

struct CameraPin: View {
    let camera: Camera
    let isSelected: Bool
    let isActive: Bool

    @State private var pulse = false

    private var pinColor: Color {
        switch camera.ownerType {
        case .municipalPolice, .sheriffDept, .statePolice, .federalAgency:
            return .flockAlert
        case .hoa:
            return .flockCaution
        case .school:
            return .skyBlue
        case .privateBusiness:
            return .flockPrimary
        case .unknown:
            return Color(white: 0.6)
        }
    }

    private var pinSize: CGFloat { isSelected ? 24 : 16 }

    var body: some View {
        ZStack {
            // Active alert pulse ring
            if isActive || isSelected {
                Circle()
                    .fill(pinColor.opacity(0.18))
                    .frame(width: pinSize * 2.2, height: pinSize * 2.2)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: pulse
                    )
            }

            // Confidence arc ring
            Circle()
                .trim(from: 0, to: camera.confidenceScore)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .rotationEffect(.degrees(-90))
                .frame(width: pinSize + 6, height: pinSize + 6)

            // Main dot
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [pinColor, pinColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: pinSize, height: pinSize)
                    .shadow(color: pinColor.opacity(0.6), radius: isSelected ? 10 : 5)

                Image(systemName: "camera.fill")
                    .font(.system(size: pinSize * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onAppear { pulse = isActive || isSelected }
        .onChange(of: isActive) { _, v in pulse = v || isSelected }
        .onChange(of: isSelected) { _, v in pulse = v || isActive }
    }
}

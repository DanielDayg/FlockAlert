import SwiftUI

struct ProximityBannerView: View {
    let camera: Camera
    let distance: Double
    let visibility: String
    var onDismiss: (() -> Void)? = nil

    @State private var pulse = false

    private var distanceFeet: Int { Int(distance * 3.281) }

    private var statusColor: Color {
        switch distance {
        case ..<46:  return .flockAlert      // <150 ft
        case 46..<152: return .flockCaution  // <500 ft
        default:     return .flockPrimary
        }
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Animated indicator orb
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 42, height: 42)

                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 42, height: 42)
                        .scaleEffect(pulse ? 1.5 : 1.0)
                        .opacity(pulse ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.3).repeatForever(autoreverses: false), value: pulse)

                    Image(systemName: "eye.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                // Info column
                VStack(alignment: .leading, spacing: 3) {
                    Text("Camera in \(distanceFeet) ft")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.flockText)
                    Text(camera.ownerLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.flockTextSub)
                        .lineLimit(1)
                }

                Spacer()

                // Visibility status
                VStack(alignment: .trailing, spacing: 2) {
                    Text("VISIBLE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.flockTextSub)
                        .tracking(1)
                    Text(visibility)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(statusColor)
                }

                // Dismiss button
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.flockTextSub)
                        .padding(8)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .onAppear { pulse = true }
    }
}

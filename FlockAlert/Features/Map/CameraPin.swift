import SwiftUI

struct CameraPin: View {
    let camera: Camera
    let isSelected: Bool
    let isActive: Bool

    @State private var pulse = false

    private var pinColor: Color {
        switch camera.ownerType {
        case .municipalPolice, .sheriffDept, .statePolice, .federalAgency: return .flockAlert
        case .hoa:             return .flockCaution
        case .school:          return .skyBlue
        case .privateBusiness: return .flockPrimary
        default:               return Color(white: 0.55)
        }
    }

    private var dotSize: CGFloat { isSelected ? 22 : 14 }

    var body: some View {
        ZStack(alignment: .center) {
            // ── FOV arc — shown when facing direction is known ──────
            if let facing = camera.facingDirection {
                FOVArc(
                    facingDegrees: facing,
                    fovDegrees: camera.fieldOfViewDegrees ?? 75,
                    radius: isSelected ? 36 : 26,
                    color: pinColor
                )
                .opacity(isSelected ? 0.55 : 0.30)
            }

            // ── Pulse ring — only when alerting or selected ─────────
            if isSelected || isActive {
                Circle()
                    .fill(pinColor.opacity(0.13))
                    .frame(width: dotSize * 2.6, height: dotSize * 2.6)
                    .scaleEffect(pulse ? 1.7 : 1.0)
                    .opacity(pulse ? 0 : 0.9)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                    .onAppear  { pulse = true  }
                    .onDisappear { pulse = false }
            }

            // ── Camera dot ─────────────────────────────────────────
            Circle()
                .fill(pinColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: pinColor.opacity(0.6), radius: isSelected ? 8 : 3)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: dotSize * 0.44, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - FOV Arc Shape

struct FOVArc: View {
    let facingDegrees: Double   // 0 = North, clockwise
    let fovDegrees: Double      // width of arc (e.g. 75°)
    let radius: CGFloat
    let color: Color

    // MapKit's coordinate system: 0° = North = up on screen
    // SwiftUI rotation: 0° = right (east), so we subtract 90° to align North = up
    private var startAngle: Angle {
        Angle(degrees: facingDegrees - fovDegrees / 2 - 90)
    }
    private var endAngle: Angle {
        Angle(degrees: facingDegrees + fovDegrees / 2 - 90)
    }

    var body: some View {
        ZStack {
            // Filled wedge
            Path { path in
                let center = CGPoint(x: radius, y: radius)
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color.opacity(0.18))

            // Arc outline
            Path { path in
                let center = CGPoint(x: radius, y: radius)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
            }
            .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Direction line from center
            Path { path in
                let center = CGPoint(x: radius, y: radius)
                let midAngle = (startAngle.radians + endAngle.radians) / 2
                let tip = CGPoint(
                    x: center.x + cos(midAngle) * radius,
                    y: center.y + sin(midAngle) * radius
                )
                path.move(to: center)
                path.addLine(to: tip)
            }
            .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

import SwiftUI

struct CityClusterPin: View {
    let cluster: CityCluster
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // ── Outer pulse ring ──────────────────────────────
                Circle()
                    .fill(Color.flockCaution.opacity(0.18))
                    .frame(width: 54, height: 54)
                    .scaleEffect(pulse ? 1.8 : 1.0)
                    .opacity(pulse ? 0 : 1.0)
                    .animation(
                        .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                        value: pulse
                    )

                // ── Static halo ───────────────────────────────────
                Circle()
                    .fill(Color.flockCaution.opacity(0.12))
                    .frame(width: 42, height: 42)

                // ── Main circle ───────────────────────────────────
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FF9F0A"),
                                Color(hex: "FF6B00")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.flockCaution.opacity(0.6), radius: 6, y: 2)

                // ── Border ────────────────────────────────────────
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 32, height: 32)

                // ── Camera + alert icon ───────────────────────────
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
            .onAppear  { pulse = true  }
            .onDisappear { pulse = false }

            // ── City name ─────────────────────────────────────────
            Text(cluster.city.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(0.5)
                .shadow(color: .black.opacity(0.9), radius: 3, y: 1)
                .lineLimit(1)
        }
    }
}

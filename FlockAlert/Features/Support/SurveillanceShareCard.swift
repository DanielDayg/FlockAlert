import SwiftUI

/// A branded, shareable "surveillance near me" card. Turns every user into a
/// distribution channel — "47 ALPR cameras track me within 2 miles" is exactly the
/// kind of stat people screenshot and post. Rendered to an image and shared.
struct SurveillanceCardView: View {
    let count: Int
    let radiusMiles: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.flockPrimary)
                Text("FLOCK ALERT")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Color.flockText)
                Spacer()
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: 118, weight: .black, design: .rounded))
                .foregroundStyle(Color.flockPrimary)
            Text(count == 1 ? "ALPR camera is tracking me" : "ALPR cameras are tracking me")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.flockText)
            Text("within \(radiusMiles) \(radiusMiles == 1 ? "mile" : "miles") of where I live")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.flockTextSub)

            Spacer()

            Text("Find the surveillance cameras near you.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.flockText)
            Text("Download Flock Alert — free on the App Store")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.flockPrimary)
        }
        .padding(36)
        .frame(width: 440, height: 440, alignment: .leading)
        .background(Color.flockBG)
    }
}

/// Renders the card to a high-resolution image for sharing. Must run on the main actor.
/// (Shared via the existing `ShareSheet` wrapper defined in CameraDetailSheet.)
@MainActor
func renderSurveillanceCard(count: Int, radiusMiles: Int) -> UIImage? {
    let renderer = ImageRenderer(content: SurveillanceCardView(count: count, radiusMiles: radiusMiles))
    renderer.scale = 3
    return renderer.uiImage
}

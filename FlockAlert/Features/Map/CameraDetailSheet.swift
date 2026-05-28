import SwiftUI
import MapKit

struct CameraDetailSheet: View {
    let camera: Camera
    let onDismiss: () -> Void
    let onReport: () -> Void

    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var showShareSheet = false
    @State private var showVerify = false
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header ──────────────────────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(camera.cameraModel ?? "Flock Safety")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.flockText)
                            if !camera.locationLabel.isEmpty {
                                Text(camera.locationLabel)
                                    .font(.flockCaption)
                                    .foregroundStyle(Color.flockTextSub)
                            }
                        }
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.flockTextSub)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // ── Owner Type Badge ──────────────────────────────────────
                    HStack(spacing: 8) {
                        OwnerBadge(ownerType: camera.ownerType)
                        ConfidenceBadge(score: camera.confidenceScore, count: camera.verificationCount)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)

                    // ── Details Grid ──────────────────────────────────────
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DetailCell(icon: "building.2", label: "Owner", value: camera.ownerLabel)
                        DetailCell(icon: "clock", label: "Data Kept",
                                   value: camera.dataRetentionDays.map { "\($0) days" } ?? "Unknown")
                        DetailCell(icon: "arrow.up", label: "Facing",
                                   value: camera.facingDirection.map { degreesToCompass($0) } ?? "Unknown")
                        DetailCell(icon: "eye.slash", label: "FOV",
                                   value: camera.fieldOfViewDegrees.map { "\(Int($0))°" } ?? "Unknown")
                        DetailCell(icon: "wrench.and.screwdriver", label: "Mount",
                                   value: camera.mountType.rawValue)
                        DetailCell(icon: "doc.text.magnifyingglass", label: "Source",
                                   value: camera.sourceType.rawValue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    if let installed = camera.installedDate {
                        DetailCell(icon: "calendar", label: "Installed",
                                   value: installed.formatted(date: .abbreviated, time: .omitted))
                            .padding(.horizontal, 20)
                    }

                    // ── Verified strip ──────────────────────────────────────
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.flockSafe)
                        Text("Last verified \(camera.lastVerified.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.flockTextSub)
                        Spacer()
                        if let url = camera.sourceURL, let link = URL(string: url) {
                            Link("Source →", destination: link)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.flockPrimary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // ── Community Photos (Pro-gated) ──────────────────
                    if !camera.photoURLs.isEmpty {
                        Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)

                        if subscriptionManager.isPro {
                            // Show photos
                            VStack(alignment: .leading, spacing: 10) {
                                Text("COMMUNITY PHOTOS")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.flockTextSub)
                                    .tracking(1.5)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(camera.photoURLs, id: \.self) { urlString in
                                            AsyncImage(url: URL(string: urlString)) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                case .failure:
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.flockSurface2)
                                                        .overlay(
                                                            Image(systemName: "photo.slash")
                                                                .foregroundStyle(Color.flockTextSub)
                                                        )
                                                default:
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.flockSurface2)
                                                        .overlay(ProgressView())
                                                }
                                            }
                                            .frame(width: 160, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 14)
                        } else {
                            // Locked teaser
                            Button { showPaywall = true } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.flockPrimary.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "photo.stack.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(Color.flockPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(camera.photoURLs.count) community photo\(camera.photoURLs.count == 1 ? "" : "s")")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.flockText)
                                        Text("Unlock with Flock Alert Pro")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.flockPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.flockPrimary.opacity(0.7))
                                }
                                .padding(14)
                                .background(Color.flockPrimary.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.flockPrimary.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 14)
                        }
                    }

                    Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)

                    // ── Actions ──────────────────────────────────────
                    HStack(spacing: 12) {
                        ActionButton(icon: "flag", label: "Report", color: .flockCaution) { onReport() }
                        ActionButton(icon: "checkmark.shield", label: "Verify", color: .flockSafe) {
                            showVerify = true
                        }
                        ActionButton(icon: "square.and.arrow.up", label: "Share", color: .flockPrimary) {
                            showShareSheet = true
                        }
                        ActionButton(icon: "map", label: "Navigate", color: .skyBlue) {
                            openInMaps()
                        }
                    }
                    .padding(20)
                }
            }
            .frame(maxHeight: 460)
        }
        .background(
            ZStack {
                Color.flockSurface
                LinearGradient(
                    colors: [Color.flockPrimary.opacity(0.06), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 90)   // above tab bar
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText()])
        }
        .sheet(isPresented: $showVerify) {
            CameraVerifySheet(camera: camera)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView().environmentObject(subscriptionManager)
        }
    }

    private func degreesToCompass(_ degrees: Double) -> String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        let idx = Int((degrees + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)
        return dirs[max(0, min(15, idx))]
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: camera.coordinate))
        item.name = camera.cameraModel ?? "Flock Camera"
        item.openInMaps()
    }

    private func shareText() -> String {
        "Flock Safety ALPR camera at \(camera.locationLabel). Owner: \(camera.ownerLabel). Found via Flock Alert app."
    }
}

// MARK: - Sub-components

struct OwnerBadge: View {
    let ownerType: OwnerType

    private var color: Color {
        switch ownerType {
        case .municipalPolice, .sheriffDept, .statePolice, .federalAgency: return .flockAlert
        case .hoa: return .flockCaution
        case .school: return .skyBlue
        case .privateBusiness: return .flockPrimary
        case .unknown: return Color(white: 0.5)
        }
    }

    var body: some View {
        Text(ownerType.rawValue)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}

struct ConfidenceBadge: View {
    let score: Double
    let count: Int

    private var color: Color {
        score > 0.75 ? .flockSafe : score > 0.5 ? .flockCaution : Color(white: 0.5)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 10, weight: .bold))
            Text("\(Int(score * 100))% · \(count) verif.")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct DetailCell: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.flockPrimary.opacity(0.8))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.flockTextSub)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.flockText)
            }
        }
        .padding(12)
        .background(Color.flockSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.flockTextSub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

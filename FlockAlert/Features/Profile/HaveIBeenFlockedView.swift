import SwiftUI
import SwiftData
import CoreLocation

/// "Have I Been Flocked?" — an honest exposure estimator.
///
/// Flock's actual plate-scan records are private (there is no public dataset to
/// query), so we do NOT fabricate a scan history. Instead we estimate how exposed
/// a user is, using the REAL documented ALPR cameras around their location.
/// The plate they enter is stored on-device only (@AppStorage) and never sent anywhere.
struct HaveIBeenFlockedView: View {
    @EnvironmentObject var appState: AppState
    @Query private var cameras: [Camera]

    @AppStorage("hibf_plate") private var plate: String = ""
    @State private var checked = false
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @FocusState private var plateFocused: Bool

    private let areaRadiusMiles = 5.0
    private let commuteRadiusMiles = 1.0

    private var activeCameras: [Camera] { cameras.filter { $0.isActive } }

    private func countWithin(_ miles: Double) -> Int? {
        guard let loc = appState.userLocation else { return nil }
        let r = miles * 1609.34
        return activeCameras.filter { loc.distance(from: $0.clLocation) <= r }.count
    }
    private var areaCount: Int? { countWithin(areaRadiusMiles) }
    private var commuteCount: Int? { countWithin(commuteRadiusMiles) }
    /// Rough projection: cameras within ~1 mi of you, passed ~twice a day, 5 days.
    private var weeklyEstimate: Int? { commuteCount.map { $0 * 10 } }

    private var exposure: Exposure { Exposure(areaCount: areaCount) }
    private var canCheck: Bool { plate.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    plateField
                    checkButton

                    if checked {
                        if appState.userLocation == nil {
                            noLocationCard
                        } else {
                            resultSection
                        }
                    }

                    disclaimer
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle("Have I Been Flocked?")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                ShareSheet(items: [img, shareCaption])
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.flockPrimary.opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.flockPrimary)
            }
            .padding(.top, 8)

            Text("Have I Been Flocked?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.flockText)

            Text("Enter your plate to see how exposed you are to the ALPR camera network around you.")
                .font(.system(size: 14))
                .foregroundStyle(Color.flockTextSub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 10)
        }
    }

    private var plateField: some View {
        VStack(spacing: 8) {
            TextField("", text: $plate, prompt:
                Text("YOUR PLATE")
                    .foregroundColor(.black.opacity(0.35))
            )
            .font(.system(size: 30, weight: .heavy, design: .monospaced))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .tracking(4)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .focused($plateFocused)
            .onChange(of: plate) { _, new in
                plate = String(new.uppercased().prefix(8))
                checked = false
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.flockPrimary.opacity(0.6), lineWidth: 3)
            )

            HStack(spacing: 5) {
                Image(systemName: "lock.fill").font(.system(size: 10))
                Text("Stored only on your device. Never uploaded, never shared.")
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.flockTextSub.opacity(0.8))
        }
    }

    private var checkButton: some View {
        Button {
            plateFocused = false
            withAnimation(.spring(response: 0.4)) { checked = true }
            HapticManager.notification(.warning)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Check my exposure")
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.flockBG)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(canCheck ? Color.flockPrimary : Color.flockTextSub.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canCheck)
    }

    @ViewBuilder
    private var resultSection: some View {
        // ── Verdict ────────────────────────────────────────────────
        GlassCard(cornerRadius: 18) {
            VStack(spacing: 10) {
                Text(exposure == .clear ? "NOT FLOCKED — YET" : "YOU'VE BEEN FLOCKED")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(exposure.color)
                    .multilineTextAlignment(.center)

                Text(verdictSubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Exposure meter
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08)).frame(height: 10)
                            Capsule().fill(exposure.color)
                                .frame(width: geo.size.width * exposure.fraction, height: 10)
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text("EXPOSURE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                        Spacer()
                        Text(exposure.label.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(exposure.color)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }

        // ── Real stats ─────────────────────────────────────────────
        HStack(spacing: 10) {
            statPill("\(areaCount ?? 0)", "within 5 miles", "dot.radiowaves.left.and.right", .flockPrimary)
            statPill("\(commuteCount ?? 0)", "within 1 mile", "location.fill", .flockCaution)
            statPill("~\(weeklyEstimate ?? 0)", "reads / week*", "camera.fill", .flockAlert)
        }

        Text("*Rough projection — assumes you pass the cameras within a mile of you about twice a day. Your real number depends on your routes.")
            .font(.system(size: 11))
            .foregroundStyle(Color.flockTextSub.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)

        // ── Share ──────────────────────────────────────────────────
        Button {
            share()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Share my result")
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.flockPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.flockPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.flockPrimary.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var noLocationCard: some View {
        GlassCard(cornerRadius: 16) {
            VStack(spacing: 10) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.flockCaution)
                Text("Turn on location to calculate your exposure")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.flockText)
                    .multilineTextAlignment(.center)
                Text("We use the documented cameras near you to estimate your exposure. Your location stays on your device.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.flockTextSub)
            Text("Flock's actual scan records are private and not publicly available. This is an exposure estimate based on documented ALPR camera locations — not your real scan history.")
                .font(.system(size: 11))
                .foregroundStyle(Color.flockTextSub.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.flockSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func statPill(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        GlassCard(cornerRadius: 14) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.flockText)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.flockTextSub)
                    .tracking(0.3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
        }
    }

    private var verdictSubtitle: String {
        guard let n = areaCount else { return "" }
        if n == 0 {
            return "No documented ALPR cameras within 5 miles of you yet. That can change fast — new cameras go up constantly."
        }
        return "\(n) documented ALPR camera\(n == 1 ? "" : "s") within 5 miles of you. If you drive here, your plate is almost certainly being logged."
    }

    private var shareCaption: String {
        let n = areaCount ?? 0
        return "I've been flocked. 👁️ \(n) ALPR cameras are tracking my plate within 5 miles of home. Check your own exposure → Flock Alert (free on the App Store)."
    }

    private func share() {
        guard let count = areaCount else { return }
        shareImage = renderSurveillanceCard(count: count, radiusMiles: Int(areaRadiusMiles))
        showShare = true
    }
}

// MARK: - Exposure level

private enum Exposure {
    case unknown, clear, low, moderate, heavy, extreme

    init(areaCount: Int?) {
        switch areaCount {
        case .none:            self = .unknown
        case .some(0):         self = .clear
        case .some(1...5):     self = .low
        case .some(6...20):    self = .moderate
        case .some(21...60):   self = .heavy
        default:               self = .extreme
        }
    }

    var label: String {
        switch self {
        case .unknown:  return "Unknown"
        case .clear:    return "Clear"
        case .low:      return "Low"
        case .moderate: return "Moderate"
        case .heavy:    return "Heavy"
        case .extreme:  return "Extreme"
        }
    }

    var fraction: Double {
        switch self {
        case .unknown:  return 0.0
        case .clear:    return 0.08
        case .low:      return 0.30
        case .moderate: return 0.55
        case .heavy:    return 0.80
        case .extreme:  return 1.0
        }
    }

    var color: Color {
        switch self {
        case .unknown:  return .flockTextSub
        case .clear:    return .flockSafe
        case .low:      return .flockSafe
        case .moderate: return .flockCaution
        case .heavy:    return .flockAlert
        case .extreme:  return .flockAlert
        }
    }
}

import SwiftUI
import RevenueCat

/// Voluntary "keep it free" support screen. Every feature in Flock Alert is free —
/// this lets people chip in a monthly amount via a Rocket-Money-style slider.
/// The slider snaps to the real donation tiers configured in RevenueCat.
struct DonationView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// Index into the sorted donation packages (snaps to real tiers).
    @State private var selection: Double = 0
    @State private var isWorking = false
    @State private var showThanks = false
    @State private var errorText: String?

    /// Shown before real RevenueCat tiers load (or if they're not configured yet),
    /// so the slider is always visible instead of a blank loading state.
    private let fallbackAmounts = [1, 3, 5, 10, 15, 25]

    private var packages: [Package] { subscriptionManager.donationPackages }
    private var hasRealTiers: Bool { !packages.isEmpty }
    private var tierCount: Int { hasRealTiers ? packages.count : fallbackAmounts.count }

    private var selectedIndex: Int {
        min(max(Int(selection.rounded()), 0), tierCount - 1)
    }
    private var selectedPackage: Package? {
        hasRealTiers ? packages[selectedIndex] : nil
    }
    private var priceLabel: String {
        if hasRealTiers { return packages[selectedIndex].storeProduct.localizedPriceString }
        return "$\(fallbackAmounts[selectedIndex])"
    }
    private func label(at i: Int) -> String {
        if hasRealTiers { return packages[i].storeProduct.localizedPriceString }
        return "$\(fallbackAmounts[i])"
    }

    /// Which tier index counts as the "most common" nudge (roughly the middle).
    private var recommendedIndex: Int { hasRealTiers ? packages.count / 2 : 2 }

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    amountBlock
                    slider
                    impactBlock
                    ctaBlock
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if showThanks { thanksBanner }
        }
        .onAppear {
            selection = Double(recommendedIndex)
            Task { await subscriptionManager.fetchDonationOffering() }
        }
        .onChange(of: subscriptionManager.donationPackages.count) { _, _ in
            selection = Double(recommendedIndex)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 14) {
            RadarBirdMark()
                .frame(width: 56, height: 56)
                .padding(.top, 20)

            Text("Keep Flock Alert free")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.flockText)

            Text("Every feature is free, forever.\nIf it's worth it to you, chip in what you want — cancel anytime.")
                .font(.system(size: 14))
                .foregroundStyle(Color.flockTextSub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
        .padding(.bottom, 26)
    }

    private var amountBlock: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(priceLabel)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.flockPrimary)
                Text("/mo")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.flockTextSub)
            }
            .contentTransition(.numericText())
            .animation(.snappy, value: selectedIndex)

            if selectedIndex == recommendedIndex {
                Text("Most common")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.flockPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.flockPrimary.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Color.clear.frame(height: 22)
            }
        }
        .padding(.bottom, 16)
    }

    private var slider: some View {
        VStack(spacing: 6) {
            Slider(
                value: $selection,
                in: 0...Double(max(tierCount - 1, 1)),
                step: 1
            ) { editing in
                if !editing { HapticManager.selection() }
            }
            .tint(Color.flockPrimary)
            .onChange(of: selectedIndex) { _, _ in HapticManager.selection() }

            HStack {
                Text(label(at: 0))
                Spacer()
                Text(label(at: tierCount - 1))
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.flockTextSub.opacity(0.7))
        }
        .padding(.bottom, 18)
    }

    private var impactBlock: some View {
        VStack(spacing: 8) {
            Text(hearts)
                .font(.system(size: 16))
            Text(impactText)
                .font(.system(size: 14))
                .foregroundStyle(Color.flockText)
                .multilineTextAlignment(.center)
                .frame(minHeight: 42)
                .padding(.horizontal, 6)
        }
        .padding(.bottom, 20)
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            Button {
                Task { await support() }
            } label: {
                HStack(spacing: 8) {
                    if isWorking {
                        ProgressView().tint(Color.flockBG)
                    } else {
                        Text("Support with \(priceLabel)/mo")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(Color.flockBG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.flockPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isWorking)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.flockAlert)
                    .multilineTextAlignment(.center)
            }

            if let webURL = URL(string: AppConfiguration.webDonationURL), !AppConfiguration.webDonationURL.isEmpty {
                Button {
                    UIApplication.shared.open(webURL)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text("Prefer to give on the web?")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.flockPrimary)
                }
            }

            Button("Maybe later") { dismiss() }
                .font(.system(size: 13))
                .foregroundStyle(Color.flockTextSub.opacity(0.7))
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.flockPrimary)
                Text("You'll get a Supporter badge on your profile")
                    .foregroundStyle(Color.flockTextSub)
            }
            .font(.system(size: 12))
            Text("The app stays 100% free either way.")
                .font(.system(size: 12))
                .foregroundStyle(Color.flockTextSub.opacity(0.7))
        }
        .padding(.top, 20)
    }

    private var thanksBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill").foregroundStyle(Color.flockPrimary)
            Text("Thank you for supporting the flock 💙")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.flockText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.flockSurface2)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.flockPrimary.opacity(0.4), lineWidth: 1))
        .padding(.top, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Copy

    private var tierFraction: Double {
        guard tierCount > 1 else { return 0.4 }
        return Double(selectedIndex) / Double(tierCount - 1)
    }

    private var hearts: String {
        let filled = max(1, Int((tierFraction * 5).rounded(.up)))
        return String(repeating: "💙", count: min(filled, 5))
            + String(repeating: "🤍", count: max(0, 5 - filled))
    }

    private var impactText: String {
        switch tierFraction {
        case ..<0.2:  return "Every bit keeps the servers running 🙏"
        case ..<0.45: return "That covers a real chunk of our monthly hosting."
        case ..<0.7:  return "You're funding a whole new city's camera map 🗺️"
        case ..<0.95: return "You're a Guardian of the flock 🛡️ Thank you."
        default:      return "Legend. You're keeping this free for thousands 💙"
        }
    }

    // MARK: - Actions

    private func support() async {
        guard let pkg = selectedPackage else {
            // Real tiers aren't configured in RevenueCat yet — be honest, don't fake a charge.
            errorText = "Supporter tiers go live with the next update. Thanks for the love 💙"
            return
        }
        errorText = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await subscriptionManager.donate(package: pkg)
            HapticManager.notification(.success)
            withAnimation(.spring(response: 0.4)) { showThanks = true }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            dismiss()
        } catch let e as PurchaseError {
            if case .purchaseCancelled = e { return }
            errorText = e.errorDescription
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// The radar-ring bird mark, reused from the app icon, as an inline vector.
struct RadarBirdMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(Color.flockPrimary.opacity(0.30), lineWidth: s * 0.024)
                    .frame(width: s * 0.68, height: s * 0.68)
                Circle().stroke(Color.flockPrimary.opacity(0.55), lineWidth: s * 0.028)
                    .frame(width: s * 0.42, height: s * 0.42)
                BirdShape()
                    .fill(Color.flockText)
                    .frame(width: s * 0.52, height: s * 0.24)
            }
            .frame(width: s, height: s)
        }
    }
}

/// The two-wing flyer silhouette used in the app icon.
struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: p(0.50, 1.0))
        path.addCurve(to: p(0.0, 0.0),  control1: p(0.40, 0.56), control2: p(0.19, 0.19))
        path.addCurve(to: p(0.50, 0.63), control1: p(0.36, 0.13), control2: p(0.43, 0.31))
        path.addCurve(to: p(1.0, 0.0),  control1: p(0.57, 0.31), control2: p(0.64, 0.13))
        path.addCurve(to: p(0.50, 1.0), control1: p(0.81, 0.19), control2: p(0.60, 0.56))
        path.closeSubpath()
        return path
    }
}

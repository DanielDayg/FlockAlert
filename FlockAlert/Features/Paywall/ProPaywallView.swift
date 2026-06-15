import SwiftUI
import RevenueCat

struct ProPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackageID: String? = AppConfiguration.supporterMonthlyID
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var loadFailed = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false

    // Packages keyed by product ID
    private var packageMap: [String: Package] {
        var map: [String: Package] = [:]
        for pkg in subscriptionManager.currentOffering?.availablePackages ?? [] {
            map[pkg.storeProduct.productIdentifier] = pkg
        }
        return map
    }

    private var supporterPackage: Package? { packageMap[AppConfiguration.supporterMonthlyID] }
    private var guardianPackage: Package?  { packageMap[AppConfiguration.guardianMonthlyID] }
    private var productsLoaded: Bool { supporterPackage != nil || guardianPackage != nil }

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ────────────────────────────────────────
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.flockPrimary.opacity(0.12))
                                .frame(width: 88, height: 88)
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.flockPrimary)
                        }
                        .padding(.top, 36)

                        Text("Support the Fight\nfor Privacy")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color.flockText)
                            .multilineTextAlignment(.center)

                        Text("Every dollar helps map surveillance cameras.\nChoose what you get in return.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.flockTextSub)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 32)

                    // ── Tier Cards ────────────────────────────────────
                    VStack(spacing: 14) {

                        // ── Supporter $3.99 ──
                        TierCard(
                            emoji: "🟦",
                            name: "Supporter",
                            price: supporterPackage?.storeProduct.localizedPriceString ?? "$3.99",
                            isSelected: selectedPackageID == AppConfiguration.supporterMonthlyID,
                            isLoading: !productsLoaded,
                            features: [
                                ("bell.fill",              "Drive-by proximity alerts"),
                                ("waveform.badge.mic",     "Voice alerts while driving"),
                                ("bird.fill",              "Bird chirp alert sound"),
                                ("eye.fill",               "In-view camera detection"),
                            ]
                        ) {
                            selectedPackageID = AppConfiguration.supporterMonthlyID
                            HapticManager.impact(.light)
                        }

                        // ── Guardian $5.99 ──
                        TierCard(
                            emoji: "🔷",
                            name: "Guardian",
                            price: guardianPackage?.storeProduct.localizedPriceString ?? "$5.99",
                            badge: "BEST VALUE",
                            isSelected: selectedPackageID == AppConfiguration.guardianMonthlyID,
                            isLoading: !productsLoaded,
                            features: [
                                ("bell.fill",              "Everything in Supporter"),
                                ("photo.stack.fill",       "Community camera photos"),
                                ("trophy.fill",            "Leaderboard access"),
                                ("star.fill",              "Priority submission review"),
                                ("shield.fill",            "Guardian badge on profile"),
                            ]
                        ) {
                            selectedPackageID = AppConfiguration.guardianMonthlyID
                            HapticManager.impact(.light)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // ── Purchase button ───────────────────────────────
                    Button {
                        guard let id = selectedPackageID,
                              let pkg = packageMap[id] else { return }
                        Task { await purchase(pkg) }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Unlock \(selectedPackageID == AppConfiguration.guardianMonthlyID ? "Guardian" : "Supporter") Access")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(productsLoaded ? Color.flockPrimary : Color.flockTextSub.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!productsLoaded || isPurchasing)
                    .padding(.horizontal, 20)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.flockAlert)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    if loadFailed {
                        Button {
                            loadFailed = false
                            Task { await loadProducts() }
                        } label: {
                            Label("Retry loading prices", systemImage: "arrow.clockwise")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.flockPrimary)
                        }
                        .padding(.top, 8)
                    }

                    Text("Cancel anytime. Renews monthly.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.flockTextSub.opacity(0.5))
                        .padding(.top, 8)

                    // ── Restore ───────────────────────────────────────
                    Button {
                        Task {
                            try? await subscriptionManager.restorePurchases()
                            if subscriptionManager.isPro { dismiss() }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.flockTextSub.opacity(0.45))
                    }
                    .padding(.top, 14)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)

                    // ── Freedom button ────────────────────────────────
                    Button { dismiss() } label: {
                        Text("I can't afford it, but I believe in my right to privacy →")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.flockTextSub.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 12)

                    // ── Required legal links (guideline 3.1.2c) ───────
                    HStack(spacing: 16) {
                        Button("Privacy Policy") { showPrivacyPolicy = true }
                            .underline()
                        Button("Terms of Use") { showTerms = true }
                            .underline()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.flockPrimary.opacity(0.8))
                    .padding(.bottom, 32)
                }
            }
        }
        .task { await loadProducts() }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
        .sheet(isPresented: $showTerms) { DisclaimerView() }
        .preferredColorScheme(.dark)
    }

    private func loadProducts() async {
        await subscriptionManager.fetchOffering()
        try? await Task.sleep(nanoseconds: 600_000_000)
        if !productsLoaded { loadFailed = true }
    }

    private func purchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await subscriptionManager.purchase(package: package)
            dismiss()
        } catch PurchaseError.purchaseCancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Tier Card

struct TierCard: View {
    let emoji: String
    let name: String
    let price: String
    var badge: String? = nil
    let isSelected: Bool
    let isLoading: Bool
    let features: [(String, String)]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // Header row
                HStack(spacing: 10) {
                    Text(emoji)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(isSelected ? Color.flockPrimary : Color.flockText)
                            if let badge {
                                Text(badge)
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.flockPrimary)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.flockPrimary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(isLoading ? "Loading..." : "\(price) / month")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.flockTextSub)
                            .redacted(reason: isLoading ? .placeholder : [])
                    }
                    Spacer()
                    // Radio
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Color.flockPrimary : Color.flockTextSub.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle().fill(Color.flockPrimary).frame(width: 12, height: 12)
                        }
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)

                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.1) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: feature.0)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.flockPrimary)
                                .frame(width: 18)
                            Text(feature.1)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.flockText)
                        }
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.flockPrimary.opacity(0.07) : Color.flockSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.flockPrimary.opacity(0.5) : Color.white.opacity(0.07), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - ProFeatureRow (kept for other uses)

struct ProFeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.flockPrimary)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.flockText)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.flockSafe)
        }
    }
}

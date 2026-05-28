import SwiftUI
import RevenueCat

// MARK: - ProPaywallView
//
// "Pay what you want" monthly paywall.
// Three price tiers — all grant the same FlockAlert Pro entitlement.
// Packages are fetched from RevenueCat and sorted by price ascending.

struct ProPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    // Monthly packages from the current offering, sorted cheapest → most expensive
    private var monthlyPackages: [Package] {
        (subscriptionManager.currentOffering?.availablePackages ?? [])
            .filter {
                let id = $0.storeProduct.productIdentifier
                return id.contains("monthly")
            }
            .sorted { $0.storeProduct.price < $1.storeProduct.price }
    }

    // Middle tier is pre-selected / marked "most common"
    private var popularPackage: Package? {
        let pkgs = monthlyPackages
        guard pkgs.count >= 2 else { return pkgs.first }
        return pkgs[pkgs.count / 2]
    }

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────
                    VStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.flockPrimary)
                            .padding(.top, 40)

                        Text("Support the Fight\nfor Privacy")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Color.flockText)
                            .multilineTextAlignment(.center)

                        Text("Choose what feels right.\nEvery dollar funds open surveillance transparency.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.flockTextSub)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 28)

                    // ── Pro features ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        ProFeatureRow(icon: "photo.stack.fill",
                                      text: "Community camera photos")
                        ProFeatureRow(icon: "waveform.badge.mic",
                                      text: "Voice proximity alerts")
                        ProFeatureRow(icon: "bird.fill",
                                      text: "Bird chirp alert tone")
                        ProFeatureRow(icon: "eye.fill",
                                      text: "In-view detection")
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)

                    // ── Price tiers ───────────────────────────────────
                    if monthlyPackages.isEmpty {
                        ProgressView()
                            .tint(Color.flockPrimary)
                            .padding(.bottom, 32)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(monthlyPackages, id: \.identifier) { pkg in
                                PriceTierCard(
                                    package: pkg,
                                    isSelected: selectedPackage?.identifier == pkg.identifier,
                                    isPopular: pkg.identifier == popularPackage?.identifier
                                ) {
                                    selectedPackage = pkg
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }

                    // ── Purchase button ───────────────────────────────
                    Button {
                        guard let pkg = selectedPackage else { return }
                        Task { await purchase(pkg) }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text(selectedPackage == nil
                                     ? "Select a Contribution"
                                     : "Support Flock Alert Pro")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            selectedPackage == nil
                                ? Color.flockTextSub.opacity(0.25)
                                : Color.flockPrimary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(selectedPackage == nil || isPurchasing)
                    .padding(.horizontal, 20)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.flockAlert)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

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

                    // ── Divider ───────────────────────────────────────
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 24)

                    // ── Freedom button ────────────────────────────────
                    Button { dismiss() } label: {
                        Text("I can't afford it, but I believe in my right to privacy →")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.flockTextSub.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 36)
                }
            }
        }
        .task { await subscriptionManager.fetchOffering() }
        .onAppear {
            if selectedPackage == nil {
                selectedPackage = popularPackage
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Purchase

    private func purchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await subscriptionManager.purchase(package: package)
            dismiss()
        } catch PurchaseError.purchaseCancelled {
            // User cancelled — silently ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - PriceTierCard

struct PriceTierCard: View {
    let package: Package
    let isSelected: Bool
    let isPopular: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio circle
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.flockPrimary : Color.flockTextSub.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.flockPrimary)
                            .frame(width: 12, height: 12)
                    }
                }

                // Price + label
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(package.storeProduct.localizedPriceString + " / month")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(isSelected ? Color.flockPrimary : Color.flockText)

                        if isPopular {
                            Text("MOST COMMON")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(Color.flockPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.flockPrimary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.flockPrimary.opacity(0.07) : Color.flockSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? Color.flockPrimary.opacity(0.45) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - ProFeatureRow

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

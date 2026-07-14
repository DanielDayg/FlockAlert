import SwiftUI
import SwiftData
import RevenueCatUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var cameras: [Camera]
    @Query private var reports: [CameraReport]

    @State private var showPrivacyPolicy = false
    @State private var showDisclaimer = false
    @State private var showAbout = false
    @State private var showClearConfirm = false
    @State private var showPaywall = false
    @State private var showDonation = false
    @State private var showCustomerCenter = false
    @State private var showDeleteAccountConfirm = false
    @State private var shareCardImage: UIImage?
    @State private var showShareSheet = false

    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    /// Radius used for the shareable "surveillance near me" card.
    private let shareRadiusMiles = 2

    /// Count of active cameras within `shareRadiusMiles` of the user. Returns nil when
    /// location is unavailable — we must never share a "within 2 miles" figure computed
    /// from anything other than the user's actual location.
    private func camerasNearMe() -> Int? {
        guard let loc = appState.userLocation else { return nil }
        let radiusMetres = Double(shareRadiusMiles) * 1609.34
        return cameras.filter { $0.isActive && loc.distance(from: $0.clLocation) <= radiusMetres }.count
    }

    private func shareSurveillanceCard() {
        guard let count = camerasNearMe(),
              let img = renderSurveillanceCard(count: count, radiusMiles: shareRadiusMiles) else { return }
        shareCardImage = img
        showShareSheet = true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                List {
                    // ── Support banner — every feature is free ───────
                    Section {
                        if subscriptionManager.isSupporter {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(Color.flockPrimary)
                                Text("Supporter — thank you 💙")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.flockPrimary)
                                Spacer()
                            }
                            .listRowBackground(Color.flockPrimary.opacity(0.08))

                            Button { showCustomerCenter = true } label: {
                                SettingsRow(
                                    icon: "person.crop.circle.badge.checkmark",
                                    label: "Manage Support",
                                    sub: "Billing, change amount & cancel anytime",
                                    color: .flockPrimary
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button { showDonation = true } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.flockPrimary.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.flockPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Support Flock Alert")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.flockPrimary)
                                        Text("The app is 100% free — chip in if you can")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.flockTextSub)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.flockTextSub)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.flockPrimary.opacity(0.08))
                        }
                    }

                    // ── Spread the word ──────────────────────────────
                    Section {
                        Button {
                            shareSurveillanceCard()
                        } label: {
                            SettingsRow(icon: "square.and.arrow.up.fill", label: "Share surveillance near me",
                                        sub: appState.userLocation == nil
                                            ? "Enable location to see what's near you"
                                            : "Post the cameras tracking your area",
                                        color: .flockPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.userLocation == nil)
                        .opacity(appState.userLocation == nil ? 0.5 : 1)

                        Button {
                            // Opens the App Store review sheet directly. Apple's rules
                            // forbid asking for a specific star count, so we simply
                            // invite a rating and let users decide.
                            if let url = URL(string: "itms-apps://apps.apple.com/app/id6774017307?action=write-review") {
                                openURL(url)
                            }
                        } label: {
                            SettingsRow(icon: "star.fill", label: "Rate Flock Alert",
                                        sub: "A quick review helps others find it",
                                        color: .flockCaution)
                        }
                        .buttonStyle(.plain)
                    } header: {
                        ListHeader("SPREAD THE WORD")
                    }
                    .listRowBackground(Color.flockSurface)

                    // ── Status Card ──────────────────────────────────
                    Section {
                        StatusCard(
                            cameraCount: cameras.filter { $0.isActive }.count,
                            reportCount: reports.count,
                            isLocationOn: appState.isLocationAuthorized
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // ── Alert Settings ──────────────────────────────────
                    Section {
                        NavigationLink {
                            AlertSettingsView()
                        } label: {
                            SettingsRow(icon: "bell.badge.fill", label: "Alert Settings",
                                        sub: "\(appState.alertMode.label) · \(Int(appState.alertRadiusMetres * 3.281)) ft",
                                        color: .flockPrimary)
                        }

                        NavigationLink {
                            AlertSettingsView()
                        } label: {
                            SettingsRow(icon: "location.fill", label: "Location Access",
                                        sub: appState.isLocationAuthorized ? "Always On" : "Not Authorized",
                                        color: appState.isLocationAuthorized ? .flockSafe : .flockAlert)
                        }
                    } header: {
                        ListHeader("ALERTS & LOCATION")
                    }
                    .listRowBackground(Color.flockSurface)

                    // ── Map ──────────────────────────────────────────
                    Section {
                        SettingsRow(icon: "map.fill", label: "Surveillance Heatmap",
                                    sub: appState.showHeatmap ? "Enabled" : "Disabled",
                                    color: .flockCaution)
                        .contentShape(Rectangle())
                        .onTapGesture { appState.showHeatmap.toggle() }
                    } header: {
                        ListHeader("MAP")
                    }
                    .listRowBackground(Color.flockSurface)

                    // ── Data ──────────────────────────────────────────
                    Section {
                        Button(role: .destructive) { showClearConfirm = true } label: {
                            SettingsRow(icon: "trash", label: "Clear Alert History",
                                        sub: "Removes logged alerts from this device",
                                        color: .flockAlert)
                        }
                    } header: {
                        ListHeader("DATA")
                    }
                    .listRowBackground(Color.flockSurface)

                    // ── Account ──────────────────────────────────────────
                    if authManager.isSignedIn {
                        Section {
                            Button(role: .destructive) {
                                showDeleteAccountConfirm = true
                            } label: {
                                SettingsRow(
                                    icon: "person.crop.circle.badge.minus",
                                    label: "Delete Account",
                                    sub: "Permanently removes your profile and data",
                                    color: .flockAlert
                                )
                            }
                            .buttonStyle(.plain)
                        } header: {
                            ListHeader("ACCOUNT")
                        }
                        .listRowBackground(Color.flockSurface)
                    }

                    // ── Legal ──────────────────────────────────────────
                    Section {
                        Button { showPrivacyPolicy = true } label: {
                            SettingsRow(icon: "hand.raised.fill", label: "Privacy Policy",
                                        sub: "How we handle your data", color: .flockPrimary)
                        }
                        Button { showDisclaimer = true } label: {
                            SettingsRow(icon: "doc.text", label: "Legal Disclaimer",
                                        sub: "Terms of use", color: .flockPrimary)
                        }
                        Link(destination: URL(string: "https://www.eff.org")!) {
                            SettingsRow(icon: "safari", label: "EFF — Digital Rights",
                                        sub: "Our civil liberties partner", color: .skyBlue)
                        }
                    } header: {
                        ListHeader("LEGAL & RESOURCES")
                    }
                    .listRowBackground(Color.flockSurface)

                    // ── About ──────────────────────────────────────────
                    Section {
                        Button { showAbout = true } label: {
                            SettingsRow(icon: "info.circle.fill", label: "About Flock Alert",
                                        sub: "v\(appVersion)", color: .flockTextSub)
                        }
                        Link(destination: URL(string: "https://github.com")!) {
                            SettingsRow(icon: "chevron.left.forwardslash.chevron.right",
                                        label: "Open Source",
                                        sub: "Camera database is publicly licensed", color: .flockSafe)
                        }
                    } header: {
                        ListHeader("ABOUT")
                    }
                    .listRowBackground(Color.flockSurface)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showPaywall) { ProPaywallView().environmentObject(subscriptionManager) }
        .sheet(isPresented: $showDonation) { DonationView().environmentObject(subscriptionManager) }
        .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
        .sheet(isPresented: $showDisclaimer) { DisclaimerView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareCardImage { ShareSheet(items: [img]) }
        }
        .confirmationDialog("Clear Alert History?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All Alerts", role: .destructive) { clearAlerts() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes alert logs from your device. Camera data is not affected.")
        }
        .confirmationDialog("Delete Account?", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                authManager.deleteAccount(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your profile, points, and contributions. This action cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }

    private func clearAlerts() {
        let desc = FetchDescriptor<AlertEvent>()
        if let events = try? modelContext.fetch(desc) {
            events.forEach { modelContext.delete($0) }
            try? modelContext.save()
        }
        appState.unreadAlertCount = 0
    }
}

// MARK: - Sub-components

struct StatusCard: View {
    let cameraCount: Int
    let reportCount: Int
    let isLocationOn: Bool

    var body: some View {
        GlassCard {
            HStack(spacing: 0) {
                StatusStat(value: "\(cameraCount)", label: "CAMERAS", color: .flockPrimary)
                Divider().frame(height: 36).background(Color.white.opacity(0.1))
                StatusStat(value: "\(reportCount)", label: "MY REPORTS", color: .flockSafe)
                Divider().frame(height: 36).background(Color.white.opacity(0.1))
                StatusStat(
                    value: isLocationOn ? "ON" : "OFF",
                    label: "LOCATION",
                    color: isLocationOn ? .flockSafe : .flockAlert
                )
            }
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct StatusStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.flockTextSub)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let sub: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.flockText)
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flockTextSub)
            }
        }
    }
}

struct ListHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.flockTextSub)
            .tracking(1.5)
    }
}

// MARK: - Legal Sheets

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy Policy")
                            .font(.flockTitle)
                            .foregroundStyle(Color.flockText)

                        Group {
                            PolicySection(title: "Location Data", content: "Your GPS location is processed entirely on your device. We do not store, transmit, or log your location to any server.")
                            PolicySection(title: "No Account Required", content: "Flock Alert does not require you to create an account. All features work without providing any personal information.")
                            PolicySection(title: "Camera Reports", content: "When you submit a camera report, we collect only the camera location, type, and optional photo. No personal identifying information is attached to reports.")
                            PolicySection(title: "Analytics", content: "We collect only anonymous crash reports (opt-in) to improve app stability. No usage analytics, tracking, or ad targeting.")
                            PolicySection(title: "Data Sales", content: "We do not sell, rent, or share your data with third parties for commercial purposes. Period.")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.flockPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct DisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Legal Disclaimer")
                            .font(.flockTitle)
                            .foregroundStyle(Color.flockText)
                        PolicySection(title: "Purpose", content: "Flock Alert is a public transparency and privacy awareness application. It is not affiliated with Flock Safety, LLC.")
                        PolicySection(title: "Not Legal Advice", content: "Nothing in this app constitutes legal advice. For legal questions about surveillance and your rights, consult a qualified attorney.")
                        PolicySection(title: "Data Accuracy", content: "Camera location data is sourced from public records, community reports, and open datasets. We do not guarantee accuracy or completeness.")
                        PolicySection(title: "Intended Use", content: "This app is intended for lawful transparency and awareness purposes only. Use for illegal activity, police evasion, or interference with law enforcement is strictly prohibited.")
                        PolicySection(title: "No Interference", content: "This app does not interfere with, jam, disable, or otherwise affect the operation of any surveillance camera or system.")
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Legal Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.flockPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "eye.trianglebadge.exclamationmark")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.flockPrimary)
                            Text("Flock Alert")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(Color.flockText)
                            Text("The Waze of public surveillance transparency.")
                                .font(.flockBody)
                                .foregroundStyle(Color.flockTextSub)
                                .multilineTextAlignment(.center)
                            Text("Built for informed citizens.\nPowered by open data.\nFor civil liberties.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.flockTextSub.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 32)

                        // ── Early Access Notice ───────────────────────────
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "hammer.fill")
                                    .foregroundStyle(Color.flockCaution)
                                Text("Early Access")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.flockText)
                                Spacer()
                            }
                            Text("Flock Alert is a brand-new app and we're constantly shipping improvements. You may encounter occasional bugs — we appreciate your patience as we make this the best it can be.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.flockTextSub)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(Color.flockSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // ── Bug Report ────────────────────────────────────
                        Button {
                            let subject = "Flock Alert Bug Report".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            let body = "Describe the issue below:\n\n\nDevice: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)\nApp Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
                                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "mailto:danielstockday@gmail.com?subject=\(subject)&body=\(body)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 15))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Report a Bug")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Help us improve Flock Alert")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.flockTextSub)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.flockTextSub)
                            }
                            .foregroundStyle(Color.flockText)
                            .padding(16)
                            .background(Color.flockSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.flockPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct PolicySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.flockText)
            Text(content)
                .font(.system(size: 13))
                .foregroundStyle(Color.flockTextSub)
                .lineSpacing(4)
        }
        .padding(14)
        .background(Color.flockSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

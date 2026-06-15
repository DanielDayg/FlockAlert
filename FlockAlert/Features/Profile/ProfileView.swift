import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CameraVerification.submittedAt, order: .reverse) private var verifications: [CameraVerification]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // ── Route Planner — visible to everyone ────────────
                        NavigationLink(destination: RouteView()) {
                            GlassCard(cornerRadius: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.green.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(Color.green)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text("Camera-Free Route Planner")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.flockText)
                                            if !subscriptionManager.isGuardian {
                                                Text("GUARDIAN")
                                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(Color(hex: "FFB800"))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color(hex: "FFB800").opacity(0.15))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                        Text(subscriptionManager.isGuardian
                                             ? "Navigate around surveillance cameras"
                                             : "Upgrade to Guardian to evade the grid")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.flockTextSub)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.green)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .buttonStyle(.plain)

                        // ── Leaderboard — visible to everyone ──────────────
                        NavigationLink(destination: LeaderboardView().environmentObject(subscriptionManager)) {
                            GlassCard(cornerRadius: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(hex: "FFB800").opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color(hex: "FFD700"), Color(hex: "FF6B00")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text("Community Leaderboard")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.flockText)
                                            if !subscriptionManager.isGuardian {
                                                Text("GUARDIAN")
                                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(Color(hex: "FFB800"))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color(hex: "FFB800").opacity(0.15))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                        Text(subscriptionManager.isGuardian
                                             ? "See your global rank among contributors"
                                             : "Upgrade to Guardian to access rankings")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.flockTextSub)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.flockTextSub)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .buttonStyle(.plain)

                        // ── Profile content ────────────────────────────────
                        if authManager.isSignedIn, let profile = authManager.currentProfile {
                            SignedInProfile(profile: profile, verifications: verifications)
                        } else {
                            SignInPrompt()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.flockPrimary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sign In Prompt

private struct SignInPrompt: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 32) {
                Spacer(minLength: 40)

                // App icon area
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.flockPrimary.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.flockPrimary, Color.flockSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 10) {
                    Text("Join the Network")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.flockText)

                    Text("Sign in to earn points, track your contributions,\nand unlock badges as you help document\nsurveillance cameras.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.flockTextSub)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Points system card
                GlassCard(cornerRadius: 18) {
                    VStack(spacing: 0) {
                        Text("HOW TO EARN POINTS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                            .tracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        Divider().background(Color.white.opacity(0.07))

                        EarnRow(icon: "camera.fill", label: "Camera Report", points: "+10", color: .flockPrimary)
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        EarnRow(icon: "photo.fill", label: "Photo Verification", points: "+25", color: .flockSafe)
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        EarnRow(icon: "star.circle.fill", label: "First Report Bonus", points: "+50", color: .flockCaution)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)

                // Badge tiers
                GlassCard(cornerRadius: 18) {
                    VStack(spacing: 0) {
                        Text("BADGE TIERS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                            .tracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        Divider().background(Color.white.opacity(0.07))

                        BadgeTierRow(tier: .scout,        range: "0–49 pts")
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        BadgeTierRow(tier: .watcher,      range: "50–199 pts")
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        BadgeTierRow(tier: .investigator, range: "200–499 pts")
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        BadgeTierRow(tier: .guardian,     range: "500–999 pts")
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        BadgeTierRow(tier: .watchdog,     range: "1000+ pts")
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)

                // Sign in button
                Button {
                    authManager.signIn()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Sign in with Apple")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Text("Your Apple ID is used only to identify your account locally. We don't share your information.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flockTextSub.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 100)
            }
    }
}

// MARK: - Signed In Profile

private struct SignedInProfile: View {
    let profile: UserProfile
    let verifications: [CameraVerification]
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false

    private var progressFraction: Double {
        let range = Double(profile.nextBadgeTotal - profile.currentBadgeStart)
        guard range > 0 else { return 1.0 }
        let progress = Double(profile.points - profile.currentBadgeStart)
        return min(1.0, max(0.0, progress / range))
    }

    private var badgeColor: Color {
        Color(hex: profile.badgeTier.color)
    }

    private var initials: String {
        let parts = profile.displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map { String($0) } }
        return letters.joined().uppercased().isEmpty ? "FA" : letters.joined().uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ── Avatar + Badge Header ──────────────────────────────
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 16) {
                        HStack(spacing: 18) {
                            // Avatar circle
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [badgeColor.opacity(0.7), badgeColor.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 72, height: 72)

                                Text(initials)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .overlay(
                                Circle()
                                    .strokeBorder(badgeColor.opacity(0.5), lineWidth: 2)
                            )

                            VStack(alignment: .leading, spacing: 5) {
                                Text(profile.displayName)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.flockText)

                                HStack(spacing: 6) {
                                    Image(systemName: profile.badgeTier.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(badgeColor)
                                    Text(profile.badgeTier.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(badgeColor)
                                }

                                Text("Member since \(profile.joinDate.formatted(.dateTime.month().year()))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.flockTextSub)
                            }

                            Spacer()
                        }

                        // Progress bar
                        VStack(spacing: 6) {
                            HStack {
                                Text(profile.badgeTier.rawValue.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(badgeColor)
                                Spacer()
                                if profile.badgeTier != .watchdog {
                                    Text("\(profile.pointsToNextBadge) pts to \(nextTierName)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color.flockTextSub)
                                } else {
                                    Text("MAX RANK")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(badgeColor)
                                }
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [badgeColor, badgeColor.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * progressFraction, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(20)
                }

                // ── Stats Row ──────────────────────────────────────────
                HStack(spacing: 10) {
                    ProfileStatPill(value: "\(profile.camerasReported)", label: "Cameras", icon: "camera.fill", color: .flockPrimary)
                    ProfileStatPill(value: "\(profile.photosUploaded)", label: "Photos", icon: "photo.fill", color: .flockSafe)
                    ProfileStatPill(value: "\(profile.points)", label: "Points", icon: profile.badgeTier.icon, color: badgeColor)
                }

                // ── Leaderboard ────────────────────────────────────────
                NavigationLink(destination: LeaderboardView().environmentObject(subscriptionManager)) {
                    GlassCard(cornerRadius: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "FFB800").opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "FFD700"), Color(hex: "FF6B00")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Community Leaderboard")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.flockText)
                                    if !subscriptionManager.isGuardian {
                                        Text("GUARDIAN")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color(hex: "FFB800"))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "FFB800").opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                                Text(subscriptionManager.isGuardian
                                     ? "See how you rank against the community"
                                     : "Upgrade to Guardian to access rankings")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.flockTextSub)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.flockTextSub)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.plain)

                // ── Camera-Free Route Planner ──────────────────────────
                NavigationLink(destination: RouteView()) {
                    GlassCard(cornerRadius: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "map.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.green)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Camera-Free Route Planner")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.flockText)
                                    if !subscriptionManager.isGuardian {
                                        Text("GUARDIAN")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color(hex: "FFB800"))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "FFB800").opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                                Text(subscriptionManager.isGuardian
                                     ? "Navigate around surveillance cameras"
                                     : "Upgrade to Guardian to evade the grid")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.flockTextSub)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.flockTextSub)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.plain)

                // ── How to Earn ────────────────────────────────────────
                GlassCard(cornerRadius: 18) {
                    VStack(spacing: 0) {
                        Text("HOW TO EARN POINTS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                            .tracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        Divider().background(Color.white.opacity(0.07))

                        EarnRow(icon: "camera.fill", label: "Camera Report", points: "+10", color: .flockPrimary)
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        EarnRow(icon: "photo.fill", label: "Photo Verification", points: "+25", color: .flockSafe)
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                        EarnRow(icon: "star.circle.fill", label: "First Report Bonus", points: "+50", color: .flockCaution)
                    }
                    .padding(.bottom, 8)
                }

                // ── Recent Verifications ───────────────────────────────
                if !verifications.isEmpty {
                    GlassCard(cornerRadius: 18) {
                        VStack(spacing: 0) {
                            Text("RECENT VERIFICATIONS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.flockTextSub)
                                .tracking(1.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                                .padding(.bottom, 12)

                            Divider().background(Color.white.opacity(0.07))

                            ForEach(Array(verifications.prefix(5)), id: \.id) { v in
                                VerificationRow(verification: v)
                                if v.id != verifications.prefix(5).last?.id {
                                    Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }

                // ── Sign Out ───────────────────────────────────────────
                Button {
                    authManager.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.flockAlert)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.flockAlert.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.flockAlert.opacity(0.2), lineWidth: 1)
                    )
                }

                // ── Delete Account ─────────────────────────────────────
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Delete Account")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.flockAlert.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.flockAlert.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.flockAlert.opacity(0.12), lineWidth: 1)
                    )
                }
                .confirmationDialog(
                    "Delete Account?",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete Account", role: .destructive) {
                        authManager.deleteAccount(context: modelContext)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently deletes your profile, points, and contributions from this device. This action cannot be undone.")
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var nextTierName: String {
        switch profile.badgeTier {
        case .scout:        return "Watcher"
        case .watcher:      return "Investigator"
        case .investigator: return "Guardian"
        case .guardian:     return "Watchdog"
        case .watchdog:     return "Max"
        }
    }
}

// MARK: - Sub-components

private struct ProfileStatPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard(cornerRadius: 14) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)

                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.flockText)

                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.flockTextSub)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}

private struct EarnRow: View {
    let icon: String
    let label: String
    let points: String
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
            .padding(.leading, 18)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.flockText)

            Spacer()

            Text(points)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.trailing, 18)
        }
        .padding(.vertical, 12)
    }
}

private struct BadgeTierRow: View {
    let tier: UserProfile.BadgeTier
    let range: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: tier.color).opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: tier.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: tier.color))
            }
            .padding(.leading, 18)

            Text(tier.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.flockText)

            Spacer()

            Text(range)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.flockTextSub)
                .padding(.trailing, 18)
        }
        .padding(.vertical, 12)
    }
}

private struct VerificationRow: View {
    let verification: CameraVerification

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.flockSafe.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: verification.photoData != nil ? "photo.fill" : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.flockSafe)
            }
            .padding(.leading, 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(verification.note ?? "Camera verified")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.flockText)
                    .lineLimit(1)
                Text(verification.submittedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flockTextSub)
            }

            Spacer()

            Text("+\(verification.pointsAwarded)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.flockSafe)
                .padding(.trailing, 18)
        }
        .padding(.vertical, 12)
    }
}

import SwiftUI
import SwiftData

// MARK: - Leaderboard Entry Model

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let displayName: String
    let points: Int
    let camerasReported: Int
    let badgeTier: UserProfile.BadgeTier

    static let mockEntries: [LeaderboardEntry] = [
        LeaderboardEntry(rank: 1,  displayName: "Zara Okonkwo",      points: 2840, camerasReported: 58, badgeTier: .watchdog),
        LeaderboardEntry(rank: 2,  displayName: "Cruz",               points: 1920, camerasReported: 41, badgeTier: .watchdog),
        LeaderboardEntry(rank: 3,  displayName: "Yuki Nakamura",      points: 1380, camerasReported: 29, badgeTier: .watchdog),
        LeaderboardEntry(rank: 4,  displayName: "PrivacyHawk_TX",     points: 940,  camerasReported: 21, badgeTier: .guardian),
        LeaderboardEntry(rank: 5,  displayName: "NoTrack_Boston",     points: 720,  camerasReported: 15, badgeTier: .guardian),
        LeaderboardEntry(rank: 6,  displayName: "GridWatcher_LA",     points: 580,  camerasReported: 13, badgeTier: .guardian),
        LeaderboardEntry(rank: 7,  displayName: "AnonymousRoute",     points: 410,  camerasReported: 10, badgeTier: .investigator),
        LeaderboardEntry(rank: 8,  displayName: "DarkLane_PDX",       points: 290,  camerasReported: 7,  badgeTier: .investigator),
        LeaderboardEntry(rank: 9,  displayName: "SilentMile",         points: 180,  camerasReported: 5,  badgeTier: .watcher),
        LeaderboardEntry(rank: 10, displayName: "BlindSpot_AZ",       points: 95,   camerasReported: 3,  badgeTier: .watcher),
    ]
}

// MARK: - LeaderboardView

struct LeaderboardView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Query(sort: \UserProfile.joinDate, order: .forward) private var profiles: [UserProfile]

    private var myProfile: UserProfile? { profiles.first }
    private let entries = LeaderboardEntry.mockEntries

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            if myProfile?.isGuest == true && !subscriptionManager.isGuardian {
                GuestGateView()
            } else if !subscriptionManager.isGuardian {
                GuardianGateView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {

                        // ── User's own rank ─────────────────────────────
                        if let profile = myProfile {
                            MyRankCard(profile: profile)
                        } else {
                            SignInForRankCard()
                        }

                        // ── Community tier distribution ──────────────────
                        TierBreakdownCard()

                        // ── Top contributors ─────────────────────────────
                        TopContributorsCard(entries: entries)

                        Text("Rankings reflect verified camera submissions\nand update weekly.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.flockTextSub.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("The Watchlist")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Guardian Gate

private struct GuardianGateView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "FFB800").opacity(0.25), Color.clear],
                            center: .center, startRadius: 20, endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FF6B00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("Guardian Exclusive")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.flockText)

                Text("The community leaderboard is a Guardian-only feature. Upgrade to see your global rank and compete with top contributors.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            NavigationLink(destination: ProPaywallView()) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Upgrade to Guardian")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.flockBG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FFB800"), Color(hex: "FF6B00")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - My Rank Card

private struct MyRankCard: View {
    let profile: UserProfile
    private var badgeColor: Color { Color(hex: profile.badgeTier.color) }

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 0) {
                HStack {
                    Text("YOUR RANK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.flockTextSub)
                        .tracking(1.5)
                    Spacer()
                    Text("COMMUNITY MEMBER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.flockPrimary)
                        .tracking(0.8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.07))

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(badgeColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Circle()
                            .strokeBorder(badgeColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 56, height: 56)
                        Image(systemName: profile.badgeTier.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(badgeColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.flockText)
                        Text(profile.badgeTier.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(badgeColor)
                        Text("\(profile.points) pts · \(profile.camerasReported) cameras")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                    }

                    Spacer()

                    // Points badge
                    VStack(spacing: 2) {
                        Text("\(profile.points)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(badgeColor)
                        Text("PTS")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                            .tracking(1)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
        }
    }
}

// MARK: - Sign In Prompt Card

private struct SignInForRankCard: View {
    var body: some View {
        GlassCard(cornerRadius: 18) {
            VStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.flockPrimary)
                Text("Sign in to see your rank")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.flockText)
                Text("Sign in with Apple or continue as guest from the Profile tab to track your contributions.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}

// MARK: - Guest Gate

private struct GuestGateView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.flockPrimary.opacity(0.2), Color.clear],
                            center: .center, startRadius: 20, endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.flockPrimary)
            }

            VStack(spacing: 10) {
                Text("Full Account Required")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.flockText)

                Text("The Watchlist is available to Guardian subscribers.\nSign in with Apple to create a full account, then upgrade to join the rankings.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                    Text("Sign in from the Profile tab")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.flockBG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)

                Text("Guest progress stays on this device and won't appear on The Watchlist.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flockTextSub.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - Tier Breakdown Card

private struct TierBreakdownData: Identifiable {
    let id = UUID()
    let tier: UserProfile.BadgeTier
    let count: Int
    let fraction: Double
}

private struct TierBreakdownCard: View {
    private let tiers: [TierBreakdownData] = [
        TierBreakdownData(tier: .watchdog,     count: 12,  fraction: 0.03),
        TierBreakdownData(tier: .guardian,     count: 47,  fraction: 0.11),
        TierBreakdownData(tier: .investigator, count: 118, fraction: 0.28),
        TierBreakdownData(tier: .watcher,      count: 163, fraction: 0.39),
        TierBreakdownData(tier: .scout,        count: 81,  fraction: 0.19),
    ]

    var body: some View {
        GlassCard(cornerRadius: 18) {
            VStack(spacing: 0) {
                HStack {
                    Text("COMMUNITY TIERS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.flockTextSub)
                        .tracking(1.5)
                    Spacer()
                    Text("421 MEMBERS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.flockPrimary)
                        .tracking(0.8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.07))

                ForEach(Array(tiers.enumerated()), id: \.element.id) { idx, data in
                    TierBreakdownRow(data: data)
                    if idx < tiers.count - 1 {
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}

private struct TierBreakdownRow: View {
    let data: TierBreakdownData
    private var color: Color { Color(hex: data.tier.color) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: data.tier.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            .padding(.leading, 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(data.tier.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.flockText)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.75))
                            .frame(width: geo.size.width * data.fraction, height: 5)
                    }
                }
                .frame(height: 5)
            }

            Text("\(data.count)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .trailing)
                .padding(.trailing, 18)
        }
        .padding(.vertical, 13)
    }
}

// MARK: - Top Contributors Card

private struct TopContributorsCard: View {
    let entries: [LeaderboardEntry]

    var body: some View {
        GlassCard(cornerRadius: 18) {
            VStack(spacing: 0) {
                HStack {
                    Text("MOST WANTED WATCHERS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.flockTextSub)
                        .tracking(1.5)
                    Spacer()
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.flockTextSub)
                        .tracking(1.0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.07))

                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    ContributorRow(entry: entry)
                    if idx < entries.count - 1 {
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 54)
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}

private struct ContributorRow: View {
    let entry: LeaderboardEntry

    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color(hex: "FFD700")
        case 2: return Color(hex: "C0C0C0")
        case 3: return Color(hex: "CD7F32")
        default: return Color.flockTextSub
        }
    }

    private var tierColor: Color { Color(hex: entry.badgeTier.color) }

    var body: some View {
        HStack(spacing: 10) {
            // Rank
            Text(entry.rank <= 3 ? medalSymbol : "#\(entry.rank)")
                .font(.system(size: entry.rank <= 3 ? 18 : 11, weight: .black, design: .monospaced))
                .foregroundStyle(rankColor)
                .frame(width: 28)
                .padding(.leading, 14)

            // Badge icon
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(tierColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: entry.badgeTier.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tierColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.flockText)
                Text("\(entry.camerasReported) cameras · \(entry.badgeTier.rawValue)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.flockTextSub)
            }

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(entry.points)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(tierColor)
                Text("pts")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.flockTextSub)
            }
            .padding(.trailing, 14)
        }
        .padding(.vertical, 11)
    }

    private var medalSymbol: String {
        switch entry.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(entry.rank)"
        }
    }
}

import SwiftUI

// MARK: - Data Model

struct BannedCity: Identifiable {
    let id = UUID()
    let city: String
    let state: String
    let stateCode: String
    let status: BanStatus
    let description: String
    let year: Int?
    let sourceURL: String?

    enum BanStatus: String, CaseIterable {
        case banned        = "Banned"
        case restricted    = "Restricted"
        case moratorium    = "Moratorium"
        case pendingBan    = "Pending Ban"
        case ordinance     = "Ordinance Passed"

        var color: Color {
            switch self {
            case .banned:       return .flockSafe
            case .restricted:   return .flockPrimary
            case .moratorium:   return .flockCaution
            case .pendingBan:   return Color(hex: "FF9F0A")
            case .ordinance:    return .skyBlue
            }
        }

        var icon: String {
            switch self {
            case .banned:       return "xmark.shield.fill"
            case .restricted:   return "exclamationmark.shield.fill"
            case .moratorium:   return "clock.badge.xmark"
            case .pendingBan:   return "clock.badge.questionmark"
            case .ordinance:    return "doc.badge.checkmark"
            }
        }
    }
}

// MARK: - City Database
// Paste your full list here — add entries following the same format below.

struct BannedCitiesData {
    static let cities: [BannedCity] = [
        BannedCity(
            city: "Oakland", state: "California", stateCode: "CA",
            status: .ordinance,
            description: "Oakland's Surveillance and Community Safety Ordinance requires City Council approval before any surveillance technology can be deployed by city departments.",
            year: 2020, sourceURL: "https://www.oaklandca.gov"
        ),
        BannedCity(
            city: "Somerville", state: "Massachusetts", stateCode: "MA",
            status: .banned,
            description: "Somerville became one of the first US cities to ban government use of facial recognition and passed ordinances restricting ALPR data retention and sharing.",
            year: 2019, sourceURL: nil
        ),
        BannedCity(
            city: "San Francisco", state: "California", stateCode: "CA",
            status: .banned,
            description: "San Francisco banned city agencies from using facial recognition technology and has strict surveillance oversight ordinances covering ALPR systems.",
            year: 2019, sourceURL: "https://sf.gov"
        ),
        BannedCity(
            city: "Portland", state: "Oregon", stateCode: "OR",
            status: .banned,
            description: "Portland passed the strongest facial recognition ban in the US, extended to private entities, and has broader surveillance oversight covering ALPR.",
            year: 2020, sourceURL: nil
        ),
        BannedCity(
            city: "Boston", state: "Massachusetts", stateCode: "MA",
            status: .banned,
            description: "Boston banned city use of facial recognition technology and has active ALPR data retention restrictions limiting surveillance scope.",
            year: 2020, sourceURL: nil
        ),
        BannedCity(
            city: "Minneapolis", state: "Minnesota", stateCode: "MN",
            status: .restricted,
            description: "Minneapolis has city ordinances restricting how ALPR data can be retained and shared, requiring annual reporting on surveillance technology use.",
            year: 2021, sourceURL: nil
        ),
        BannedCity(
            city: "Cambridge", state: "Massachusetts", stateCode: "MA",
            status: .banned,
            description: "Cambridge banned all city use of facial recognition and passed a broader surveillance oversight ordinance requiring council approval for new tech.",
            year: 2020, sourceURL: nil
        ),
        BannedCity(
            city: "Brookline", state: "Massachusetts", stateCode: "MA",
            status: .banned,
            description: "Brookline passed a ban on government facial recognition and surveillance technology that includes restrictions on automated tracking systems.",
            year: 2021, sourceURL: nil
        ),
        BannedCity(
            city: "New Orleans", state: "Louisiana", stateCode: "LA",
            status: .restricted,
            description: "New Orleans implemented an ordinance restricting real-time facial recognition use by police, with broader privacy oversight recommendations.",
            year: 2022, sourceURL: nil
        ),
        BannedCity(
            city: "Springfield", state: "Massachusetts", stateCode: "MA",
            status: .moratorium,
            description: "Springfield placed a moratorium on new surveillance technology acquisitions pending community review and data privacy impact assessments.",
            year: 2022, sourceURL: nil
        ),
    ]

    static var statesRepresented: [String] {
        Array(Set(cities.map { $0.stateCode })).sorted()
    }
}

// MARK: - Main View

struct BannedCitiesView: View {
    @State private var selectedStatus: BannedCity.BanStatus? = nil
    @State private var selectedState: String? = nil
    @State private var searchText = ""

    private var filtered: [BannedCity] {
        BannedCitiesData.cities.filter { city in
            if let s = selectedStatus, city.status != s { return false }
            if let state = selectedState, city.stateCode != state { return false }
            if !searchText.isEmpty {
                return city.city.localizedCaseInsensitiveContains(searchText) ||
                       city.state.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Hero Stats ─────────────────────────────────
                    BannedStatsBar(cities: BannedCitiesData.cities)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // ── Status Filter ──────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryPill(label: "All", icon: "list.bullet", isSelected: selectedStatus == nil) {
                                selectedStatus = nil
                            }
                            ForEach(BannedCity.BanStatus.allCases, id: \.self) { s in
                                CategoryPill(
                                    label: s.rawValue,
                                    icon: s.icon,
                                    isSelected: selectedStatus == s
                                ) {
                                    selectedStatus = selectedStatus == s ? nil : s
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── City Cards ─────────────────────────────────
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.flockTextSub.opacity(0.4))
                            Text("No cities match")
                                .font(.flockHeadline)
                                .foregroundStyle(Color.flockTextSub)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { city in
                                BannedCityCard(city: city)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Contribute Banner ──────────────────────────
                    ContributeBanner()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                }
            }
            .searchable(text: $searchText, prompt: "Search cities or states…")
        }
        .navigationTitle("Cities & Bans")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Stats Bar

struct BannedStatsBar: View {
    let cities: [BannedCity]

    var bannedCount:     Int { cities.filter { $0.status == .banned }.count }
    var restrictedCount: Int { cities.filter { $0.status == .restricted || $0.status == .ordinance }.count }
    var pendingCount:    Int { cities.filter { $0.status == .pendingBan || $0.status == .moratorium }.count }

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "xmark.shield.fill")
                        .foregroundStyle(Color.flockSafe)
                    Text("Flock-Free & Restricted Jurisdictions")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.flockText)
                    Spacer()
                }

                HStack(spacing: 0) {
                    BannedStat(value: "\(bannedCount)", label: "BANNED", color: .flockSafe)
                    Divider().frame(height: 30).background(Color.white.opacity(0.1))
                    BannedStat(value: "\(restrictedCount)", label: "RESTRICTED", color: .flockPrimary)
                    Divider().frame(height: 30).background(Color.white.opacity(0.1))
                    BannedStat(value: "\(pendingCount)", label: "PENDING", color: .flockCaution)
                    Divider().frame(height: 30).background(Color.white.opacity(0.1))
                    BannedStat(value: "\(cities.count)", label: "TOTAL", color: Color.flockText)
                }
            }
            .padding(16)
        }
    }
}

struct BannedStat: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.flockTextSub)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - City Card

struct BannedCityCard: View {
    let city: BannedCity
    @State private var expanded = false

    var body: some View {
        GlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 12) {
                    // Status icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(city.status.color.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: city.status.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(city.status.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(city.city)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.flockText)
                            Text(city.stateCode)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.flockTextSub)
                        }
                        HStack(spacing: 6) {
                            Text(city.status.rawValue.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(city.status.color)
                                .tracking(1)
                            if let year = city.year {
                                Text("· \(year)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.flockTextSub)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.flockTextSub)
                }
                .padding(14)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expanded.toggle()
                    }
                    HapticManager.selection()
                }

                // Expanded detail
                if expanded {
                    Divider().background(Color.white.opacity(0.07))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(city.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.flockTextSub)
                            .lineSpacing(4)

                        if let urlString = city.sourceURL, let url = URL(string: urlString) {
                            Link(destination: url) {
                                Label("View Source", systemImage: "arrow.up.right.square")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.flockPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Contribute Banner

struct ContributeBanner: View {
    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.flockPrimary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Know a missing city?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.flockText)
                    Text("Help us keep this list updated with public records and news sources.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.flockTextSub)
                }
            }
            .padding(16)
        }
    }
}

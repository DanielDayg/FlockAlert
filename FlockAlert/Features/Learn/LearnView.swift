import SwiftUI

struct LearnView: View {
    @State private var selectedCategory: Article.Category? = nil
    @State private var searchText = ""

    private var filteredArticles: [Article] {
        var result = LearnContent.articles
        if let cat = selectedCategory { result = result.filter { $0.category == cat } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.intro.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Hero ──────────────────────────────────────
                        HeroCard()
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // ── Category Pills ──────────────────────────────
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CategoryPill(label: "All", icon: "square.grid.2x2", isSelected: selectedCategory == nil) {
                                    selectedCategory = nil
                                }
                                ForEach(Article.Category.allCases, id: \.self) { cat in
                                    CategoryPill(label: cat.rawValue, icon: cat.icon, isSelected: selectedCategory == cat) {
                                        selectedCategory = selectedCategory == cat ? nil : cat
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // ── Articles ──────────────────────────────────
                        LazyVStack(spacing: 12) {
                            ForEach(filteredArticles) { article in
                                NavigationLink(destination: ArticleView(article: article)) {
                                    ArticleCard(article: article)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 100)
                    }
                }
                .searchable(text: $searchText, prompt: "Search articles…")
            }
            .navigationTitle("Privacy Learn")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Hero Card

struct HeroCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.flockPrimary)
                    Spacer()
                    Text("PRIVACY EDUCATION")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.flockTextSub)
                        .tracking(1.5)
                }
                Text("Understand surveillance in your community")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.flockText)
                Text("Non-partisan, factual, research-backed.")
                    .font(.flockBody)
                    .foregroundStyle(Color.flockTextSub)
            }
            .padding(18)
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.flockBG : Color.flockTextSub)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.flockPrimary : Color.flockSurface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Article Card

struct ArticleCard: View {
    let article: Article

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.flockPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: article.category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.flockPrimary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(article.category.rawValue.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                            .tracking(1)
                        Spacer()
                        Text("\(article.readMinutes) min")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                    }

                    Text(article.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.flockText)
                        .multilineTextAlignment(.leading)

                    Text(article.intro)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.flockTextSub)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
        }
    }
}

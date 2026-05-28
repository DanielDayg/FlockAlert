import SwiftUI

struct ArticleView: View {
    let article: Article

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(article.category.rawValue, systemImage: article.category.icon)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.flockPrimary)
                            Spacer()
                            Text("\(article.readMinutes) min read")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.flockTextSub)
                        }

                        Text(article.title)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(Color.flockText)

                        Text(article.intro)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.flockTextSub)
                            .lineSpacing(4)
                    }
                    .padding(20)

                    Divider().background(Color.white.opacity(0.08))

                    // Sections
                    ForEach(article.sections.indices, id: \.self) { i in
                        let section = article.sections[i]
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.heading)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.flockText)

                            Text(section.body)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.flockTextSub.opacity(0.9))
                                .lineSpacing(5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        if i < article.sections.count - 1 {
                            Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 20)
                        }
                    }

                    // Disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Editorial Note", systemImage: "info.circle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.flockTextSub)
                        Text("This content is for informational purposes only. Flock Alert does not provide legal advice. For legal questions about your rights, consult a qualified attorney or contact the ACLU or EFF.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.flockTextSub.opacity(0.7))
                    }
                    .padding(16)
                    .background(Color.flockSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

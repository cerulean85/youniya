import SwiftUI

/// 04 Home: today's prompt, hero constellation, and recent stars.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    var onCompose: () -> Void
    var onOpenStar: (StarItem) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                SkyHeader(subtitle: "\(Self.todayText) · 오늘은 어떤 마음이 머물렀나요?")

                Button("오늘의 별 만들기", action: onCompose)
                    .buttonStyle(.primary)

                HeroConstellation()

                Text("최근 별")
                    .textStyle(.labelM)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                LazyVStack(spacing: Space.md) {
                    ForEach(model.stars) { star in
                        Button { onOpenStar(star) } label: { StarRow(star: star) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .scrollIndicators(.hidden)
    }

    /// e.g. "11월 3일 화요일"
    private static var todayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: .now)
    }
}

/// Figma `Hero Constellation`: five glowing stars on a dashed line, each twinkling.
private struct HeroConstellation: View {
    private struct HeroStar {
        var image: ImageResource
        var center: CGPoint
        var size: CGFloat
        var keys: [(Double, Double)]
    }

    private let stars: [HeroStar] = [
        HeroStar(image: .heroStar0, center: CGPoint(x: 40, y: 100), size: 66,
                 keys: [(0, 1), (0.06, 0.3), (0.295, 1), (0.53, 0.3), (0.76333, 1)]),
        HeroStar(image: .heroStar1, center: CGPoint(x: 110, y: 55), size: 62,
                 keys: [(0, 1), (0.16, 0.3), (0.355, 1), (0.55, 0.3), (0.745, 1), (0.94, 0.3), (1, 1)]),
        HeroStar(image: .heroStar2, center: CGPoint(x: 185, y: 90), size: 66,
                 keys: [(0, 1), (0.06167, 0.3), (0.21667, 1), (0.37167, 0.3), (0.52667, 1), (0.68167, 0.3), (0.83667, 1)]),
        HeroStar(image: .heroStar3, center: CGPoint(x: 255, y: 40), size: 50,
                 keys: [(0, 1), (0.11167, 0.3), (0.22667, 1), (0.34167, 0.3), (0.45667, 1), (0.57167, 0.3), (0.68833, 1), (0.80333, 0.3), (0.91833, 1)]),
        HeroStar(image: .heroStar4, center: CGPoint(x: 300, y: 110), size: 68,
                 keys: [(0, 1), (0.12, 0.3), (0.345, 1), (0.57, 0.3), (0.79667, 1)]),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(.heroLine)
                .resizable()
                .frame(width: 260.691, height: 70.9824)
                .offset(x: 39.74, y: 39.29)
            ForEach(stars.indices, id: \.self) { i in
                let s = stars[i]
                Image(s.image)
                    .resizable()
                    .frame(width: s.size, height: s.size)
                    .twinkle(Twinkle(duration: 6, keys: s.keys), scale: StarScale.dim)
                    .position(s.center)
            }
        }
        .frame(width: 342, height: 150, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

#Preview {
    let model = AppModel()
    model.fillSampleStars()
    return HomeView(onCompose: {})
        .environment(model)
        .background(Color.bgCanvas)
}

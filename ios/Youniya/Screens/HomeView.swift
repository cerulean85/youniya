import SwiftUI

/// 04 Home: today's prompt, this month's constellation card, and recent stars.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    var onCompose: () -> Void
    var onOpenStar: (StarItem) -> Void = { _ in }
    /// "전체 보기 ›" → the records tab
    var onSeeAll: () -> Void = {}
    /// 04 이번 달 별자리 카드 → the 별자리 tab
    var onConstellation: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                SkyHeader(subtitle: "\(Self.todayText) · 오늘은 어떤 마음이 머물렀나요?")

                Button("오늘의 별 만들기", action: onCompose)
                    .buttonStyle(.primary)

                MonthConstellationCard(onOpen: onConstellation)

                HStack {
                    Text("최근 별")
                        .textStyle(.labelM)
                        .foregroundStyle(Color.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: onSeeAll) {
                        HStack(spacing: 2) {
                            Text("전체 보기").textStyle(.labelS)
                            Image(.iconChevronRight).renderingMode(.template).resizable().frame(width: 16, height: 16)
                        }
                        .foregroundStyle(Color.borderFocus)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }

                // Figma 04: the four most recent; the rest live in the records tab.
                LazyVStack(spacing: Space.md) {
                    ForEach(model.stars.prefix(4)) { star in
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

#Preview {
    let model = AppModel()
    model.fillSampleStars()
    return HomeView(onCompose: {})
        .environment(model)
        .background(Color.bgCanvas)
}

import SwiftUI

/// 08-3 나의 별자리 (별자리 tab, 436:15767): this month's constellation, filled
/// by the stars floated this month in date order. ‹ › (or a swipe) shows the
/// months before, back to the first one; not past this month.
struct ConstellationView: View {
    @Environment(AppModel.self) private var model
    var onOpen: (_ title: String) -> Void
    /// 「자세히 보기」 / 「남은 자리」 → 70/77 for the month shown.
    var onDetail: (_ month: String) -> Void = { _ in }
    /// 「별자리 이야기」 → 83 for the month shown.
    var onStory: (_ month: String) -> Void = { _ in }

    @State private var month = MonthConstellation.monthKey(.now)

    private var thisMonth: String { MonthConstellation.monthKey(.now) }
    private var canGoBack: Bool { month > model.firstConstellationMonth }
    private var canGoForward: Bool { month < thisMonth }

    var body: some View {
        let c = model.constellation(month)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("나의 별자리")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(c.title) · 별 \(c.stars.count)개")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.starBright)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                canvas(c)

                HStack(spacing: Space.md) {
                    stat(c.stars.count, "떠 있는 별")
                    stat(c.deepCount, "깊은 별")
                    stat(max(0, c.total - c.filled), "남은 자리")
                }

                Text(description(c))
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.md) {
                    Button("우주 광장") { onOpen("우주 광장") }
                        .buttonStyle(.secondary)
                    Button("자세히 보기") { onDetail(month) }
                        .buttonStyle(.primary)
                }

                FlowRow(spacing: Space.sm) {
                    LinkChip(title: "별자리 이야기") { onStory(month) }
                    LinkChip(title: "나의 은하수") { onOpen("나의 은하수") }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .scrollIndicators(.hidden)
        .task(id: month) { await model.loadConstellation(month) }
    }

    /// Figma `Canvas`: the month's name, the figure, ‹ ›, and "6 / 9".
    private func canvas(_ c: MonthConstellation) -> some View {
        ZStack {
            ConstellationFigureView(constellation: c)
                .padding(.horizontal, 36)
                .padding(.vertical, 32)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(c.title), \(c.total)자리 중 \(c.filled)자리 채움")
            HStack {
                arrow("chevron.left", enabled: canGoBack, label: "지난달") { go(-1) }
                Spacer()
                arrow("chevron.right", enabled: canGoForward, label: "다음 달") { go(1) }
            }
            .padding(.horizontal, Space.xs)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            Text(c.title).textStyle(.labelS).foregroundStyle(Color.textSecondary).padding(Space.lg)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(c.filled) / \(c.total)").textStyle(.labelS).foregroundStyle(Color.textSecondary).padding(Space.lg)
        }
        .background { NebulaGlowBackground() }
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Color.borderDefault, lineWidth: 1))
        .clipShape(.rect(cornerRadius: Radius.xl))
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width > 60 { go(-1) } else if v.translation.width < -60 { go(1) }
        })
    }

    private func arrow(_ symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func go(_ by: Int) {
        let next = MonthConstellation.shift(month, by: by)
        guard next >= model.firstConstellationMonth, next <= thisMonth else { return }
        withAnimation(.easeInOut(duration: 0.3)) { month = next }
    }

    private func description(_ c: MonthConstellation) -> String {
        if c.isComplete {
            return "\(c.monthLabel) 저녁 하늘에 뜨는 \(c.name)를 모두 채웠어요. 자리보다 많이 띄운 별은 별자리 둘레에 은은하게 떠요."
        }
        if month < thisMonth {
            return "\(c.monthLabel)에는 \(c.total)자리 중 \(c.filled)자리를 채웠어요. 남은 자리는 그달의 여백으로 남아요."
        }
        return "\(c.monthLabel) 저녁 하늘에 뜨는 \(c.name)예요. 별을 띄울 때마다 빈 자리가 하나씩 채워지고, \(c.total)개를 다 채우면 별자리가 완성돼요."
    }

    /// Figma `Stat`: a tappable count card with "›".
    private func stat(_ value: Int, _ label: String) -> some View {
        Button { if label == "남은 자리" { onDetail(month) } else { onOpen(label) } } label: {
            VStack(spacing: Space.xs) {
                Text("\(value)").textStyle(.h2).foregroundStyle(Color.textPrimary)
                HStack(spacing: 2) {
                    Text(label).textStyle(.caption).foregroundStyle(Color.textSecondary)
                    Image(.iconChevronRight).renderingMode(.template).resizable()
                        .frame(width: 14, height: 14).foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Space.md)
            .cosmos("stat-\(label)", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// 04 이번 달 별자리 카드: the month's figure, "6 / 9 자리 채움" with a bar,
/// and 「별자리 보기 ›」 (the 별자리 tab).
struct MonthConstellationCard: View {
    @Environment(AppModel.self) private var model
    var onOpen: () -> Void

    var body: some View {
        let c = model.constellation(MonthConstellation.monthKey(.now))
        Button(action: onOpen) {
            HStack(spacing: Space.lg) {
                ConstellationFigureView(constellation: c, compact: true)
                    .frame(width: 130, height: 114)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("이번 달 별자리").textStyle(.caption).foregroundStyle(Color.textSecondary)
                    Text(c.title).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Text("\(c.filled) / \(c.total) 자리 채움").textStyle(.caption).foregroundStyle(Color.textSecondary)
                        .padding(.top, Space.xs)
                    Capsule().fill(Color.borderDefault).frame(height: 4)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Capsule().fill(Color.brandPrimary)
                                    .frame(width: g.size.width * CGFloat(c.filled) / CGFloat(max(1, c.total)))
                            }
                        }
                    Text("별자리 보기 ›").textStyle(.labelS).foregroundStyle(Color.brandPrimaryText)
                        .padding(.top, Space.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.lg)
            .itemCard(seed: "home-constellation", minHeight: 0)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("이번 달 별자리, \(c.title), \(c.total)자리 중 \(c.filled)자리 채움")
        .accessibilityAddTraits(.isButton)
        .task { await model.loadConstellation(c.month) }
    }
}

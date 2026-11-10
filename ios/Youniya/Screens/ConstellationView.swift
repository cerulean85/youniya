import SwiftUI

/// 08-3 나의 별자리 (별자리 tab, 436:15767): this month's constellation, filled
/// by the stars floated this month in date order. ‹ › (or a swipe) shows the
/// months before, back to the first one; not past this month.
struct ConstellationView: View {
    @Environment(AppModel.self) private var model
    var onOpen: (_ title: String) -> Void
    /// 「별자리 이야기」 → 83 for the month shown.
    var onStory: (_ month: String) -> Void = { _ in }
    /// 08-8 「별 보기 ›」 on a picked star.
    var onOpenStar: (StarItem) -> Void = { _ in }

    @State private var month = MonthConstellation.monthKey(.now)
    /// 08-8: the star picked on the figure (a dotted ring and its card).
    @State private var selected: MonthConstellation.Star?
    /// 08-8: its links within the month, shown for a moment in silver.
    @State private var showLinks = false
    /// 08-9 별자리 카드로 나누기
    @State private var shareCard = DebugScreen.is("8-9")
    @State private var toast: ToastCardMessage?

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

                // 별자리 카드 공유 lives on a complete month's canvas (08-5/08-7).
                Button("별자리 이야기") { onStory(month) }
                    .buttonStyle(.secondary)

                // 567:15050 나의 은하수 미리 보기 → 81
                MilkyWayPreviewCard { onOpen("나의 은하수") }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .scrollIndicators(.hidden)
        .task(id: month) { await model.loadConstellation(month) }
        .onChange(of: month) { selected = nil }
        .onAppear {
            // 08-8 review: the sample star picked, with its links.
            if DebugScreen.is("8-8"), selected == nil {
                let stars = model.constellation(month).stars
                if let s = stars.first(where: { !model.linkedStars($0.id).isEmpty }) ?? stars.first { pick(s) }
            }
        }
        // 08-9 별자리 카드로 나누기
        .cardShareSheet(isPresented: $shareCard, title: "별자리 카드로 나누기", toast: $toast) {
            ConstellationShareCard(constellation: model.constellation(month))
        }
        .toastCard($toast)
    }

    /// 08-8: tap a star to pick it (again to let go). Its links in this month
    /// show in silver for a moment.
    private func pick(_ s: MonthConstellation.Star) {
        withAnimation(.snappy) {
            selected = selected?.id == s.id ? nil : s
            showLinks = selected != nil
        }
        guard let id = selected?.id else { return }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if selected?.id == id { withAnimation(.easeOut(duration: 0.6)) { showLinks = false } }
        }
    }

    /// 08-8 `Star Tooltip`: "내 별 · {제목}", its shape and starlight, 「별 보기 ›」.
    private func pickedCard(_ s: MonthConstellation.Star) -> some View {
        let star = model.stars.first { $0.id == s.id }
        var detail: String {
            guard s.hasStarlight else { return "별빛 없는 별" }
            let shape = (s.shape ?? star?.analysis?.shape).map { "모양: \($0.label) · " } ?? ""
            return shape + "별빛 \(s.starlight ?? 0)"
        }
        return Button {
            if let star { onOpenStar(star) }
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("내 별 · \(s.title)").textStyle(.labelM).foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(detail).textStyle(.caption).foregroundStyle(Color.textTertiary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("별 보기 ›").textStyle(.labelM).foregroundStyle(Color.brandPrimary)
                    .fixedSize()
            }
            .padding(Space.lg)
            .cosmos("picked-star", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.starBright, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(star == nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Figma `Canvas`: the month's name, the figure, ‹ ›, and "6 / 9".
    private func canvas(_ c: MonthConstellation) -> some View {
        ZStack {
            ConstellationFigureView(constellation: c, selected: selected?.id,
                                    silverLinks: showLinks ? selected.map { model.linkedStars($0.id).map(\.id) } ?? [] : [],
                                    onTap: pick)
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
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            if let s = selected {
                pickedCard(s)
                    .padding(Space.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            Text(c.title).textStyle(.labelS).foregroundStyle(Color.textSecondary).padding(Space.lg)
        }
        .overlay(alignment: .topTrailing) {
            // 08-5/08-7 `Complete Card Button`: only a complete month can be shared,
            // and it stays findable after 08-10. Level with the month label.
            if c.isComplete || DebugScreen.is("8-5", "8-7", "8-9") {
                Button { shareCard = true } label: {
                    Text("완성 카드 ›")
                        .textStyle(.labelS)
                        .foregroundStyle(Color.starBright)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.starBright.opacity(0.14), in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.starBright.opacity(0.45), lineWidth: 1))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.top, Space.lg - 6)
                .padding(.trailing, Space.lg)
                .accessibilityLabel("별자리 완성 카드 나누기")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if selected == nil {
                Text("\(c.filled) / \(c.total)").textStyle(.labelS).foregroundStyle(Color.textSecondary).padding(Space.lg)
            }
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
        // 「남은 자리」 led to 70/77, which are gone (2026-11-10): a plain count now.
        let tappable = label != "남은 자리"
        return Button { onOpen(label) } label: {
            VStack(spacing: Space.xs) {
                Text("\(value)").textStyle(.h2).foregroundStyle(Color.textPrimary)
                HStack(spacing: 2) {
                    Text(label).textStyle(.caption).foregroundStyle(Color.textSecondary)
                    if tappable {
                        Image(.iconChevronRight).renderingMode(.template).resizable()
                            .frame(width: 14, height: 14).foregroundStyle(Color.textSecondary)
                    }
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
        .allowsHitTesting(tappable)
        .accessibilityElement(children: .combine)
    }
}

/// 04 이번 달 별자리 한 줄 (Figma 554:14661): "11월 페가수스자리 · 6 / 9 자리 채움"
/// and 「별자리 보기 ›」 (the 별자리 tab), under the recent stars.
struct MonthConstellationLink: View {
    @Environment(AppModel.self) private var model
    var onOpen: () -> Void

    var body: some View {
        let c = model.constellation(MonthConstellation.monthKey(.now))
        Button(action: onOpen) {
            HStack(spacing: Space.sm) {
                Text("\(c.monthLabel) \(c.name) · \(c.filled) / \(c.total) 자리 채움")
                    .textStyle(.caption).foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("별자리 보기 ›").textStyle(.labelS).foregroundStyle(Color.brandPrimaryText)
                    .fixedSize()
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, 14)
            .itemCard(seed: "home-constellation", minHeight: 0)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(c.monthLabel) \(c.name), \(c.total)자리 중 \(c.filled)자리 채움, 별자리 보기")
        .accessibilityAddTraits(.isButton)
        .task { await model.loadConstellation(c.month) }
    }
}

/// 567:15050: a 92pt band of the 81 Galaxy Canvas, "나의 은하수 ›", and
/// "별자리 N개 · 별 M개 · {첫 달}부터". Opens 81.
struct MilkyWayPreviewCard: View {
    @Environment(AppModel.self) private var model
    var onOpen: () -> Void

    var body: some View {
        let timeline = model.stars.map { ($0, $0.date ?? .now) }.sorted { $0.1 < $1.1 }
        let first = model.firstConstellationMonth
        let months = Self.monthCount(from: first, to: MonthConstellation.monthKey(.now))
        let floated = model.stars.filter(\.isFloated).count
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                GalaxyRiver(timeline: timeline.map { (star: $0.0, date: $0.1) })
                    .frame(height: 300)
                    .frame(height: 92, alignment: .center)
                    .offset(y: -18)
                    .frame(height: 92)
                    .clipped()
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack {
                        Text("나의 은하수")
                            .font(.custom("NotoSerifKR-Medium", size: 17))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(.iconChevronRight).renderingMode(.template).resizable()
                            .frame(width: 16, height: 16).foregroundStyle(Color.textTertiary)
                    }
                    Text("별자리 \(months)개 · 별 \(floated)개 · \(Int(first.suffix(2)) ?? 0)월부터")
                        .font(.custom("Pretendard-Regular", size: 13))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(Space.lg)
            }
            .itemCard(seed: "milky-way-preview", minHeight: 0)
            .clipShape(.rect(cornerRadius: Radius.lg))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Months from the first constellation to this one, both included.
    static func monthCount(from a: String, to b: String) -> Int {
        func n(_ m: String) -> Int {
            let p = m.split(separator: "-").compactMap { Int($0) }
            return p.count == 2 ? p[0] * 12 + p[1] : 0
        }
        return max(1, n(b) - n(a) + 1)
    }
}

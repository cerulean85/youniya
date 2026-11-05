import SwiftUI

// MARK: - 26 Report List

/// One week of floated stars that has at least one telescope report.
struct ReportWeek: Identifiable {
    var id: Date { start }
    /// Monday of the week
    var start: Date
    var stars: [StarItem]
    /// The newest star in the week that has a report; opened on tap.
    var latestReport: StarItem

    /// "11월 첫째 주", or "10월 마지막 주" for the last Monday of a month.
    var title: String {
        let cal = Calendar.koreanWeeks
        let month = cal.component(.month, from: start)
        let ordinal = (cal.component(.day, from: start) - 1) / 7
        let isLast = cal.component(.month, from: cal.date(byAdding: .day, value: 7, to: start)!) != month
        let names = ["첫째", "둘째", "셋째", "넷째", "다섯째"]
        return "\(month)월 \(isLast && ordinal > 0 ? "마지막" : names[min(ordinal, 4)]) 주"
    }

    /// "별 6개 · 11월 3일"
    var detail: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return "별 \(stars.count)개 · \(f.string(from: start))"
    }

    /// Groups floated stars by week (Monday start); keeps weeks with a report.
    static func weeks(from stars: [StarItem]) -> [ReportWeek] {
        let cal = Calendar.koreanWeeks
        let floated = stars.filter(\.isFloated)
        let groups = Dictionary(grouping: floated) { star -> Date in
            let d = star.date ?? .now
            return cal.dateInterval(of: .weekOfYear, for: d)?.start ?? cal.startOfDay(for: d)
        }
        return groups.compactMap { start, stars in
            let sorted = stars.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            guard let latest = sorted.first(where: { $0.report != nil }) else { return nil }
            return ReportWeek(start: start, stars: sorted, latestReport: latest)
        }
    }
}

extension Calendar {
    /// Gregorian weeks that start on Monday, in Korea.
    static var koreanWeeks: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ko_KR")
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }
}

extension StarItem {
    /// `createdAt`, or the "M월 d일" in `dateText` (this year) for older saves.
    var date: Date? {
        if let createdAt { return createdAt }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy M월 d일"
        let day = dateText.components(separatedBy: " ·").first ?? dateText
        return f.date(from: "\(Calendar.current.component(.year, from: .now)) \(day)")
    }
}

/// 26 Report List (망원경 리포트): reports grouped by week, with 27 sort.
struct ReportListView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpen: (StarItem) -> Void

    enum Order { case newest, oldest }
    @State private var order: Order = .newest
    @State private var showSort = false
    @State private var sheetHeight: CGFloat = 314

    private var weeks: [ReportWeek] {
        ReportWeek.weeks(from: model.stars).sorted {
            order == .newest ? $0.start > $1.start : $0.start < $1.start
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "망원경 리포트", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    KeptHero()

                    if weeks.isEmpty {
                        Text("아직 리포트가 없어요.\n띄운 별에서 마음 망원경을 켜 보세요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Space.xl)
                    } else {
                        VStack(spacing: Space.md) {
                            ForEach(weeks) { week in
                                Button { onOpen(week.latestReport) } label: {
                                    InfoCard(seed: "week\(week.start.timeIntervalSince1970)",
                                             title: week.title, detail: week.detail)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)

            Button("정렬") { showSort = true }
                .buttonStyle(.ghost)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
                .disabled(weeks.count < 2)
        }
        .background { StarField() }
        // 27 Sort Sheet
        .sheet(isPresented: $showSort) {
            ActionSheetContent(
                title: "정렬",
                message: "목록을 어떻게 볼까요?",
                primary: ("최신순", { setOrder(.newest) }),
                secondary: ("오래된 순", { setOrder(.oldest) }),
                ghost: ("닫기", { showSort = false })
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
            .presentationDetents([.height(sheetHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "sort-sheet") }
        }
    }

    private func setOrder(_ o: Order) {
        withAnimation(.snappy) { order = o }
        showSort = false
    }
}

// MARK: - 28 Coin Charge

/// A coin package. TODO: Load products and prices from StoreKit.
struct CoinPackage: Identifiable, Equatable {
    var coins: Int
    var price: String
    var id: Int { coins }

    static let all: [CoinPackage] = [
        CoinPackage(coins: 50, price: "₩3,300"),
        CoinPackage(coins: 120, price: "₩6,600"),
        CoinPackage(coins: 300, price: "₩14,900"),
    ]
}

/// 28 Coin Charge (코인 충전). Purchases are mocked: the balance just grows.
struct CoinChargeView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onPolicy: () -> Void
    /// → 33 Coin History
    var onHistory: () -> Void = {}

    @State private var selected: CoinPackage = CoinPackage.all[1]
    @State private var charged: Int?

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "코인 충전", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("코인 충전")
                            .textStyle(.h1)
                            .foregroundStyle(Color.textPrimary)
                        Text("필요한 만큼만 충전해요. 기록은 코인 없이도 쓸 수 있어요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    // Not in Figma: balance, and the way to 33 Coin History.
                    Button(action: onHistory) {
                        HStack(spacing: Space.xs) {
                            Text("지금 코인 \(model.coins)개")
                                .contentTransition(.numericText())
                            Text("· 내역 보기")
                                .foregroundStyle(Color.textSecondary)
                            Image(.iconChevronRight)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .textStyle(.labelS)
                        .foregroundStyle(Color.starBright)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    CoinHero()

                    VStack(spacing: Space.md) {
                        ForEach(CoinPackage.all) { pkg in
                            let on = pkg == selected
                            Button { withAnimation(.snappy) { selected = pkg } } label: {
                                InfoCard(seed: "coin\(pkg.coins)", title: "코인 \(pkg.coins)", detail: pkg.price)
                                    .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                                        .strokeBorder(Color.brandPrimary, lineWidth: on ? 2 : 0))
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Space.lg) {
                Button(action: onPolicy) {
                    Text("결제·환불 정책 보기")
                        .textStyle(.caption)
                        .underline()
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Button(charged.map { "코인 \($0)개를 충전했어요" } ?? "충전하기") { charge() }
                    .buttonStyle(.primary)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }

    private func charge() {
        // TODO: StoreKit purchase; on success the server credits the coins.
        withAnimation(.snappy) {
            model.addCoins(selected.coins)
            charged = selected.coins
        }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { charged = nil }
        }
    }
}

/// 28 `Hero` (342×120): a scatter of gold coins, each with a soft halo.
struct CoinHero: View {
    // (center, core diameter, halo diameter)
    private let coins: [(CGPoint, CGFloat, CGFloat)] = [
        (CGPoint(x: 120.5, y: 60.5), 17, 30),
        (CGPoint(x: 171, y: 48), 24, 44),
        (CGPoint(x: 225, y: 66), 14, 26),
        (CGPoint(x: 150, y: 96), 10, 18),
        (CGPoint(x: 205, y: 100), 8, 14),
        (CGPoint(x: 90, y: 92), 6, 10),
        (CGPoint(x: 260, y: 36), 6, 10),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(coins.indices, id: \.self) { i in
                let (c, core, halo) = coins[i]
                ZStack {
                    Circle().fill(Color.starBright.opacity(0.16)).frame(width: halo, height: halo)
                    Circle().fill(Color.starBright).frame(width: core, height: core)
                }
                .position(c)
            }
        }
        .frame(width: 342, height: 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

#Preview("26") {
    let model = AppModel()
    model.fillSampleStars()
    return ReportListView(onBack: {}, onOpen: { _ in }).environment(model)
}

#Preview("28") {
    CoinChargeView(onBack: {}, onPolicy: {}).environment(AppModel())
}

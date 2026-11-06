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
    /// 98 "마음 망원경 켜기": to the latest floated star without a report.
    var onTurnOn: () -> Void = {}

    enum Order { case newest, oldest }
    @State private var order: Order = .newest
    @State private var showSort = false
    /// 111 skeleton while the reports load.
    @State private var loaded = false
    private var isLoading: Bool { model.simulateLoading && !loaded }
    @State private var sheetHeight: CGFloat = 314

    private var weeks: [ReportWeek] {
        ReportWeek.weeks(from: model.stars).sorted {
            order == .newest ? $0.start > $1.start : $0.start < $1.start
        }
    }

    /// 26 list, or 98 when there's nothing yet.
    @ViewBuilder private var reportList: some View {
        if weeks.isEmpty {
            // 98
            EmptyStateView(title: "아직 받은 리포트가 없어요",
                           message: "마음 망원경을 켜면 일주일 동안의 별을\n모아 리포트로 보여 드려요.")
                .padding(.top, Space.sm)
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

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "망원경 리포트", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    KeptHero()

                    if isLoading { ReportListSkeleton() } else { reportList }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)

            if isLoading {
                // Figma 111: a disabled ghost button until the list arrives.
                Button("정렬") {}
                    .buttonStyle(.ghost)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.xl)
                    .disabled(true)
            } else if weeks.isEmpty {
                // Figma 98: always on; with nothing floated yet it starts a new star.
                Button("마음 망원경 켜기", action: onTurnOn)
                    .buttonStyle(.primary)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.xl)
            } else {
                Button("정렬") { showSort = true }
                    .buttonStyle(.ghost)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.xl)
                    .disabled(weeks.count < 2)
            }
        }
        .background { StarField() }
        .simulatedLoad($loaded)
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
    /// 38 결제 미완료
    @State private var paymentFailed = false

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
                Button("충전하기") { charge() }
                    .buttonStyle(.primary)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .overlay {
            if let charged {
                StatusView(icon: .iconCheck, title: "충전이 끝났어요",
                           message: "코인 \(charged)개가 들어왔어요. 지금 코인은 \(model.coins)개예요.",
                           actions: [
                               .init(title: "하던 곳으로 돌아가기", style: .primary, run: onBack),
                               .init(title: "코인 사용 내역 보기", style: .ghost, run: onHistory),
                           ])
                    .transition(.opacity)
            }
        }
        .overlay {
            if paymentFailed {
                StatusView(icon: .iconLock, title: "결제가 끝나지 않았어요",
                           message: "코인은 차감되거나 지급되지 않았어요.",
                           actions: [
                               .init(title: "다시 결제하기", style: .primary) { charge() },
                               .init(title: "닫기", style: .ghost) {
                                   withAnimation(.easeInOut(duration: 0.3)) { paymentFailed = false }
                               },
                           ])
                    .transition(.opacity)
            }
        }
    }

    private func charge() {
        // TODO: StoreKit purchase; on success the server credits the coins.
        // Cancelled or pending purchases show 38 and change nothing.
        if model.simulatedFailure == .payment {
            withAnimation(.easeInOut(duration: 0.3)) { paymentFailed = true }
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) { paymentFailed = false }
        // 102 충전이 끝났어요
        withAnimation(.easeInOut(duration: 0.3)) {
            model.addCoins(selected.coins)
            charged = selected.coins
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
        .fitCanvas(width: 342, height: 120)
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

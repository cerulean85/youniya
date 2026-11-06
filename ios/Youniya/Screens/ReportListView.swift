import SwiftUI

// MARK: - 26 Report List

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

/// 26 Report List (망원경 리포트): one row per report, with 27 sort.
struct ReportListView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpen: (StarItem) -> Void
    /// 98 "최근 별 보러 가기": to the latest floated star (or 05 when there is none).
    var onTurnOn: () -> Void = {}

    enum Order { case newest, oldest }
    @State private var order: Order = .newest
    @State private var showSort = DebugScreen.is("27")
    /// 111 skeleton while the reports load.
    @State private var loaded = false
    private var isLoading: Bool { model.simulateLoading && !loaded }
    @State private var sheetHeight: CGFloat = 314

    /// 26: one row per report (one star each), by the star's date.
    private var reported: [StarItem] {
        model.stars.filter { $0.report != nil }.sorted {
            let (a, b) = ($0.date ?? .distantPast, $1.date ?? .distantPast)
            return order == .newest ? a > b : a < b
        }
    }

    /// 26 list, or 98 when there's nothing yet.
    @ViewBuilder private var reportList: some View {
        if reported.isEmpty {
            // 98
            EmptyStateView(title: "아직 받은 리포트가 없어요",
                           message: "오늘의 별 카드에서 마음 망원경을 켜면\n그 별의 리포트가 여기에 모여요.")
                .padding(.top, Space.sm)
        } else {
            VStack(spacing: Space.md) {
                ForEach(reported) { star in
                    Button { onOpen(star) } label: {
                        // Figma 26: the report's star name, then "원래 별 제목 · 날짜".
                        InfoCard(seed: "report\(star.id)", title: star.report?.starName ?? star.title,
                                 detail: "\(star.title) · \(star.shortDateText)")
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
            } else if reported.isEmpty {
                // Figma 98: always on; with nothing floated yet it starts a new star.
                Button("최근 별 보러 가기", action: onTurnOn)
                    .buttonStyle(.primary)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.xl)
            } else {
                Button("정렬") { showSort = true }
                    .buttonStyle(.ghost)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.xl)
                    .disabled(reported.count < 2)
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
    @State private var charged: Int? = DebugScreen.is("102") ? 120 : nil
    /// 38 결제 미완료
    @State private var paymentFailed = DebugScreen.is("38")
    /// 28 "(필수) 결제·환불 정책에 동의해요". Asked again for each charge; the server
    /// keeps it with the purchase (`consumption_consent`) for App Store refund requests.
    /// iPhone SE and other short screens.
    @State private var isShortScreen = false
    @State private var agreed: Bool = {
        #if DEBUG
        UserDefaults.standard.string(forKey: "debugRoute") == "coinsAgreed" || DebugScreen.is("28-1", "102")  // 28-1 for visual review
        #else
        false
        #endif
    }()

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

                    // Short screens (iPhone SE) drop the picture so all three packages
                    // fit above the consent and the button.
                    if !isShortScreen { CoinHero() }

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
            // Anything left below the fold fades out, so the list reads as scrollable.
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: Space.lg)
                }
            }

            // Figma 28 / 28-1: refund note, the required consent, then the button.
            VStack(spacing: Space.lg) {
                Text("충전한 코인만큼 남아 있을 때만 환불할 수 있어요.\n환불을 요청하면 코인 사용 내역이 앱 스토어에 전달돼요.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                CheckboxRow(label: "(필수) 결제·환불 정책에 동의해요", isChecked: agreed,
                            onToggle: { withAnimation(.snappy(duration: 0.2)) { agreed.toggle() } },
                            onOpen: onPolicy)
                Button("충전하기") { charge() }
                    .buttonStyle(.primary)
                    .disabled(!agreed)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .onGeometryChange(for: Bool.self) { $0.size.height < 700 } action: { isShortScreen = $0 }
        .background { StarField() }
        .task { await model.loadCoins() }
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
        guard agreed else { return }
        if model.useLiveAPI {
            chargeLive()
            return
        }
        // Mock: the balance just grows.
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

extension CoinChargeView {
    /// Live 28: the server credits the purchase (with consumption_consent).
    /// 102 when it does; 38 when it can't confirm the payment.
    fileprivate func chargeLive() {
        Task { @MainActor in
            do {
                guard let added = try await model.purchaseCoinsLive(selected.coins) else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    paymentFailed = false
                    charged = added
                }
            } catch let e as APIError where ["purchase_unverified", "purchase_invalid", "offline", "product_unavailable"].contains(e.code) {
                withAnimation(.easeInOut(duration: 0.3)) { paymentFailed = true }
            } catch {
                model.handle(error)
            }
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

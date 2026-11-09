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

// MARK: - 28 Coin Charge

/// A coin package (product `coin_<coins>`; 1 coin = ₩10). TODO: Prices from StoreKit.
struct CoinPackage: Identifiable, Equatable {
    var coins: Int
    var price: String
    /// coin_1100: 1,000 + 100 bonus.
    var bonus = 0
    var id: Int { coins }

    /// "₩9,900 · 보너스 100 포함"
    var priceText: String { bonus > 0 ? "\(price) · 보너스 \(bonus) 포함" : price }

    static let all: [CoinPackage] = [
        CoinPackage(coins: 110, price: "₩1,100"),
        CoinPackage(coins: 330, price: "₩3,300"),
        CoinPackage(coins: 1100, price: "₩9,900", bonus: 100),
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
    /// M1 from the 28-2 card.
    @State private var showMembership = DebugScreen.is("M1")
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
                    if model.membershipOn {
                        // 28-2: the membership card instead of the coin picture.
                        MembershipCard { showMembership = true }
                        Text("또는 필요한 만큼 코인 충전").textStyle(.labelS).foregroundStyle(Color.textSecondary)
                    } else if !isShortScreen {
                        CoinHero()
                    }

                    VStack(spacing: Space.md) {
                        ForEach(CoinPackage.all) { pkg in
                            let on = pkg == selected
                            Button { withAnimation(.snappy) { selected = pkg } } label: {
                                InfoCard(seed: "coin\(pkg.coins)", title: "코인 \(pkg.coins.formatted())", detail: pkg.priceText)
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
        .membershipSheet(isPresented: $showMembership, onPolicy: { _ in onPolicy() })
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


#Preview("28") {
    CoinChargeView(onBack: {}, onPolicy: {}).environment(AppModel())
}

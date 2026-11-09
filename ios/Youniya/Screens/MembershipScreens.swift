import StoreKit
import SwiftUI

// v1.1 별지기 멤버십: built ahead, switched off in the release build.
// `AppModel.membershipOn` stays false until the server's GET /v1/membership
// answers (404 = off); `-debugScreen M1 / 28-2 / 68-1 / 87-4 / 123` turn it on
// for the visual review.

// MARK: - Model

/// The membership plans (StoreKit 2 auto-renewing subscriptions).
enum MembershipPlan: String, CaseIterable, Identifiable {
    case yearly = "membership_yearly"
    case monthly = "membership_monthly"
    var id: String { rawValue }
    var label: String { self == .yearly ? "연간" : "월간" }
    var price: String { self == .yearly ? "29,000원" : "2,900원" }
    var detail: String { self == .yearly ? "두 달 무료 · 월 2,417원" : "매달 자동 갱신" }
}

extension AppModel {
    /// The release switch for v1.1. The server can also turn it on (TODO: GET /v1/membership).
    static let membershipEnabled = false

    var membershipOn: Bool { Self.membershipEnabled || membershipAvailable }
    var isMember: Bool { membershipOn && memberActive }

    /// "이용 중 · 12월 7일 갱신"
    var memberStatusText: String {
        guard let date = memberRenewal else { return "이용 중" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return "이용 중 · \(f.string(from: date)) 갱신"
    }

    /// M1 "7일 무료로 시작하기". Mock: the trial starts on device. TODO: Send the
    /// transaction to the server once the API session sends the format.
    @MainActor func startMembership(_ plan: MembershipPlan) async -> Bool {
        guard useLiveAPI else {
            memberActive = true
            memberRenewal = Calendar.current.date(byAdding: .day, value: 7, to: .now)
            return true
        }
        do {
            guard let product = try await Product.products(for: [plan.rawValue]).first else {
                apiMessage = "멤버십 상품을 찾지 못했어요. 잠시 뒤 다시 시도해 주세요."
                return false
            }
            var options: Set<Product.PurchaseOption> = []
            if let id = accountID.flatMap(UUID.init(uuidString:)) { options.insert(.appAccountToken(id)) }
            switch try await product.purchase(options: options) {
            case .success(let result):
                guard case .verified(let transaction) = result else { return false }
                // The server checks the signed transaction and keeps the membership.
                guard await verifyMembership(result.jwsRepresentation) else { return false }
                await transaction.finish()
                return true
            default:
                return false
            }
        } catch {
            apiMessage = "결제를 마치지 못했어요. 다시 시도해 주세요."
            return false
        }
    }

    /// 87-4 / M1 "구매 복원": AppStore.sync, then the current entitlement.
    @MainActor func restoreMembership() async {
        try? await AppStore.sync()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  MembershipPlan(rawValue: t.productID) != nil, t.revocationDate == nil else { continue }
            if useLiveAPI {
                guard await verifyMembership(result.jwsRepresentation) else { return }
            } else {
                memberActive = true
                memberRenewal = t.expirationDate
            }
            apiMessage = "멤버십을 복원했어요."
            return
        }
        apiMessage = "복원할 멤버십이 없어요."
    }
}

// MARK: - M1 Membership sheet

/// M1 별지기 멤버십 안내 (over 28): benefits, two plans, the 3.1.2 notes and links.
struct MembershipSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skyTheme) private var theme
    var onClose: () -> Void
    var onPolicy: (PolicyDoc) -> Void = { _ in }

    @State private var plan: MembershipPlan = .yearly
    @State private var working = false

    private static let benefits: [(ImageResource, String)] = [
        (.iconStar, "별빛 받기 하루 10번"),
        (.iconTelescope, "마음 망원경 하루 10번 · 띄운 별마다"),
        (.iconSun, "우주의 색 장면 3가지 · 앱 아이콘"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("별지기 멤버십").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("마음을 더 자주, 더 깊이 들여다보고 싶다면.").textStyle(.bodyM).foregroundStyle(Color.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Space.md) {
                ForEach(Self.benefits, id: \.1) { icon, text in
                    HStack(spacing: Space.md) {
                        Image(icon).resizable().frame(width: 20, height: 20)
                            .frame(width: 32, height: 32)
                            .background(theme.accent.tint.opacity(0.16), in: .circle)
                            .accessibilityHidden(true)
                        Text(text).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    }
                }
            }

            HStack(spacing: Space.md) {
                ForEach(MembershipPlan.allCases) { p in planCard(p) }
            }

            VStack(spacing: Space.md) {
                Button("7일 무료로 시작하기") {
                    working = true
                    Task { @MainActor in
                        let ok = await model.startMembership(plan)
                        working = false
                        if ok { onClose() }
                    }
                }
                .buttonStyle(.primary)
                .disabled(working)
                Button("나중에", action: onClose).buttonStyle(.ghost)
            }

            // App Review 3.1.2: price, renewal, how to cancel, and the links.
            VStack(alignment: .leading, spacing: Space.md) {
                Text("7일 무료 체험이 끝나면 선택한 요금으로 자동 결제돼요. 끝나기 24시간 전까지 언제든 해지할 수 있어요. 기록 쓰기와 별빛 없이 띄우기는 멤버십 없이도 계속 무료예요.")
                    .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.xs) {
                    link("이용약관") { onPolicy(.terms) }
                    Text("·").foregroundStyle(Color.textTertiary)
                    link("개인정보 처리방침") { onPolicy(.privacy) }
                    Text("·").foregroundStyle(Color.textTertiary)
                    link("구매 복원") { Task { await model.restoreMembership() } }
                }
                .textStyle(.caption)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
    }

    private func planCard(_ p: MembershipPlan) -> some View {
        let on = p == plan
        return Button { withAnimation(.snappy(duration: 0.2)) { plan = p } } label: {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(p.label).textStyle(.caption).foregroundStyle(Color.textSecondary)
                Text(p.price)
                    .font(.custom("Pretendard-Medium", size: 20, relativeTo: .title3))
                    .foregroundStyle(Color.textPrimary)
                Text(p.detail).textStyle(.caption).foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.lg)
            .background(on ? theme.accent.tint.opacity(0.14) : Color.bgSurface.opacity(0.7), in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(on ? theme.accent.strong : Color.borderDefault, lineWidth: on ? 1.5 : 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).underline().foregroundStyle(Color.hex(0xA78BFA)) }
            .buttonStyle(.plain)
    }
}

extension View {
    /// M1 as a bottom sheet sized to its content.
    func membershipSheet(isPresented: Binding<Bool>, onPolicy: @escaping (PolicyDoc) -> Void = { _ in }) -> some View {
        modifier(MembershipSheetModifier(isPresented: isPresented, onPolicy: onPolicy))
    }
}

private struct MembershipSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onPolicy: (PolicyDoc) -> Void
    @State private var height: CGFloat = 680

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            MembershipSheet(onClose: { isPresented = false },
                            onPolicy: { doc in isPresented = false; onPolicy(doc) })
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                .presentationDetents([.height(height)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.xl)
                .presentationBackground { SheetBackground(seed: "membership-sheet") }
        }
    }
}

// MARK: - 28-2 Membership card

/// 28-2: the gradient card above the coin packages (→ M1), or the member's status.
struct MembershipCard: View {
    @Environment(AppModel.self) private var model
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("별지기 멤버십").textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    if model.isMember {
                        Text(model.memberStatusText).textStyle(.bodyS).foregroundStyle(Color.textPrimary)
                    } else {
                        Text("별 띄우기·마음 망원경 하루 10번").textStyle(.bodyS).foregroundStyle(Color.textPrimary)
                        Text("월 2,900원부터 · 7일 무료 체험").textStyle(.caption).foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(.iconChevronRight).renderingMode(.template).resizable()
                    .frame(width: 20, height: 20).foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(
                LinearGradient(colors: [Color.hex(0x8B5CF6).opacity(0.35), Color.hex(0xEC4899).opacity(0.18)],
                               startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Color.hex(0xA78BFA), lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - 87-4 Settings · membership

/// 87-4: the "멤버십" section at the top of Settings.
struct MembershipSettingsSection: View {
    @Environment(AppModel.self) private var model
    var onLearnMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("멤버십").textStyle(.labelS).foregroundStyle(Color.textTertiary)
                .accessibilityAddTraits(.isHeader)
            SettingsRow(icon: .iconStar, title: "별지기 멤버십",
                        value: model.isMember ? model.memberStatusText : "알아보기") { onLearnMore() }
            SettingsRow(icon: .iconSettings, title: "멤버십 관리", value: "App Store") {
                Task { @MainActor in
                    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                    try? await AppStore.showManageSubscriptions(in: scene)
                }
            }
            SettingsRow(icon: .iconExport, title: "구매 복원") { Task { await model.restoreMembership() } }
        }
        .padding(.top, Space.md)
    }
}


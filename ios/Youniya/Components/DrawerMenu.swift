import SwiftUI

/// Side drawer with the items from Figma `Menu Popup` (67 Home · Menu Open).
/// Slides in from the right edge.
struct DrawerMenu: View {
    @Environment(AppModel.self) private var model
    var onSelect: (_ title: String) -> Void
    var onDev: (_ action: DevAction) -> Void

    enum DevAction { case fillSamples, longDraft, clearStars, signOut, cycleFailure, toggleLoading, toggleLiveAPI, notice(AppNotice) }

    private struct Item: Identifiable {
        var title: String
        var subtitle: String
        var icon: ImageResource
        var id: String { title }
    }

    private let items: [Item] = [
        Item(title: "별빛 기록", subtitle: "지나온 별들", icon: .iconStar),
        Item(title: "간직한 별", subtitle: "조용히 품은 마음", icon: .iconArchive),
        Item(title: "마음 망원경", subtitle: "리포트 모아보기", icon: .iconNebula),
        // 79·80: not in the 67 drawer; this is where the collection opens.
        Item(title: "컬렉션", subtitle: "모인 별과 성운", icon: .iconGrid),
        Item(title: "코인", subtitle: "충전 · 사용 내역", icon: .iconMoon),
        Item(title: "설정", subtitle: "알림 · 데이터 · 약관", icon: .iconPencil),
        // Not in the 67 drawer; 30 Menu lists it. Reaches 32 Inquiry.
        Item(title: "문의하기", subtitle: "궁금한 점 보내기", icon: .iconInfo),
    ]

    var body: some View {
        // Scrolls when the list is taller than the screen (iPhone SE), so the
        // drawer never grows the layout and pushes the tab bar down.
        GeometryReader { geo in
            ScrollView {
                list.frame(minHeight: geo.size.height, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Radius.xl, bottomLeadingRadius: Radius.xl)
                .fill(Color.bgSurfaceRaised)
                .overlay {
                    CosmosBackground(seed: "menu")
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.xl, bottomLeadingRadius: Radius.xl))
                }
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: Radius.xl, bottomLeadingRadius: Radius.xl)
                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                )
                // Elevation/Card
                .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                .ignoresSafeArea()
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 2) {
            header

            ForEach(items) { item in
                Button { onSelect(item.title) } label: { row(item) }
                    .buttonStyle(.plain)
            }

            Spacer()

            #if DEBUG
            // Temporary dev tools until real settings exist.
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("개발용")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                devButton("샘플 별 채우기") { onDev(.fillSamples) }
                devButton("긴 예시 글 쓰기") { onDev(.longDraft) }
                devButton("별 모두 비우기") { onDev(.clearStars) }
                devButton("로그아웃") { onDev(.signOut) }
                devButton("실패 흉내: \(model.simulatedFailure?.rawValue ?? "없음")") { onDev(.cycleFailure) }
                devButton("로딩 흉내: \(model.simulateLoading ? "켬" : "끔")") { onDev(.toggleLoading) }
                devButton("서버: \(model.useLiveAPI ? "실제 API" : "목업")") { onDev(.toggleLiveAPI) }
                HStack(spacing: Space.lg) {
                    devButton("39") { onDev(.notice(.loginExpired)) }
                    devButton("40") { onDev(.notice(.updateRequired)) }
                    devButton("41") { onDev(.notice(.maintenance("11월 4일 02:00~04:00"))) }
                    devButton("120") { onDev(.notice(.rateLimited)) }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.lg)
            #endif
        }
        .padding(.horizontal, Space.sm)
        .padding(.top, Space.lg)
    }

    /// Figma 67-1: logo mark, wordmark and slogan above the items, then a divider.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Figma 67-1 uses the splash mark scaled to 40pt.
                LogoMark(size: .large)
                    .scaleEffect(40 / 112)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    // The splash wordmark (Display, 8% tracking) at 20pt.
                    Text("YOUNIYA")
                        .font(.custom("NotoSerifKR-SemiBold", size: 20, relativeTo: .title3))
                        .tracking(1.6)
                        .foregroundStyle(Color.textPrimary)
                    Text("텍스트로 시각화한 우리 모두의 우주")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("YOUNIYA, 텍스트로 시각화한 우리 모두의 우주")

            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
                .padding(.horizontal, 12)
                .padding(.top, Space.xl - 4)
                .padding(.bottom, Space.md - 2)
                .accessibilityHidden(true)
        }
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 12) {
            Image(item.icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 36, height: 36)
                .background(Color.tintPrimary, in: .rect(cornerRadius: Radius.md))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .textStyle(.labelM)
                    .foregroundStyle(Color.textPrimary)
                Text(item.subtitle)
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func devButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .textStyle(.labelS)
            .foregroundStyle(Color.textSecondary)
            .buttonStyle(.plain)
    }
}

#Preview {
    DrawerMenu(onSelect: { _ in }, onDev: { _ in })
        .frame(width: 320)
        .background(Color.bgCanvas)
}

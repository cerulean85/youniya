import SwiftUI

/// Side drawer with the items from Figma `Menu Popup` (67 Home · Menu Open).
/// Slides in from the right edge.
struct DrawerMenu: View {
    var onSelect: (_ title: String) -> Void
    var onDev: (_ action: DevAction) -> Void

    enum DevAction { case fillSamples, clearStars, signOut }

    private struct Item: Identifiable {
        var title: String
        var subtitle: String
        var icon: ImageResource
        var id: String { title }
    }

    private let items: [Item] = [
        Item(title: "별빛 기록", subtitle: "지나온 별들", icon: .iconStar),
        Item(title: "보관함", subtitle: "조용히 품은 마음", icon: .iconArchive),
        Item(title: "마음 망원경", subtitle: "리포트 모아보기", icon: .iconNebula),
        Item(title: "코인", subtitle: "충전 · 사용 내역", icon: .iconMoon),
        Item(title: "설정", subtitle: "알림 · 데이터 · 약관", icon: .iconPencil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                Button { onSelect(item.title) } label: { row(item) }
                    .buttonStyle(.plain)
            }

            Spacer()

            // Temporary dev tools until real settings exist.
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("개발용")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                devButton("샘플 별 채우기") { onDev(.fillSamples) }
                devButton("별 모두 비우기") { onDev(.clearStars) }
                devButton("로그아웃") { onDev(.signOut) }
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.sm)
        .padding(.top, 60)
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

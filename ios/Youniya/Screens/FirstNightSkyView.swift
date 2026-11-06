import SwiftUI

/// 03 First Night Sky: empty state before the first star.
struct FirstNightSkyView: View {
    var onCompose: () -> Void

    var body: some View {
        VStack(spacing: Space.xl) {
            SkyHeader(subtitle: "첫 별을 기다리고 있어요")

            VStack(spacing: Space.xl) {
                emptySlot

                VStack(spacing: Space.sm) {
                    Text("아직 떠 있는 별이 없어요")
                        .textStyle(.h3)
                        .foregroundStyle(Color.textPrimary)
                    Text("마음에 머무는 이야기를 적으면\n첫 별이 조용히 떠올라요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textSecondary)
                }
                .multilineTextAlignment(.center)

                Button("첫 별 만들기", action: onCompose)
                    .buttonStyle(.primary)

                Text("별 띄우기는 언제나 무료예요")
                    .textStyle(.caption)
                    .foregroundStyle(Color.starBright)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl)
    }

    private var emptySlot: some View {
        Circle()
            .strokeBorder(Color.brandPrimary, style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            .cosmos("empty-slot", in: Circle())
            .frame(width: 160, height: 160)
            .overlay {
                // 8:64: 2s, scale 1↔0.7, opacity 1↔0.3
                Image(.emptySlotStar)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .twinkle(
                        Twinkle(duration: 2, keys: [(0, 1), (0.255, 0.3), (0.63, 1), (1, 0.3)]),
                        scale: StarScale.dim
                    )
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    FirstNightSkyView(onCompose: {})
        .background(Color.bgCanvas)
}

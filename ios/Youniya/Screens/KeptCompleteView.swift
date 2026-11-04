import SwiftUI

/// 13 Kept Complete: after "조용히 품기" (kept without analysis).
struct KeptCompleteView: View {
    var onHome: () -> Void
    var onOpenStar: () -> Void

    var body: some View {
        VStack(spacing: Space.xl) {
            Circle()
                .strokeBorder(Color.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 112, height: 112)
                .overlay {
                    Image(.iconArchive)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.textPrimary)
                }
                .accessibilityHidden(true)

            VStack(spacing: Space.sm) {
                Text("조용히 품었어요")
                    .textStyle(.h2)
                    .foregroundStyle(Color.textPrimary)
                Text("분석 없이 마음을 있는 그대로 간직했어요.\n언제든 다시 꺼내볼 수 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)

            VStack(spacing: Space.md) {
                Button("홈으로", action: onHome)
                    .buttonStyle(.primary)
                Button("이 별 보기", action: onOpenStar)
                    .buttonStyle(.ghost)
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StarField() }
    }
}

#Preview {
    KeptCompleteView(onHome: {}, onOpenStar: {})
}

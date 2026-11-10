import SwiftUI

// MARK: - 23 Starlight Line

/// 23 Starlight Line (별빛 한 줄): the one line a star in someone's nebula
/// left behind, opened from a card on 22. It can be saved.
struct StarlightLineView: View {
    @Environment(AppModel.self) private var model
    var line: String
    var onClose: () -> Void

    var body: some View {
        let saved = model.savedLines.contains(line)
        VStack(spacing: 0) {
            TopAppBar(title: "오늘의 한 줄", onBack: onClose)

            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("오늘의 한 줄")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                    Text("별이 남긴 짧은 말이에요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                RecordsHero()

                NoticeBanner(message: line)

                Spacer(minLength: Space.xl)

                VStack(spacing: Space.md) {
                    Button(saved ? "저장했어요" : "저장하기") {
                        withAnimation(.snappy) { model.saveLine(line) }
                    }
                    .buttonStyle(.primary)
                    .disabled(saved)
                    Button("닫기", action: onClose)
                        .buttonStyle(.ghost)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }
}


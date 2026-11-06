import SwiftUI

/// 14 Rewrite: write again on a previous star's question.
struct RewriteView: View {
    var previous: StarItem
    var question: String
    var onBack: () -> Void
    var onPublish: (_ body: String, _ floated: Bool) -> Void

    @State private var text = DebugScreen.is("105") ? "조금 더 써 보고 싶은 마음." : ""
    @FocusState private var focused: Bool

    private var canPublish: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "다시 쓰기", onBack: onBack)

            VStack(spacing: Space.lg) {
                // Previous question
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("지난번 기록 · \(previous.title)")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                    Text(question)
                        .textStyle(.observation)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.lg)
                .focusCard(angle: .init(x: 0.38, y: 0), end: .init(x: 0.62, y: 1))
                .accessibilityElement(children: .combine)

                // Editor
                TextEditor(text: $text)
                    .textInputStyle(.journalBody)
                    .foregroundStyle(Color.textSecondary)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(.horizontal, -5)
                    .padding(.top, -8)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("이번에는 어떤 마음이 떠오르나요?")
                                .textInputStyle(.journalBody)
                                .foregroundStyle(Color.textTertiary)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(Space.lg)
                    // Figma 14/105: a 260pt editor; the buttons stay at the bottom.
                    .frame(height: 260, alignment: .top)
                    .focusCard(angle: .init(x: 0.25, y: 0), end: .init(x: 0.75, y: 1))

                Text("\(text.count.formatted()) / \(AppModel.minFloatLength.formatted())자")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                // 105: floating needs 1,000 characters.
                if canPublish && text.count < AppModel.minFloatLength {
                    NoticeBanner(message: "\(AppModel.minFloatLength.formatted())자부터 별로 띄울 수 있어요")
                }

                Spacer(minLength: 0)

                HStack(spacing: Space.md) {
                    Button("조용히 간직하기") { publish(floated: false) }
                        .buttonStyle(.secondary)
                        .disabled(!canPublish)
                    Button("별 띄우기") { publish(floated: true) }
                        .buttonStyle(.primary)
                        .disabled(text.count < AppModel.minFloatLength)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .onAppear { focused = true }
    }

    private func publish(floated: Bool) {
        focused = false
        onPublish(text, floated)
    }
}

private extension View {
    /// Raised card with the focus border used on 14 (gradient surface → raised).
    /// Now the shared Figma item card (Cosmos BG + violet→slate border).
    func focusCard(angle start: UnitPoint, end: UnitPoint) -> some View {
        itemCard(seed: "focus-\(start.x)-\(end.y)", minHeight: 0)
    }
}

/// 16 Rematch Compare: starlight before and after rewriting.
struct RematchCompareView: View {
    var previous: StarItem
    var current: StarItem
    var onBack: () -> Void
    var onShowNebula: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "다시 마주한 마음", onBack: onBack)

            VStack(alignment: .leading, spacing: Space.lg) {
                Text("같은 마음, 다른 빛")
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: Space.md) {
                    metric("지난번", previous.analysis?.starlight, color: .textSecondary)
                    metric("이번", current.analysis?.starlight, color: .starBright)
                }

                NoticeBanner(message: note, tone: .warm)

                Spacer(minLength: 0)

                Button("나의 성운 보기", action: onShowNebula)
                    .buttonStyle(.primary)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }

    private var note: String {
        let before = previous.analysis?.starlight, after = current.analysis?.starlight
        if let before, let after, after < before {
            return "별빛이 낮아진 것은 좋고 나쁨이 아니에요. 이번에는 다른 결의 마음을 마주했다는 뜻이에요."
        }
        return "별빛이 밝아진 것은 좋고 나쁨이 아니에요. 다시 쓰며 마음이 조금 더 또렷해졌다는 뜻이에요."
    }

    private func metric(_ label: String, _ value: Int?, color: Color) -> some View {
        VStack(spacing: Space.sm) {
            Text(label)
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
            Text(value.map(String.init) ?? "—")
                .textStyle(.metric)
                .foregroundStyle(color)
            Text("별빛")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.lg)
        .cosmos("compare-\(color)", in: RoundedRectangle(cornerRadius: Radius.lg))
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// 15 Delete Confirm: bottom sheet. Keeping is the primary choice.
struct DeleteStarSheet: View {
    var exportText: String
    var onKeep: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule()
                .fill(Color.borderDefault)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("이 별을 어떻게 할까요?")
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                Text("영구 삭제하면 쓴 글과 분석이 모두 사라지고 되돌릴 수 없어요. 먼저 내보내 둘 수 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Space.md) {
                Button("그대로 두기", action: onKeep)
                    .buttonStyle(.primary)
                ShareLink(item: exportText) { Text("내보내기") }
                    .buttonStyle(.secondary)
                Button("영구 삭제", action: onDelete)
                    .buttonStyle(.danger)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }
}

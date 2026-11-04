import SwiftUI

/// 05 Star Making: write today's story, then keep it quietly or float it as a star.
struct StarMakingView: View {
    @Environment(AppModel.self) private var model
    /// Called after the draft is saved; the parent closes the flow.
    var onClose: () -> Void
    /// Called with the draft when the user keeps or floats it.
    var onPublish: (_ draft: StarDraft, _ floated: Bool) -> Void

    @State private var draft = StarDraft()
    @State private var isSaved = false
    @State private var didPublish = false
    @FocusState private var focus: Field?

    private enum Field { case title, body }

    private var canPublish: Bool {
        !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            topBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(Mood.allCases) { mood in
                        MoodChip(mood: mood, isSelected: draft.mood == mood) {
                            draft.mood = mood
                        }
                    }
                }
            }
            .scrollClipDisabled()

            TextField(
                "",
                text: $draft.title,
                prompt: Text("제목을 붙여주세요").foregroundStyle(Color.textTertiary),
                axis: .vertical
            )
            .textStyle(.h2)
            .foregroundStyle(Color.textPrimary)
            .focused($focus, equals: .title)
            .submitLabel(.next)
            .onSubmit { focus = .body }

            bodyEditor

            Text("\(draft.body.count)자")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("\(draft.body.count)자 작성함")

            HStack(spacing: Space.md) {
                Button("조용히 품기") { publish(floated: false) }
                    .buttonStyle(.secondary)
                Button("별 띄우기") { publish(floated: true) }
                    .buttonStyle(.primary)
            }
            .disabled(!canPublish)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xl)
        .background { StarField() }
        .onAppear {
            draft = model.draft
            isSaved = !model.draft.isEmpty
            if draft.isEmpty { focus = .body }
        }
        // Covers leaving by back swipe before the autosave fires.
        .onDisappear { if !didPublish { model.saveDraft(draft) } }
        // Autosave shortly after typing stops.
        .task(id: draft) {
            guard draft != model.draft else { return }
            isSaved = false
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            model.saveDraft(draft)
            isSaved = !draft.isEmpty
        }
    }

    private var topBar: some View {
        FlowTopBar(title: "별 만들기", onClose: close) {
            Text("임시저장됨")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .opacity(isSaved ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isSaved)
        }
    }

    private var bodyEditor: some View {
        TextEditor(text: $draft.body)
            .textStyle(.journalBody)
            .foregroundStyle(Color.textSecondary)
            .scrollContentBackground(.hidden)
            .focused($focus, equals: .body)
            // TextEditor insets its text by ~5pt; pull it back to the column edge.
            .padding(.horizontal, -5)
            .padding(.top, -8)
            .overlay(alignment: .topLeading) {
                if draft.body.isEmpty {
                    Text("마음에 머무는 이야기를 적어주세요.")
                        .textStyle(.journalBody)
                        .foregroundStyle(Color.textTertiary)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxHeight: .infinity)
    }

    /// Saves the draft and asks the parent to close. Also used by the back swipe.
    func close() {
        model.saveDraft(draft)
        onClose()
    }

    private func publish(floated: Bool) {
        focus = nil
        didPublish = true
        onPublish(draft, floated)
    }
}

#Preview {
    StarMakingView(onClose: {}, onPublish: { _, _ in })
        .environment(AppModel())
}

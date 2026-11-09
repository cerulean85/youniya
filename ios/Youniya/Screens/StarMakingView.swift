import SwiftUI

/// 05 Star Making: write today's story, then float it with starlight (the
/// prism reads it) or without (17.1). Either way it fills the month's sky.
struct StarMakingView: View {
    @Environment(AppModel.self) private var model
    /// Called after the draft is saved; the parent closes the flow.
    var onClose: () -> Void
    /// Called with the draft: `floated` true for 별빛 받고 띄우기.
    var onPublish: (_ draft: StarDraft, _ floated: Bool) -> Void
    /// 05-2 고쳐 쓰기: the star with starlight being rewritten. The editor starts
    /// from its text, and 「새 별로 띄우기」 asks how (05-5).
    var revising: StarItem? = nil
    var onRevise: (StarDraft) -> Void = { _ in }
    /// Set by the flow once the rewrite went out, so leaving doesn't save it back.
    var revisePublished = false

    @State private var draft = StarDraft()
    @State private var isSaved = false
    @State private var didPublish = false
    /// 34 작성 중 나가기
    @State private var askLeave = DebugScreen.is("34")
    @State private var leaveSheetHeight: CGFloat = 320
    @FocusState private var focus: Field?

    private enum Field { case title, body }

    private var canPublish: Bool {
        !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// 104: starlight (analysis) needs 50 characters; 별빛 없이 띄우기 does not.
    private var canFloat: Bool { draft.body.count >= AppModel.minFloatLength }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            topBar

            if let revising {
                NoticeBanner(message: "「\(revising.title)」를 고쳐 쓰고 있어요. 원래 별과 별빛은 그대로 남고, 띄우면 새 별이 되어 원래 별과 이어져요.")
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(Mood.allCases) { mood in
                            MoodChip(mood: mood, isSelected: draft.moods.contains(mood)) {
                                draft.toggle(mood)
                            }
                        }
                    }
                }
                .scrollClipDisabled()
                // 17.5
                Text("오늘의 마음을 여러 개 고를 수 있어요 · 처음 고른 마음이 별의 색이 돼요")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField(
                "",
                text: $draft.title,
                prompt: Text("제목을 붙여주세요").foregroundStyle(Color.textTertiary),
                axis: .vertical
            )
            .textInputStyle(.h2)
            .foregroundStyle(Color.textPrimary)
            .focused($focus, equals: .title)
            .submitLabel(.next)
            .onSubmit { focus = .body }

            bodyEditor

            // Figma 05 "1,248자"; 104 "14자 · 36자 더 쓰면 별빛을 받을 수 있어요".
            Text(canFloat
                 ? "\(draft.body.count.formatted())자"
                 : "\(draft.body.count.formatted())자 · \((AppModel.minFloatLength - draft.body.count).formatted())자 더 쓰면 별빛을 받을 수 있어요")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("\(draft.body.count)자 작성함")

            if revising != nil {
                Button("새 별로 띄우기") {
                    focus = nil
                    onRevise(draft)
                }
                .buttonStyle(.primary)
                .disabled(!canPublish)
            } else {
                if canPublish && !canFloat {
                    NoticeBanner(message: "짧은 글은 '별빛 없이 띄우기'로 띄울 수 있어요")
                        .transition(.opacity)
                }

                HStack(spacing: Space.md) {
                    Button("별빛 없이 띄우기") { publish(floated: false) }
                        .buttonStyle(.secondary)
                        .disabled(!canPublish)
                    Button(model.floatButtonTitle) { publish(floated: true) }
                        .buttonStyle(.primary)
                        .disabled(!canFloat)
                }
                .animation(.easeInOut(duration: 0.2), value: canFloat)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xl)
        .background { StarField() }
        .onAppear {
            if let revising {
                draft = model.reviseDrafts[revising.id]
                    ?? StarDraft(mood: revising.mood, extraMoods: revising.extraMoods, title: revising.title, body: revising.body)
                isSaved = model.reviseDrafts[revising.id] != nil
                if !DebugScreen.is("5-5") { focus = .body }
                return
            }
            draft = model.draft
            isSaved = !model.draft.isEmpty
            if draft.isEmpty { focus = .body }
        }
        .sheet(isPresented: $askLeave) {
            LeaveDraftSheet(
                onSaveAndLeave: { askLeave = false; close() },
                onKeepWriting: { askLeave = false },
                onDiscard: { askLeave = false; discard() }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { leaveSheetHeight = $0 }
            .presentationDetents([.height(leaveSheetHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "leave-sheet") }
        }
        // Covers leaving by back swipe before the autosave fires.
        .onDisappear { if !didPublish && !revisePublished { save(draft) } }
        // Autosave shortly after typing stops.
        .task(id: draft) {
            guard draft != savedDraft else { return }
            isSaved = false
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            save(draft)
            isSaved = !draft.isEmpty
        }
    }

    private var topBar: some View {
        FlowTopBar(title: revising == nil ? "별 만들기" : "고쳐 쓰기", onClose: closeTapped) {
            Text("임시 저장됨")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .opacity(isSaved ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isSaved)
        }
    }

    private var bodyEditor: some View {
        TextEditor(text: $draft.body)
            .textInputStyle(.journalBody)
            .foregroundStyle(Color.textSecondary)
            .scrollContentBackground(.hidden)
            .focused($focus, equals: .body)
            // TextEditor insets its text by ~5pt; pull it back to the column edge.
            .padding(.horizontal, -5)
            .padding(.top, -8)
            .overlay(alignment: .topLeading) {
                if draft.body.isEmpty {
                    Text("마음에 머무는 이야기를 적어주세요.")
                        .textInputStyle(.journalBody)
                        .foregroundStyle(Color.textTertiary)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxHeight: .infinity)
    }

    /// "닫기": with something written, ask first (34).
    private func closeTapped() {
        if draft.isEmpty {
            close()
        } else {
            focus = nil
            askLeave = true
        }
    }

    /// 05-2 keeps its own working copy, apart from the new-star draft.
    private var savedDraft: StarDraft {
        revising.map { model.reviseDrafts[$0.id] ?? StarDraft() } ?? model.draft
    }

    private func save(_ d: StarDraft) {
        if let revising { model.reviseDrafts[revising.id] = d } else { model.saveDraft(d) }
    }

    /// Saves the draft and asks the parent to close. Also used by the back swipe.
    func close() {
        save(draft)
        onClose()
    }

    /// 34 "버리기": clear the draft and leave without saving it again.
    private func discard() {
        didPublish = true
        draft = StarDraft()
        if let revising { model.reviseDrafts[revising.id] = nil } else { model.saveDraft(StarDraft()) }
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

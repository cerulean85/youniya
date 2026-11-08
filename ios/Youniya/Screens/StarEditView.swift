import SwiftUI

/// 글 수정 (from 12): the same editor as 05, with one "저장".
/// Kept stars change mood, title and body; floated stars keep their mood (the
/// star's shape and report stay as first floated).
struct StarEditView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onClose: () -> Void

    @State private var mood: Mood = .calm
    @State private var title = ""
    @State private var text = ""
    @State private var saving = false
    /// 37: the edited writing shows a crisis signal.
    @State private var showCrisis = false
    @FocusState private var focus: Field?
    private enum Field { case title, body }

    private var star: StarItem? { model.stars.first { $0.id == starID } }
    private var floated: Bool { star?.isFloated ?? false }
    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !saving }

    var body: some View {
        if showCrisis {
            CrisisCareView(onContinue: onClose)
                .transition(.opacity)
        } else {
            editor
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            FlowTopBar(title: "글 수정", onClose: onClose)

            if floated {
                NoticeBanner(message: "별의 모양과 리포트는 처음 띄운 글 그대로 남아요.")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(Mood.allCases) { m in
                        MoodChip(mood: m, isSelected: mood == m) { if !floated { mood = m } }
                            .opacity(floated && mood != m ? 0.4 : 1)
                    }
                }
            }
            .scrollClipDisabled()
            .disabled(floated)
            .accessibilityHint(floated ? "띄운 별의 기분은 바꿀 수 없어요" : "")

            TextField("", text: $title, prompt: Text("제목을 붙여주세요").foregroundStyle(Color.textTertiary), axis: .vertical)
                .textInputStyle(.h2)
                .foregroundStyle(Color.textPrimary)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .body }

            TextEditor(text: $text)
                .textInputStyle(.journalBody)
                .foregroundStyle(Color.textSecondary)
                .scrollContentBackground(.hidden)
                .focused($focus, equals: .body)
                .padding(.horizontal, -5)
                .padding(.top, -8)
                .frame(maxHeight: .infinity)

            Text("\(text.count.formatted())자")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Button("저장", action: save)
                .buttonStyle(.primary)
                .disabled(!canSave)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xl)
        .background { StarField() }
        .onAppear {
            guard let star else { return }
            mood = star.mood
            title = star.title
            text = star.body
            focus = .body
        }
    }

    private func save() {
        saving = true
        Task { @MainActor in
            let crisis = await model.editStar(starID, mood: floated ? nil : mood, title: title, body: text)
            saving = false
            guard let crisis else { return }
            if crisis {
                focus = nil
                withAnimation(.easeInOut(duration: 0.5)) { showCrisis = true }
            } else {
                onClose()
            }
        }
    }
}

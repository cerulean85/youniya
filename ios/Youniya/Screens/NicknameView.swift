import SwiftUI

/// 21-1 / 21-2 별지기 이름 정하기 (after 11, or before the plaza for older
/// accounts) and 87-7 별지기 이름 바꾸기. The name is checked as it is typed:
/// 「✓ 쓸 수 있는 이름이에요 · 4/12」 or why not (21-2, red).
struct NicknameView: View {
    enum Mode { case signup, plaza, change, operatorRequest }

    @Environment(AppModel.self) private var model
    var mode: Mode
    var onBack: () -> Void
    var onDone: () -> Void

    @State private var name = ""
    @State private var result: NicknameResult?
    @State private var checking = false
    @State private var saving = false
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var tooSoon: Bool { mode == .change && !model.nicknameRenameRequired && model.nicknameNextChangeText != nil }
    private var canSave: Bool {
        if case .ok = result, !checking, !saving, !tooSoon, trimmed != model.nickname { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: mode == .change || mode == .operatorRequest ? "별지기 이름" : "가입", onBack: onBack)

            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(mode == .change || mode == .operatorRequest ? "별지기 이름 바꾸기" : "별지기 이름을 정해 주세요")
                        .textStyle(.h1).foregroundStyle(Color.textPrimary)
                    Text(subtitle).textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("별지기 이름").textStyle(.labelS).foregroundStyle(Color.textSecondary)
                    TextField("", text: $name, prompt: Text("예: 느린고래").foregroundStyle(Color.textTertiary))
                        .textStyle(.h3)
                        .foregroundStyle(Color.textPrimary)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { if canSave { save() } }
                }
                .padding(Space.lg)
                .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(borderColor, lineWidth: 1.2))

                statusLine

                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(["2~12자, 한글·영문·숫자로 정해요.", "다른 별지기와 겹칠 수 없어요.",
                             "실명이나 연락처는 쓰지 않는 게 좋아요.", "30일에 한 번 바꿀 수 있어요."], id: \.self) {
                        Text("• " + $0).textStyle(.caption).foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer(minLength: 0)

                Button(mode == .change || mode == .operatorRequest ? "바꾸기" : "이 이름으로 시작하기", action: save)
                    .buttonStyle(.primary)
                    .disabled(!canSave)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .onAppear {
            if mode == .change || mode == .operatorRequest, let n = model.nickname { name = n }
            focused = !tooSoon
        }
        // Checked shortly after typing stops.
        .task(id: trimmed) {
            guard !trimmed.isEmpty else { result = nil; return }
            checking = true
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            result = await model.checkNickname(trimmed)
            checking = false
        }
    }

    private var subtitle: String {
        switch mode {
        case .signup: "우주 광장에 별을 나누면 이 이름이 함께 보여요. 내가 건넨 별빛 한 줄에도 이 이름이 보여요."
        case .plaza: "우주 광장을 쓰려면 별지기 이름이 필요해요. 나눈 별과 건넨 별빛 한 줄에 이 이름이 보여요."
        case .change: "바꾸면 지금까지 나눈 별과 남긴 별빛 한 줄에도 새 이름이 보여요."
        case .operatorRequest: "운영자가 이름을 바꿔 달라고 요청했어요. 사칭이나 불편을 줄 수 있는 이름이라는 신고가 확인됐어요. 바꾸면 나눈 별과 남긴 별빛 한 줄에도 새 이름이 보여요."
        }
    }

    private var borderColor: Color {
        if case .problem = result { return .brandWarm }
        return Color.borderFocus.opacity(0.6)
    }

    @ViewBuilder private var statusLine: some View {
        if mode == .operatorRequest && (result == nil || trimmed == model.nickname) {
            // 87-8
            Text("운영자 요청이라 30일 제한 없이 지금 바로 바꿀 수 있어요").textStyle(.labelS).foregroundStyle(Color.starBright)
        } else if tooSoon, let day = model.nicknameNextChangeText {
            Text("다음 변경은 \(day)부터 할 수 있어요").textStyle(.labelS).foregroundStyle(Color.emotionCalm)
        } else if case .problem(let why) = result {
            Text(why).textStyle(.labelS).foregroundStyle(Color.brandWarm)
        } else if case .ok = result, !trimmed.isEmpty {
            Text(trimmed == model.nickname ? "지금 쓰고 있는 이름이에요" : "✓ 쓸 수 있는 이름이에요 · \(trimmed.count)/12")
                .textStyle(.labelS).foregroundStyle(Color.emotionCalm)
        }
    }

    private func save() {
        saving = true
        focused = false
        Task { @MainActor in
            let r = await model.setNickname(trimmed)
            saving = false
            if case .ok = r { onDone() } else { result = r }
        }
    }
}

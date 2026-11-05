import SwiftUI

// MARK: - 33 Coin History

/// 33 Coin History (코인 내역): charges and uses, newest first.
struct CoinHistoryView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "코인 내역", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    CoinHero()

                    if model.coinHistory.isEmpty {
                        Text("아직 코인 내역이 없어요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Space.xl)
                    } else {
                        LazyVStack(spacing: Space.md) {
                            ForEach(model.coinHistory) { entry in
                                InfoCard(seed: entry.id.uuidString, title: entry.title, detail: detail(entry))
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }

    /// "−30 · 11월 3일" / "+120 · 11월 1일"
    private func detail(_ e: CoinEntry) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        let amount = e.delta < 0 ? "−\(-e.delta)" : "+\(e.delta)"
        return "\(amount) · \(f.string(from: e.date))"
    }
}

// MARK: - 87 Settings

/// 87 Settings (설정): motion, sound, notifications, plaza, data, help.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    var onBack: () -> Void
    /// Sub-pages not built yet (68, 91–94, 43–46).
    var onOpen: (String) -> Void

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            TopAppBar(title: "설정", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.sm) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("나에게 맞는 밤하늘")
                            .textStyle(.h2)
                            .foregroundStyle(Color.textPrimary)
                        Text("필요한 것만 켜 두세요. 언제든 바꿀 수 있어요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    SettingsSection("화면과 움직임") {
                        SettingsRow(icon: .iconMoon, title: "우주의 색") { onOpen("우주의 색") }
                        SettingsToggleRow(icon: .iconStar, title: "애니메이션 줄이기", isOn: $model.settings.reduceAnimations)
                        // TODO: Haptics are not used anywhere yet.
                        SettingsToggleRow(icon: .iconPhone, title: "진동", isOn: $model.settings.haptics)
                    }

                    SettingsSection("소리", note: "\(model.settings.sound), 미세한 성간 주파수처럼 마음을 가라앉히는 소리예요.") {
                        // TODO: Ambient audio playback.
                        SettingsToggleRow(icon: .iconMoon, title: "앰비언스 사운드", isOn: $model.settings.ambience)
                        SettingsRow(icon: .iconHeart, title: "소리 고르기", value: model.settings.sound) { onOpen("소리 고르기") }
                    }

                    SettingsSection("알림", note: "연속 기록이나 재촉하는 알림은 보내지 않아요.") {
                        // TODO: Ask for notification permission and schedule it.
                        SettingsToggleRow(icon: .iconBell, title: "별 만들기 알림", isOn: $model.settings.starReminder)
                    }

                    SettingsSection("우주 광장") {
                        SettingsRow(icon: .iconNebula, title: "나눈 성운",
                                    value: "\(model.stars.filter(\.isShared).count)개") { onOpen("나눈 성운") }
                        SettingsRow(icon: .iconLock, title: "모든 공유 거두기") { onOpen("모든 공유 거두기") }
                    }

                    SettingsSection("데이터") {
                        SettingsRow(icon: .iconExport, title: "데이터 내보내기") { onOpen("데이터 내보내기") }
                        SettingsRow(icon: .iconTrash, title: "계정 영구 삭제") { onOpen("계정 영구 삭제") }
                    }

                    SettingsSection("도움") {
                        SettingsRow(icon: .iconPhone, title: "24시간 위기 상담", value: "109") {
                            if let url = URL(string: "tel://109") { openURL(url) }
                        }
                        SettingsRow(icon: .iconFile, title: "약관 및 정책") { onOpen("약관 및 정책") }
                        SettingsRow(icon: .iconLogout, title: "로그아웃") { model.signOut() }
                    }
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }
}

/// Figma settings section: small grey header, rows, optional note.
private struct SettingsSection<Rows: View>: View {
    var title: String
    var note: String?
    @ViewBuilder var rows: Rows

    init(_ title: String, note: String? = nil, @ViewBuilder rows: () -> Rows) {
        self.title = title
        self.note = note
        self.rows = rows()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .textStyle(.labelS)
                .foregroundStyle(Color.textTertiary)
                .accessibilityAddTraits(.isHeader)
            rows
            if let note {
                Text(note)
                    .textStyle(.captionTab)
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }
        }
        .padding(.top, Space.md)
    }
}

/// Figma `Settings Row` (Nav / Value): icon, title, optional value, chevron.
private struct SettingsRow: View {
    var icon: ImageResource
    var title: String
    var value: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLayout(icon: icon, title: title) {
                if let value {
                    Text(value)
                        .textStyle(.bodyS)
                        .foregroundStyle(Color.textSecondary)
                }
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Figma `Settings Row` (Toggle) with the Figma `Toggle` (44×26).
private struct SettingsToggleRow: View {
    var icon: ImageResource
    var title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { withAnimation(.snappy(duration: 0.2)) { isOn.toggle() } } label: {
            SettingsRowLayout(icon: icon, title: title) {
                Capsule()
                    .fill(isOn ? Color.brandPrimary : Color.borderDefault)
                    .frame(width: 44, height: 26)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 20, height: 20).padding(3)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "켜짐" : "꺼짐")
        .accessibilityAddTraits(.isToggle)
    }
}

private struct SettingsRowLayout<Trailing: View>: View {
    var icon: ImageResource
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Space.md) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.textSecondary)
            Text(title)
                .textStyle(.bodyM)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.vertical, Space.md)
        // Figma rows: 47pt (nav/value), 51pt (toggle)
        .frame(minHeight: 47)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Color.borderDefault.frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 32 Inquiry

/// 32 Inquiry (문의하기): type and message. Sending is mocked.
struct InquiryView: View {
    var onBack: () -> Void

    private let kinds = ["결제", "계정", "기타"]
    @State private var kind: String?
    @State private var message = ""
    @State private var sent = false
    @FocusState private var editing: Bool

    private var canSend: Bool {
        kind != nil && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "문의하기", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("무엇이 궁금하세요?")
                            .textStyle(.h1)
                            .foregroundStyle(Color.textPrimary)
                        Text("내용과 연락 받을 이메일을 남겨 주세요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    VStack(spacing: Space.md) {
                        Menu {
                            ForEach(kinds, id: \.self) { k in
                                Button(k) { kind = k }
                            }
                        } label: {
                            InfoCard(seed: "inquiry-kind", title: "문의 유형", detail: kind ?? kinds.joined(separator: " · "))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("내용")
                                .textStyle(.labelM)
                                .foregroundStyle(Color.textPrimary)
                            TextField("여기에 적어 주세요", text: $message, axis: .vertical)
                                .textStyle(.bodyS)
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1...10)
                                .focused($editing)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.lg)
                        .itemCard(seed: "inquiry-message")
                        .onTapGesture { editing = true }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Button(sent ? "보냈어요" : "보내기") { send() }
                .buttonStyle(.primary)
                .disabled(!canSend || sent)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }

    private func send() {
        // TODO: Send to the support API with the account email.
        editing = false
        withAnimation(.snappy) { sent = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            onBack()
        }
    }
}

#Preview("33") {
    let model = AppModel()
    model.addCoins(120)
    _ = model.spendCoins(30)
    return CoinHistoryView(onBack: {}).environment(model)
}

#Preview("87") {
    SettingsView(onBack: {}, onOpen: { _ in }).environment(AppModel())
}

#Preview("32") {
    InquiryView(onBack: {})
}

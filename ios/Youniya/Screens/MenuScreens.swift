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
                        // 108
                        EmptyStateView(title: "아직 쓴 코인이 없어요",
                                       message: "마음 망원경 등에 쓴 코인이\n여기에 차례로 쌓여요.")
                            .padding(.top, Space.md)
                    } else {
                        LazyVStack(spacing: Space.md) {
                            ForEach(model.coinHistory) { entry in
                                InfoCard(seed: entry.id.uuidString, title: entry.displayTitle, detail: detail(entry))
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
        .task { await model.loadCoins() }
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
    /// → 나눈 별
    var onOpen: (String) -> Void
    /// → 68 우주의 색
    var onSky: () -> Void = {}
    /// → 43–46
    var onPolicy: (PolicyDoc) -> Void = { _ in }

    /// 91–94 bottom sheets over Settings.
    private enum Sheet: Identifiable {
        case deleteAccount, withdrawShares, export, sound
        case reminderTime // 87-2
        case signOut // 87-5
        case notificationsOff // iOS notifications are turned off for the app
        case exporting(DataExport.Format) // 114
        var id: String { "\(self)" }
    }
    @State private var sheet: Sheet?
    @State private var sheetHeight: CGFloat = 346
    /// Run after the sheet is gone (e.g. 91 → 93, or signing out).
    @State private var afterDismiss: (() -> Void)?
    @State private var showPolicies = false
    /// M1 from 87-4 "알아보기".
    @State private var showMembership = false
    @State private var exportProgress = 0.0
    @State private var toast: String?
    /// Live 92: GET /v1/me/shares counts.
    @State private var liveShareCounts: (stars: Int, nebulae: Int)?

    /// Figma note under 소리 고르기 (written for 밤바람).
    private var soundNote: String {
        model.settings.sound == Self.sounds[0]
            ? "밤바람, 미세한 성간 주파수처럼 마음을 가라앉히는 소리예요."
            : "\(model.settings.sound)처럼 마음을 가라앉히는 소리예요."
    }

    /// The sound choices in 94. TODO: Play them once ambient audio exists.
    static let sounds = ["밤바람", "미세한 성간 주파수"]

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

                    // 87-4 (v1.1, off in the release build)
                    if model.membershipOn {
                        MembershipSettingsSection(onLearnMore: { showMembership = true })
                    }

                    SettingsSection("화면과 움직임") {
                        SettingsRow(icon: .iconMoon, title: "우주의 색") { onSky() }
                        SettingsToggleRow(icon: .iconStar, title: "애니메이션 줄이기", isOn: $model.settings.reduceAnimations)
                        // TODO: Haptics are not used anywhere yet.
                        SettingsToggleRow(icon: .iconVibrate, title: "진동", isOn: $model.settings.haptics)
                    }

                    SettingsSection("소리", note: soundNote) {
                        // TODO: Ambient audio playback.
                        SettingsToggleRow(icon: .iconSound, title: "앰비언스 사운드", isOn: $model.settings.ambience)
                        SettingsRow(icon: .iconHeart, title: "소리 고르기", value: model.settings.sound) { sheet = .sound }
                    }

                    SettingsSection("알림", note: model.settings.starReminder
                                    ? "별을 띄우지 않은 날에만 고른 시각에 한 번 알려 드려요. 연속 기록이나 재촉하는 알림은 보내지 않아요."
                                    : "연속 기록이나 재촉하는 알림은 보내지 않아요.") {
                        // 87 별 만들기 알림 (`StarReminder`), 87-1 알림 시각 when on.
                        SettingsToggleRow(icon: .iconBell, title: "별 만들기 알림",
                                          isOn: notificationToggle($model.settings.starReminder))
                        if model.settings.starReminder {
                            SettingsRow(icon: .iconMoon, title: "알림 시각",
                                        value: StarReminder.timeText(model.settings.reminderMinutes)) { sheet = .reminderTime }
                        }
                        // 11 (선택) 새 기능·혜택 알림: the same consent, changeable here.
                        SettingsToggleRow(icon: .iconInfo, title: "새 기능·혜택 알림",
                                          isOn: notificationToggle($model.marketingOptIn))
                    }

                    SettingsSection("우주 광장") {
                        SettingsRow(icon: .iconNebula, title: "나눈 별",
                                    value: "\(model.stars.filter(\.isShared).count)개") { onOpen("나눈 별") }
                        // 87-3
                        SettingsRow(icon: .iconClose, title: "차단한 별지기",
                                    value: "\(model.blockedKeepers.count)명") { onOpen("차단한 별지기") }
                        SettingsRow(icon: .iconLock, title: "모든 공유 거두기") { sheet = .withdrawShares }
                    }

                    SettingsSection("데이터") {
                        SettingsRow(icon: .iconExport, title: "데이터 내보내기") { sheet = .export }
                        SettingsRow(icon: .iconTrash, title: "계정 영구 삭제") { sheet = .deleteAccount }
                    }

                    SettingsSection("도움") {
                        SettingsRow(icon: .iconPhone, title: "24시간 위기 상담", value: "109") {
                            if let url = URL(string: "tel://109") { openURL(url) }
                        }
                        SettingsRow(icon: .iconFile, title: "약관 및 정책") { showPolicies = true }
                        SettingsRow(icon: .iconLogout, title: "로그아웃") { sheet = .signOut }
                    }
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .toast($toast)
        #if DEBUG
        // Visual review: `-debugRoute withdrawShares|notificationsOff` opens 92 / 95.
        .task {
            switch UserDefaults.standard.string(forKey: "debugRoute") {
            case "withdrawShares": sheet = .withdrawShares
            case "notificationsOff": sheet = .notificationsOff
            default: break
            }
            // `-debugScreen 91…95, 114`
            if DebugScreen.is("91") { sheet = .deleteAccount }
            if DebugScreen.is("92") { sheet = .withdrawShares }
            if DebugScreen.is("93") { sheet = .export }
            if DebugScreen.is("94") { sheet = .sound }
            if DebugScreen.is("87-5") { sheet = .signOut }
            if DebugScreen.is("87-1") || DebugScreen.is("87-2") {
                // As in Figma: the reminder on, 새 기능·혜택 알림 off.
                model.settings.starReminder = true
                model.marketingOptIn = false
            }
            if DebugScreen.is("87-2") { sheet = .reminderTime }
            if DebugScreen.is("95") { sheet = .notificationsOff }
            if DebugScreen.is("114") { exportProgress = 0.62; sheet = .exporting(.text) }
        }
        #endif
        .task(id: sheet?.id) {
            guard model.useLiveAPI, case .withdrawShares = sheet else { return }
            liveShareCounts = try? await model.shareCounts()
        }
        // No Figma page lists the documents; a dialog keeps it to one tap.
        .confirmationDialog("약관 및 정책", isPresented: $showPolicies, titleVisibility: .visible) {
            ForEach(PolicyDoc.allCases.filter { $0 != .marketing }) { doc in
                Button(doc.title) { onPolicy(doc) }
            }
        }
        .membershipSheet(isPresented: $showMembership, onPolicy: onPolicy)
        .sheet(item: $sheet, onDismiss: {
            afterDismiss?()
            afterDismiss = nil
        }) { which in
            sheetContent(which)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
                .presentationDetents([.height(sheetHeight)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.xl)
                .presentationBackground { SheetBackground(seed: "settings-sheet") }
        }
    }

    @ViewBuilder
    private func sheetContent(_ which: Sheet) -> some View {
        switch which {
        case .deleteAccount: // 91
            ActionSheetContent(
                title: "계정을 영구 삭제할까요?",
                message: "별과 성운, 은하수, 계정 정보가 모두 흔적 없이 사라지고 되돌릴 수 없어요. 먼저 내 데이터를 내보내 둘 수 있어요.",
                primary: ("영구 삭제", { close { model.deleteAccount() } }),
                secondary: ("먼저 내보내기", { close { sheet = .export } }),
                ghost: ("취소", { close() }),
                destructive: true
            )
        case .withdrawShares: // 92
            ActionSheetContent(
                title: "나눈 별과 성운을 모두 거둘까요?",
                message: withdrawMessage,
                primary: ("모두 거두기", { close { model.withdrawAllShares() } }),
                secondary: ("그대로 두기", { close() }),
                ghost: nil
            )
        case .export: // 93
            ActionSheetContent(
                title: "어떤 형식으로 내보낼까요?",
                message: "쓴 별과 성운 이야기를 모두 파일로 내려받아요. 파일은 내 기기에만 저장돼요.",
                primary: ("텍스트 파일로", { close { sheet = .exporting(.text) } }),
                secondary: ("PDF로", { close { sheet = .exporting(.pdf) } }),
                ghost: ("닫기", { close() })
            )
        case .exporting(let format): // 114
            ExportProgressSheet(
                detail: "별 \(model.stars.count)개와 성운 이야기 \(max(1, model.drawnNebulae.count))편을 \(format == .pdf ? "PDF" : "텍스트") 파일로 모으고 있어요. 창을 닫아도 이어서 만들어요.",
                progress: exportProgress,
                // "창을 닫아도 이어서 만들어요": closing still finishes the file.
                onClose: { close { export(format) } }
            )
            .task {
                if DebugScreen.is("114") { return }  // visual review: hold at 62%
                exportProgress = 0
                for step in 1...10 {
                    try? await Task.sleep(for: .milliseconds(140))
                    withAnimation(.linear(duration: 0.14)) { exportProgress = Double(step) / 10 }
                }
                close { export(format) }
            }
        case .notificationsOff:
            ActionSheetContent(
                title: "알림이 꺼져 있어요",
                message: "알림을 받으려면 iPhone 설정에서 YOUNIYA 알림을 켜 주세요.",
                primary: ("설정 열기", { close { NotificationAccess.openSettings() } }),
                secondary: ("닫기", { close() }),
                ghost: nil
            )
        case .signOut: // 87-5 로그아웃할까요?
            SignOutSheet(onSignOut: { close { model.signOut() } }, onCancel: { close() })
        case .reminderTime: // 87-2
            ReminderTimeSheet(
                minutes: model.settings.reminderMinutes,
                onSave: { m in close { model.settings.reminderMinutes = m } },
                onCancel: { close() }
            )
        case .sound: // 94
            ActionSheetContent(
                title: "어떤 소리와 함께할까요?",
                message: "마음을 가라앉히는 앰비언스예요. 설정에서 언제든 끌 수 있어요.",
                primary: (Self.sounds[0], { close { model.settings.sound = Self.sounds[0] } }),
                secondary: (Self.sounds[1], { close { model.settings.sound = Self.sounds[1] } }),
                ghost: ("닫기", { close() })
            )
        }
    }

    /// A notification toggle: turning it on asks iOS for permission first, and
    /// stays off (with a way to the Settings app) when notifications are not allowed.
    private func notificationToggle(_ value: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue },
            set: { on in
                guard on else { value.wrappedValue = false; return }
                Task {
                    if await NotificationAccess.request() {
                        withAnimation(.snappy(duration: 0.2)) { value.wrappedValue = true }
                    } else {
                        sheet = .notificationsOff
                    }
                }
            }
        )
    }

    /// 92 body (Figma 154:336): "나눈 별 2개와 성운 1개", leaving out a kind with none.
    private var withdrawMessage: String {
        let (stars, nebulae) = model.useLiveAPI
            ? (liveShareCounts?.stars ?? 0, liveShareCounts?.nebulae ?? 0)
            : (model.stars.filter(\.isShared).count, model.drawnNebulae.filter(\.shared).count)
        let what: String
        switch (stars, nebulae) {
        case (0, 0): what = "나눈 별과 성운을"
        case (_, 0): what = "나눈 별 \(stars)개를"
        case (0, _): what = "성운 \(nebulae)개를"
        default: what = "나눈 별 \(stars)개와 성운 \(nebulae)개를"
        }
        return "우주 광장에서 \(what) 거둬요. 그동안 받은 공명과 별빛 한 줄은 그대로 간직돼요. 언제든 다시 나눌 수 있어요."
    }

    /// Closes the sheet, then runs `then` once it is gone.
    private func close(then: (() -> Void)? = nil) {
        afterDismiss = then
        sheet = nil
    }

    private func export(_ format: DataExport.Format) {
        do {
            _ = try DataExport.write(model.exportText(), as: format)
            toast = "파일로 내보냈어요"
        } catch {
            toast = "내보내지 못했어요. 다시 시도해 주세요"
        }
    }
}

/// Figma settings section: small grey header, rows, optional note.
/// 87-5 로그아웃할까요?: the writing stays; signing in again brings it back.
private struct SignOutSheet: View {
    var onSignOut: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("로그아웃할까요?").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("쓴 글과 별은 그대로 남아 있어요. 다시 로그인하면 이어서 볼 수 있어요.")
                    .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            VStack(spacing: Space.md) {
                Button("로그아웃", action: onSignOut).buttonStyle(.primary)
                Button("취소", action: onCancel).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
    }
}

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
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }
        }
        .padding(.top, Space.md)
    }
}

/// Figma `Settings Row` (Nav / Value): icon, title, optional value, chevron.
struct SettingsRow: View {
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

struct SettingsRowLayout<Trailing: View>: View {
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
    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    private let kinds = ["결제", "계정", "기타"]
    /// The API's payment · account · other.
    private let apiKinds = ["결제": "payment", "계정": "account", "기타": "other"]
    @State private var kind: String?
    @State private var email = ""
    @State private var message = ""
    @State private var sent = false
    @State private var sending = false
    @FocusState private var editing: Bool
    @FocusState private var editingEmail: Bool

    /// The server's check: something@something.something, at most 255 characters.
    private var emailIsValid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.count <= 255 && e.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) != nil
    }

    private var canSend: Bool {
        kind != nil && emailIsValid && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                        // Figma 32: "답장 받을 이메일" (no email is kept on the account).
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("답장 받을 이메일")
                                .textStyle(.labelM)
                                .foregroundStyle(Color.textPrimary)
                            TextField("", text: $email,
                                      prompt: Text(verbatim: "name@example.com").foregroundStyle(Color.textSecondary))
                                .textInputStyle(.bodyS)
                                .foregroundStyle(Color.textPrimary)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($editingEmail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.lg)
                        .itemCard(seed: "inquiry-email")
                        .onTapGesture { editingEmail = true }

                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("내용")
                                .textStyle(.labelM)
                                .foregroundStyle(Color.textPrimary)
                            TextField("", text: $message,
                                      prompt: Text("여기에 적어 주세요").foregroundStyle(Color.textSecondary),
                                      axis: .vertical)
                                .textInputStyle(.bodyS)
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
                .disabled(!canSend || sent || sending)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }

    /// Live: POST /v1/inquiries {kind, email, body}.
    private func send() {
        editing = false
        editingEmail = false
        Task { @MainActor in
            if model.useLiveAPI {
                struct Body: Encodable { var kind: String; var email: String; var body: String }
                sending = true
                defer { sending = false }
                do {
                    try await APIClient.shared.sendRaw("POST", "/v1/inquiries", body: Body(
                        kind: apiKinds[kind ?? "기타"] ?? "other",
                        email: email.trimmingCharacters(in: .whitespaces),
                        body: message.trimmingCharacters(in: .whitespacesAndNewlines)))
                } catch {
                    model.handle(error)
                    return
                }
            }
            withAnimation(.snappy) { sent = true }
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

import SwiftUI

// App Store 1.2 (user-generated content): report and block on every plaza item,
// and a list to undo blocks. 2.1: an invite account for App Review.

extension Color {
    /// Figma red text (#F87171): "이 별지기 차단하기", sign-in errors.
    static let dangerText = Color.hex(0xF87171)
}

// MARK: - Model

/// One blocked 별지기. Anonymous: the app only knows where they were blocked.
struct BlockedKeeper: Identifiable, Codable, Hashable {
    enum Source: String, Codable {
        case star, nebula, line
        var label: String {
            switch self {
            case .star: "별"
            case .nebula: "별"
            case .line: "별빛 한 줄"
            }
        }
    }
    var id: String = UUID().uuidString
    var source: Source
    var blockedAt: Date = .now
    /// Mock: the plaza nebula the keeper was blocked from, to hide it on device.
    var nebulaName: String?

    /// "별빛 한 줄 · 11월 5일 차단"
    var detail: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return "\(source.label) · \(f.string(from: blockedAt)) 차단"
    }

    /// Figma 87-3 samples.
    static let samples: [BlockedKeeper] = {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        return [
            BlockedKeeper(source: .line, blockedAt: cal.date(from: DateComponents(year: year, month: 11, day: 5)) ?? .now),
            BlockedKeeper(source: .star, blockedAt: cal.date(from: DateComponents(year: year, month: 10, day: 28)) ?? .now),
        ]
    }()
}

/// What the "···" menu acts on (75, 73, 78).
enum PlazaReportTarget: Equatable {
    case star, nebula
    var reportTitle: String { self == .star ? "이 별 신고하기" : "이 별 신고하기" }
    var sheetTitle: String { self == .star ? "이 별을 신고할까요?" : "이 별을 신고할까요?" }
    var sheetBody: String {
        self == .star
            ? "신고한 별은 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요."
            : "신고한 별은 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요."
    }
}

extension AppModel {
    /// 75-2 차단하기. Mock: hides that keeper's nebula on this device.
    /// Live: `POST /v1/blocks`; the server hides them from then on.
    @MainActor func block(_ source: BlockedKeeper.Source, nebulaName: String?, target: PlazaTarget?) async -> Bool {
        guard useLiveAPI else {
            blockedKeepers.insert(BlockedKeeper(source: source, nebulaName: nebulaName), at: 0)
            return true
        }
        guard let target else { return false }
        return await blockLive(target)
    }

    /// 87-3 차단 풀기.
    @MainActor func unblock(_ keeper: BlockedKeeper) async -> Bool {
        guard useLiveAPI else { blockedKeepers.removeAll { $0.id == keeper.id }; return true }
        return await unblockLive(keeper)
    }

    /// Mock: plaza nebula names hidden by a block.
    var blockedNebulaNames: Set<String> { Set(blockedKeepers.compactMap(\.nebulaName)) }
}

// MARK: - "···" menu (75-1)

/// Figma `More Button`: 44pt round, slate 80%, three dots.
struct MoreButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.textPrimary).frame(width: 4, height: 4) }
            }
            .frame(width: 44, height: 44)
            .background(Color.bgSurface.opacity(0.8), in: .circle)
            .overlay(Circle().strokeBorder(Color.borderDefault, lineWidth: 1))
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("더 보기")
    }
}

/// 75-1 `More Menu`: report, and block in red. Shown under the top bar.
struct PlazaMoreMenu: View {
    var target: PlazaReportTarget
    var onReport: () -> Void
    var onBlock: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            item(.iconWarning, template: false, target.reportTitle, "운영팀이 살펴봐요", tone: Color.textPrimary, action: onReport)
            item(.iconClose, template: true, "이 별지기 차단하기", "이 사람의 글이 더 보이지 않아요", tone: Color.dangerText, action: onBlock)
        }
        .padding(Space.sm)
        .cosmos("more-menu", in: RoundedRectangle(cornerRadius: Radius.xl))
        .background(Color.bgSurfaceRaised, in: .rect(cornerRadius: Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Color.borderDefault, lineWidth: 1))
    }

    private func item(_ icon: ImageResource, template: Bool, _ title: String, _ sub: String,
                      tone: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                Image(icon).renderingMode(template ? .template : .original).resizable()
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 24, height: 24)
                    .frame(width: 36, height: 36)
                    .background(Color.brandPrimary.opacity(0.16), in: .rect(cornerRadius: Radius.md))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.labelM).foregroundStyle(tone)
                    Text(sub).textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

extension View {
    /// 75-1: the "···" menu over a plaza page, closed by tapping anywhere else.
    func plazaMoreMenu(isPresented: Binding<Bool>, target: PlazaReportTarget,
                       onReport: @escaping () -> Void, onBlock: @escaping () -> Void) -> some View {
        overlay(alignment: .top) {
            if isPresented.wrappedValue {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.001)
                        .onTapGesture { withAnimation(.snappy(duration: 0.2)) { isPresented.wrappedValue = false } }
                    PlazaMoreMenu(
                        target: target,
                        onReport: { isPresented.wrappedValue = false; onReport() },
                        onBlock: { isPresented.wrappedValue = false; onBlock() }
                    )
                    .padding(.horizontal, Space.xl)
                    // Under the 52pt top bar, 4pt apart (Figma y 100).
                    .padding(.top, 56)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                }
            }
        }
    }
}

// MARK: - 75-2 Block confirm

/// 75-2 이 별지기를 차단할까요?
struct BlockConfirmSheet: View {
    var onBlock: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("이 별지기를 차단할까요?").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("차단하면 이 사람의 별과 별빛 한 줄이 내 화면에 더 이상 보이지 않아요. 상대에게는 알리지 않고, 설정 › 차단한 별지기에서 언제든 풀 수 있어요.")
                    .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            VStack(spacing: Space.md) {
                Button("차단하기", action: onBlock).buttonStyle(.danger)
                Button("취소", action: onCancel).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
    }
}

/// 75-1 / 75-2 on a plaza page: the menu, report sheet and block sheet together.
struct PlazaSafetyModifier: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var showMenu: Bool
    var target: PlazaReportTarget
    var nebulaName: String
    /// The nebula's plaza share id. Stars inside a plaza nebula (75) have no
    /// share of their own, so their report and block go to the nebula's owner.
    var serverID: String?
    /// After 차단하기: back to the previous page, with the "차단했어요" toast.
    var onBlocked: () -> Void

    @State private var reporting = false
    @State private var confirmBlock = DebugScreen.is("75-2")
    @State private var reportHeight: CGFloat = 480
    @State private var blockHeight: CGFloat = 300
    @State private var toast: ToastCardMessage?

    func body(content: Content) -> some View {
        content
            .plazaMoreMenu(isPresented: $showMenu, target: target,
                           onReport: { reporting = true }, onBlock: { confirmBlock = true })
            .animation(.snappy(duration: 0.2), value: showMenu)
            .toastCard($toast)
            .sheet(isPresented: $reporting) {
                ReportSheet(
                    title: target.sheetTitle, message: target.sheetBody,
                    onReport: { reason, alsoBlock in
                        reporting = false
                        Task { @MainActor in
                            if model.useLiveAPI {
                                guard let id = serverID,
                                      await model.reportLive(.nebula(id), reason: reason, block: alsoBlock) else { return }
                            } else if alsoBlock {
                                _ = await model.block(target == .star ? .star : .nebula, nebulaName: nebulaName, target: nil)
                            }
                            if alsoBlock {
                                onBlocked()
                            } else {
                                toast = ToastCardMessage(title: "신고를 받았어요", detail: "살펴본 뒤 결과를 알림으로 알려 드릴게요")
                            }
                        }
                    },
                    onCancel: { reporting = false }
                )
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { reportHeight = $0 }
                .presentationDetents([.height(reportHeight)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.xl)
                .presentationBackground { SheetBackground(seed: "report-sheet") }
            }
            .sheet(isPresented: $confirmBlock) {
                BlockConfirmSheet(
                    onBlock: {
                        confirmBlock = false
                        Task { @MainActor in
                            if await model.block(target == .star ? .star : .nebula, nebulaName: nebulaName,
                                                 target: serverID.map(PlazaTarget.nebula)) {
                                onBlocked()
                            }
                        }
                    },
                    onCancel: { confirmBlock = false }
                )
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { blockHeight = $0 }
                .presentationDetents([.height(blockHeight)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.xl)
                .presentationBackground { SheetBackground(seed: "block-sheet") }
            }
    }
}

// MARK: - 100 Report (with "이 별지기도 차단하기")

/// 100 이 별빛을 신고할까요? (also the star / nebula report): reasons, then an
/// optional block of the same keeper.
struct ReportSheet: View {
    var title = "이 별빛을 신고할까요?"
    var message = "신고한 별빛은 바로 가려지고 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요."
    /// The first picked reason (hurtful · personal_info · spam · other), and the block box.
    var onReport: (_ reason: String, _ alsoBlock: Bool) -> Void
    var onCancel: () -> Void

    private static let reasons = ["상처를 주는 말이에요", "개인정보가 드러나 있어요", "광고나 스팸이에요", "그 밖의 이유가 있어요"]
    private static let apiReasons = ["hurtful", "personal_info", "spam", "other"]
    @State private var picked: Set<String> = [reasons[0]]
    @State private var alsoBlock = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title).textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text(message)
                    .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Self.reasons, id: \.self) { r in
                    checkRow(r, isOn: picked.contains(r)) {
                        if picked.contains(r) { picked.remove(r) } else { picked.insert(r) }
                    }
                }
                // Figma 100: a gap, then the block box (off by default).
                checkRow("이 별지기도 차단하기", isOn: alsoBlock) { alsoBlock.toggle() }
                    .padding(.top, Space.sm)
            }
            VStack(spacing: Space.md) {
                Button("신고하기") {
                    let first = Self.reasons.firstIndex { picked.contains($0) } ?? 3
                    onReport(Self.apiReasons[first], alsoBlock)
                }
                .buttonStyle(.primary).disabled(picked.isEmpty)
                Button("취소", action: onCancel).buttonStyle(.secondary)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }

    private func checkRow(_ text: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                ZStack {
                    if isOn {
                        RoundedRectangle(cornerRadius: 6).fill(Color.brandPrimary)
                        Image(.iconCheck).resizable().frame(width: 14, height: 14)
                    } else {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(Color.borderDefault, lineWidth: 1.5)
                    }
                }
                .frame(width: 22, height: 22)
                Text(text).textStyle(.bodyM).foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .frame(minHeight: 46)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 87-3 Blocked keepers

/// 87-3 설정 · 차단한 별지기: like 17, with "차단 풀기".
struct BlockedKeepersView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    @State private var toast: ToastCardMessage?

    var body: some View {
        let keepers = model.blockedKeepers
        VStack(spacing: 0) {
            TopAppBar(title: "차단한 별지기", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    if keepers.isEmpty {
                        EmptyStateView(
                            title: "차단한 별지기가 없어요",
                            message: "우주 광장에서 차단한 사람이\n여기에 모여요.",
                            action: nil
                        )
                        .padding(.top, Space.xxxl)
                    } else {
                        Text("차단한 별지기 \(keepers.count)명이에요. 이 사람들의 별과 별빛 한 줄은 내 화면에 보이지 않아요. 풀면 다시 보여요.")
                            .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        LazyVStack(spacing: Space.md) {
                            ForEach(keepers) { row($0) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xxxl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .toastCard($toast)
        .animation(.snappy, value: keepers.map(\.id))
        .task { await model.loadBlocks() }
    }

    private func row(_ keeper: BlockedKeeper) -> some View {
        VStack(alignment: .trailing, spacing: Space.xs) {
            // Figma `Star Row` without the starlight badge.
            HStack(spacing: Space.md) {
                Image(.starShapeFloated).resizable().frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("익명의 별지기").textStyle(.bodyM).foregroundStyle(Color.textPrimary)
                    Text(keeper.detail).textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.lg)
            .frame(minHeight: 78)
            .cosmos(keeper.id, in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
            .accessibilityElement(children: .combine)

            Button("차단 풀기") {
                Task { @MainActor in
                    if await model.unblock(keeper) {
                        toast = .init(title: "차단을 풀었어요", detail: "이 사람의 글이 다시 보여요")
                    }
                }
            }
            .textStyle(.labelS)
            .foregroundStyle(Color.textSecondary)
            .buttonStyle(.plain)
            .padding(.vertical, Space.xs)
            .padding(.trailing, Space.xs)
            .accessibilityLabel("익명의 별지기 차단 풀기")
        }
        .transition(.opacity)
    }
}

// MARK: - 02-1 Invite account

/// 02-1 초대 계정으로 로그인: for App Review and accounts the team hands out.
struct InviteLoginSheet: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var failed = false
    @State private var working = false
    @FocusState private var focus: Field?
    private enum Field { case username, password }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("초대 계정으로 로그인").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("운영팀이 드린 계정으로만 들어올 수 있어요. 처음이라면 Apple이나 Google로 시작해 주세요.")
                    .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Space.md) {
                field("아이디", focused: .username) {
                    TextField("", text: $username)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                field("비밀번호", focused: .password) {
                    SecureField("", text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                }
                if failed {
                    Text("아이디나 비밀번호가 맞지 않아요.")
                        .textStyle(.caption).foregroundStyle(Color.dangerText)
                }
            }

            VStack(spacing: Space.md) {
                Button("로그인", action: signIn)
                    .buttonStyle(.primary)
                    .disabled(username.isEmpty || password.isEmpty || working)
                Button("취소", action: onClose).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
        .onChange(of: username) { failed = false }
        .onChange(of: password) { failed = false }
    }

    /// Figma `Text Field`: label, then a 48pt field (slate, Cosmos BG, 1pt border).
    private func field<F: View>(_ label: String, focused: Field, @ViewBuilder input: () -> F) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(label).textStyle(.labelS).foregroundStyle(Color.textSecondary)
            input()
                .textInputStyle(.bodyM)
                .foregroundStyle(Color.textPrimary)
                .focused($focus, equals: focused)
                .padding(.horizontal, Space.lg)
                .frame(height: 48)
                .cosmos("invite-\(label)", in: RoundedRectangle(cornerRadius: Radius.md))
                .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(focus == focused ? Color.borderFocus
                                  : (failed && focused == .password ? Color.dangerText : Color.borderDefault),
                                  lineWidth: 1))
                .contentShape(.rect)
                .onTapGesture { focus = focused }
        }
    }

    private func signIn() {
        guard !username.isEmpty, !password.isEmpty, !working else { return }
        working = true
        Task { @MainActor in
            let ok = await model.inviteSignIn(username: username, password: password)
            working = false
            if ok { onClose() } else { failed = true }
        }
    }
}

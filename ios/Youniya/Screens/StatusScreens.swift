import SwiftUI

// MARK: - Shared status layout (35, 36, 38, 39, 40, 41)

/// Figma status screens: an orb with an icon, a title, a short note, and actions,
/// all centered over the star field.
struct StatusView: View {
    struct Action {
        enum Style { case primary, secondary, ghost }
        var title: String
        var style: Style
        var disabled = false
        var run: () -> Void
    }

    var icon: ImageResource
    var title: String
    var message: String
    var actions: [Action]

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0)

            StatusHero(icon: icon)

            VStack(spacing: Space.lg) {
                Text(title)
                    .textStyle(.h2)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)

            VStack(spacing: Space.md) {
                ForEach(actions.indices, id: \.self) { i in
                    let a = actions[i]
                    Group {
                        switch a.style {
                        case .primary: Button(a.title, action: a.run).buttonStyle(.primary)
                        case .secondary: Button(a.title, action: a.run).buttonStyle(.secondary)
                        case .ghost: Button(a.title, action: a.run).buttonStyle(.ghost)
                        }
                    }
                    .disabled(a.disabled)
                }
            }

            Spacer(minLength: 0)
        }
        // Figma: content centered a little below the middle (status bar above).
        .padding(.horizontal, Space.xl)
        .padding(.top, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background { StarField() }
    }
}

/// Figma status `Hero` (120×120): two orbits, a violet orb with a gold icon, two stars.
struct StatusHero: View {
    var icon: ImageResource

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle().strokeBorder(Color.brandPrimary, lineWidth: 1)
                .frame(width: 120, height: 120).opacity(0.3)
            Circle().strokeBorder(Color.brandPrimary, lineWidth: 1)
                .frame(width: 92, height: 92).opacity(0.5)
                .offset(x: 14, y: 14)
            Circle().fill(Color.tintPrimary)
                .overlay(Circle().strokeBorder(Color.borderFocus, lineWidth: 1))
                .frame(width: 64, height: 64)
                .shadow(color: Color.brandPrimary.opacity(0.4), radius: 12)
                .offset(x: 28, y: 28)
            // Figma: the 24pt icon scaled to a 30pt slot, centred in the orb.
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.starBright)
                .offset(x: 45, y: 45)
            Circle().fill(Color.starBright)
                .frame(width: 6, height: 6)
                .shadow(color: Color.starBright.opacity(0.5), radius: 14)
                .offset(x: 97, y: 17)
            Circle().fill(Color.starClear)
                .frame(width: 5, height: 5)
                .shadow(color: Color.starClear.opacity(0.4), radius: 10)
                .offset(x: 12, y: 94)
        }
        .frame(width: 120, height: 120, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

// MARK: - 39–41 App notices

/// Screens that cover the whole app until handled.
/// TODO: Raise these from API responses (401, minimum version, maintenance window).
enum AppNotice: Identifiable {
    case loginExpired      // 39
    case updateRequired    // 40
    case maintenance(String) // 41, e.g. "11월 4일 02:00~04:00"
    case accountDeleted    // 113
    case rateLimited       // 120: the server's 429 rate_limited

    var id: String {
        switch self {
        case .loginExpired: "39"
        case .updateRequired: "40"
        case .maintenance: "41"
        case .accountDeleted: "113"
        case .rateLimited: "120"
        }
    }
}

struct AppNoticeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    var notice: AppNotice

    var body: some View {
        switch notice {
        case .loginExpired:
            StatusView(icon: .iconUser, title: "다시 로그인해 주세요",
                       message: "쓴 글은 그대로 남아 있어요.",
                       actions: [.init(title: "로그인", style: .primary) {
                           model.appNotice = nil
                           model.signOut()
                       }])
        case .updateRequired:
            StatusView(icon: .iconInfo, title: "새 버전이 필요해요",
                       message: "더 안전하게 쓰기 위해 업데이트가 필요해요.",
                       actions: [.init(title: "업데이트", style: .primary) {
                           // TODO: The real App Store link once the app is listed.
                           if let url = URL(string: "itms-apps://apps.apple.com") { openURL(url) }
                       }])
        case .maintenance(let window):
            StatusView(icon: .iconMoon, title: "잠시 점검 중이에요",
                       message: "\(window)\n기록은 안전하게 보관돼요.",
                       actions: [.init(title: "닫기", style: .ghost) { model.appNotice = nil }])
        case .accountDeleted:
            StatusView(icon: .iconMoon, title: "계정을 삭제했어요",
                       message: "그동안 띄운 별과 성운이 모두 사라졌어요.\n언제든 다시 첫 별을 띄울 수 있어요.",
                       actions: [.init(title: "처음 화면으로", style: .primary) { model.appNotice = nil }])
        case .rateLimited:
            // 120 / 120-1: with the server's retry_after, counts down in minutes (rounded up)
            // and keeps the button off until then. "다시 시도하기" returns to the screen underneath.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = model.retryAvailableAt.map { $0.timeIntervalSince(context.date) } ?? 0
                let minutes = Int((left / 60).rounded(.up))
                let base = "요청이 한꺼번에 몰렸어요. 쓰던 글은 그대로 있고 코인도 차감되지 않았어요."
                StatusView(icon: .iconMoon, title: "잠시 숨을 고르고 있어요",
                           message: left > 0 ? "\(base) \(minutes)분 뒤에 다시 시도할 수 있어요." : "\(base) 조금 뒤에 다시 시도해 주세요.",
                           actions: [.init(title: left > 0 ? "\(minutes)분 뒤에 다시 시도" : "다시 시도하기",
                                           style: .primary, disabled: left > 0) {
                               model.retryAvailableAt = nil
                               model.appNotice = nil
                           }])
            }
        }
    }
}

// MARK: - 122 Not found

/// 122 별을 찾을 수 없어요 / 122-1 리포트를 찾을 수 없어요: deleted, or tidied
/// away on another device.
struct NotFoundView: View {
    enum Kind { case star, report }
    var kind: Kind = .star
    /// 122 "밤하늘로 돌아가기" / 122-1 "리포트 목록으로"
    var onBack: () -> Void

    var body: some View {
        switch kind {
        case .star:
            StatusView(icon: .iconStar, title: "별을 찾을 수 없어요",
                       message: "이미 지웠거나 다른 기기에서 정리한 별이에요.",
                       actions: [.init(title: "밤하늘로 돌아가기", style: .primary, run: onBack)])
        case .report:
            StatusView(icon: .iconTelescope, title: "리포트를 찾을 수 없어요",
                       message: "이미 지웠거나 다른 기기에서 정리한 리포트예요.",
                       actions: [.init(title: "리포트 목록으로", style: .primary, run: onBack)])
        }
    }
}

// MARK: - 34 Leave while writing

/// 34 작성 중 나가기: asked when closing 05 with something written.
struct LeaveDraftSheet: View {
    var onSaveAndLeave: () -> Void
    var onKeepWriting: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule()
                .fill(Color.borderDefault)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("쓰던 글을 어떻게 할까요?")
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                Text("글은 사라지지 않게 임시로 저장해 둘 수 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Space.md) {
                Button("임시 저장하고 나가기", action: onSaveAndLeave).buttonStyle(.primary)
                Button("계속 쓰기", action: onKeepWriting).buttonStyle(.secondary)
                Button("버리기", action: onDiscard).buttonStyle(.danger)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }
}

// MARK: - 42 Toast card

/// Figma `Toast Card`: a title and an optional line, in the list-card style.
struct ToastCardMessage: Equatable {
    var title: String
    var detail: String?
}

struct ToastCard: View {
    var message: ToastCardMessage

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(message.title)
                .textStyle(.labelM)
                .foregroundStyle(Color.textPrimary)
            if let detail = message.detail {
                Text(detail)
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .itemCard(seed: "toast-\(message.title)", minHeight: 0)
        .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Shows a 42 toast card near the bottom for about two seconds.
    func toastCard(_ message: Binding<ToastCardMessage?>) -> some View {
        overlay(alignment: .bottom) {
            if let m = message.wrappedValue {
                ToastCard(message: m)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: m.title) {
                        UIAccessibility.post(notification: .announcement,
                                             argument: [m.title, m.detail].compactMap { $0 }.joined(separator: ", "))
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation(.easeInOut(duration: 0.3)) { message.wrappedValue = nil }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message.wrappedValue)
    }
}

#Preview("35") {
    StatusView(icon: .iconWifiOff, title: "연결이 잠시 끊겼어요",
               message: "쓰던 글은 이 기기에 안전하게 있어요.",
               actions: [.init(title: "다시 시도", style: .primary) {}])
}

#Preview("42") {
    VStack(spacing: 12) {
        ToastCard(message: .init(title: "별을 띄웠어요"))
        ToastCard(message: .init(title: "삭제되었어요", detail: "되돌릴 수 없어요"))
    }
    .padding(24)
    .background(Color.bgCanvas)
}

// MARK: - Empty state (96–98, 103, 108, 109, 119)

/// Figma empty states: a dim star glyph, a title, a short note, and an optional action.
struct EmptyStateView: View {
    enum ActionStyle { case primary, outline }
    var title: String
    var message: String
    var action: (title: String, style: ActionStyle, run: () -> Void)? = nil
    /// The violet floated glyph, or the grey kept one (119).
    var floatedGlyph = true

    var body: some View {
        VStack(spacing: Space.md) {
            // Figma empty states: the violet glyph, dimmed.
            StarGlyph(floated: floatedGlyph, spins: false)
                .scaleEffect(40 / 18.14)
                .frame(width: 40, height: 40)
                .opacity(0.55)
                .padding(.bottom, Space.sm)
                .accessibilityHidden(true)
            Text(title).textStyle(.h3).foregroundStyle(Color.textPrimary)
            Text(message).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Group {
                    switch action.style {
                    case .primary:
                        Button(action.title, action: action.run).buttonStyle(.primary)
                    case .outline:
                        Button(action.title, action: action.run).buttonStyle(.secondary)
                    }
                }
                .fixedSize()
                .padding(.top, Space.sm)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 114 Export in progress

/// 114 내보내는 중이에요: shown while the export file is made.
struct ExportProgressSheet: View {
    var detail: String
    var progress: Double
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("내보내는 중이에요").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text(detail).textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Space.sm) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.borderDefault.opacity(0.5))
                        Capsule().fill(Color.brandPrimary).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)
                Text("\(Int(progress * 100))% · \(progress >= 0.5 ? "거의 다 됐어요" : "모으는 중이에요")")
                    .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            Button("닫기", action: onClose).buttonStyle(.ghost)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }
}

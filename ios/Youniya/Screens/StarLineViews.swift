import SwiftUI

// MARK: - 74 별빛 한 줄 건네기

/// 74 별빛 한 줄 · 「제목」 (33:5748): one line (60 자) or a quick chip for a
/// shared star. 99 held back, 106 too long, 107 already left.
struct StarLineComposeView: View {
    @Environment(AppModel.self) private var model
    var star: PlazaNebula
    var onBack: () -> Void

    @State private var draft = DebugScreen.is("99") ? "그런 생각은 한심해요." : DebugScreen.is("106") ? String(repeating: "오늘의 별빛이 참 따뜻해서 오래 머물렀어요. ", count: 3) : ""
    /// 99 review: the held-back message over the composer.
    @State private var problem: String? = DebugScreen.is("99") ? "상처가 될 수 있는 말이 있어 건네지 못했어요" : nil
    @State private var sending = false
    @State private var toast: ToastCardMessage?
    @FocusState private var editing: Bool

    private var sent: String? { model.sentStarLines[star.name] ?? (star.lineLeft ? "" : nil) }
    private var over: Bool { draft.count > AppModel.lineLimit }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty && !over && !sending }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "별빛 한 줄 · 「\(star.starTitle ?? star.name)」", onBack: onBack)

            ScrollView {
                VStack(spacing: Space.lg) {
                    Text("한 사람이 한 별에 한 줄씩 건넬 수 있어요. 별 주인만 읽을 수 있어요.")
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                    if let sent, !sent.isEmpty {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("내가 건넨 한 줄").textStyle(.caption).foregroundStyle(Color.textTertiary)
                            Text(sent).textStyle(.bodyM).foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.lg)
                        .itemCard(seed: "my-line", minHeight: 0)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            VStack(alignment: .leading, spacing: Space.md) {
                if !star.receiveLines {
                    NoticeBanner(message: "이 별은 지금 별빛 한 줄을 받지 않아요")
                } else if sent != nil || DebugScreen.is("107") {
                    // 107
                    NoticeBanner(message: "이 별에는 이미 한 줄을 건넸어요")
                } else {
                    if let problem {
                        // 99
                        NoticeBanner(message: problem, tone: .warm).transition(.opacity)
                    } else if over {
                        // 106
                        NoticeBanner(message: "\(draft.count) / \(AppModel.lineLimit)자 · \(AppModel.lineLimit)자 안으로 줄여 주세요", tone: .warm)
                            .transition(.opacity)
                    } else {
                        HStack(spacing: Space.sm) {
                            ForEach(AppModel.lineChips, id: \.key) { c in
                                DotChip(title: c.label, isSelected: false) { send(chip: c.key) }
                            }
                        }
                    }
                    composer
                    Text("상처 주는 말은 별빛이 되지 못해요 · 보내기 전에 한 번 걸러요")
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.lg)
        }
        .background { StarField() }
        .toastCard($toast)
        .animation(.snappy, value: problem)
        .onChange(of: draft) { _, _ in if problem != nil { problem = nil } }
    }

    private var composer: some View {
        HStack(spacing: Space.sm) {
            TextField("", text: $draft, prompt: Text("한 줄을 남겨 보세요 (\(AppModel.lineLimit)자)").foregroundStyle(Color.textTertiary),
                      axis: .vertical)
                .textStyle(.bodyM)
                .foregroundStyle(Color.textPrimary)
                .focused($editing)
                .lineLimit(1...3)
            Button { send(chip: nil) } label: {
                Image(systemName: "arrow.up")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(canSend ? Color.brandPrimary : Color.textTertiary.opacity(0.4), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("건네기")
        }
        .padding(.leading, Space.lg)
        .padding(.trailing, Space.sm)
        .padding(.vertical, Space.sm)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderFocus.opacity(0.6), lineWidth: 1))
    }

    private func send(chip: String?) {
        sending = true
        editing = false
        Task { @MainActor in
            let r = await model.sendStarLine(to: star, text: chip == nil ? draft.trimmingCharacters(in: .whitespaces) : nil, chip: chip)
            sending = false
            switch r {
            case .sent:
                draft = ""
                toast = ToastCardMessage(title: "별빛 한 줄을 건넸어요", detail: "별 주인만 읽을 수 있어요")
            case .rejected(let why): problem = why
            case .already: problem = nil; toast = ToastCardMessage(title: "이 별에는 이미 한 줄을 건넸어요")
            case .closed: toast = ToastCardMessage(title: "이 별은 지금 별빛 한 줄을 받지 않아요")
            }
        }
    }
}

// MARK: - 12-4 받은 별빛 한 줄

/// 12-4 받은 별빛 한 줄 · 「제목」: the lines left on my star. Each can be
/// deleted or reported (100), with its keeper blocked too; reported ones hide
/// at once (101).
struct ReceivedLinesView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onBack: () -> Void

    @State private var lines: [ReceivedLine]?
    @State private var reporting: ReceivedLine?
    @State private var reportHeight: CGFloat = 520
    @State private var toast: ToastCardMessage?

    private var star: StarItem? { model.stars.first { $0.id == starID } }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "받은 별빛 한 줄 · 「\(star?.title ?? "")」", onBack: onBack)
            ScrollView {
                VStack(spacing: Space.md) {
                    Text("이 별에 건네진 한 줄이에요. 나만 읽을 수 있고, 지우거나 신고할 수 있어요.")
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                    if let lines {
                        if lines.isEmpty {
                            Text("아직 받은 한 줄이 없어요.").textStyle(.bodyM).foregroundStyle(Color.textTertiary)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        }
                        ForEach(lines) { line in card(line) }
                    } else {
                        ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .toastCard($toast)
        .task { lines = await model.receivedLines(starID) }
        // 100 이 별빛을 신고할까요?
        .sheet(item: $reporting) { line in
            LineReportSheet(onReport: { reason, block in
                reporting = nil
                Task { @MainActor in
                    if await model.reportLine(line, on: starID, reason: reason, block: block) {
                        withAnimation { lines?.removeAll { $0.id == line.id } }
                        // 101
                        toast = ToastCardMessage(title: "신고했어요", detail: block ? "그 별지기도 차단했어요" : "바로 가려졌어요")
                    }
                }
            }, onCancel: { reporting = nil })
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { reportHeight = $0 }
            .presentationDetents([.height(reportHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "line-report") }
        }
        .onAppear { if DebugScreen.is("100") { Task { try? await Task.sleep(for: .seconds(0.8)); reporting = lines?.first } } }
    }

    private func card(_ line: ReceivedLine) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("\(line.nickname ?? "별지기") · \(PlazaStarRow.when(line.createdAt))")
                .textStyle(.caption).foregroundStyle(Color.textTertiary)
            Text(line.text).textStyle(.bodyM).foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .itemCard(seed: "line-\(line.id)", minHeight: 0)
        .contextMenu {
            Button("지우기", systemImage: "trash", role: .destructive) {
                Task { @MainActor in
                    if await model.deleteLine(line, on: starID) { withAnimation { lines?.removeAll { $0.id == line.id } } }
                }
            }
            Button("신고하기", systemImage: "flag") { reporting = line }
        }
        .accessibilityAction(named: "지우기") { Task { _ = await model.deleteLine(line, on: starID) } }
        .accessibilityAction(named: "신고하기") { reporting = line }
    }
}

/// 100 이 별빛을 신고할까요?: one reason, and 「이 별지기도 차단하기」.
struct LineReportSheet: View {
    var onReport: (_ reason: String, _ block: Bool) -> Void
    var onCancel: () -> Void

    private static let reasons = [("hurtful", "상처를 주는 말이에요"), ("personal_info", "개인정보가 드러나 있어요"),
                                  ("spam", "광고나 스팸이에요"), ("other", "그 밖의 이유가 있어요")]
    @State private var reason = "hurtful"
    @State private var block = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("이 별빛을 신고할까요?").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("신고한 별빛은 바로 가려지고 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.")
                    .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Space.md) {
                ForEach(Self.reasons, id: \.0) { r in check(r.1, on: reason == r.0) { reason = r.0 } }
                check("이 별지기도 차단하기", on: block) { block.toggle() }
                    .padding(.top, Space.sm)
            }
            VStack(spacing: Space.md) {
                Button("신고하기") { onReport(reason, block) }.buttonStyle(.primary)
                Button("취소", action: onCancel).buttonStyle(.secondary)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }

    private func check(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(on ? Color.brandPrimary : .clear)
                    RoundedRectangle(cornerRadius: 5).strokeBorder(on ? Color.brandPrimary : Color.borderDefault, lineWidth: 1.2)
                    if on { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white) }
                }
                .frame(width: 20, height: 20)
                Text(title).textStyle(.bodyM).foregroundStyle(Color.textPrimary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

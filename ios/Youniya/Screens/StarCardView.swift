import SwiftUI

/// 07-1 오늘의 별 카드 · 별빛 풀이 (442:14104): the card, the 별빛 풀이 (open
/// here), then 「나의 별자리 보기」.
/// 17.4: the blocks appear top to bottom, 0.2 s apart (0.5 s each), and the
/// breakdown's rows follow 0.18 s apart; at once with reduced motion.
struct StarCardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionReduced) private var reduceMotion
    var star: StarItem
    var title: String = "별이 떠올랐어요"
    var onClose: () -> Void
    var onShowNebula: () -> Void

    @State private var showBreakdown = true

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                FlowTopBar(title: title, onClose: onClose)

                if let analysis = star.analysis {
                    TodayStarCard(analysis: analysis)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { showBreakdown.toggle() } }
                        .appear(true, delay: 0, reduceMotion: reduceMotion)
                    if showBreakdown {
                        StarlightBreakdown(analysis: analysis)
                            .appear(true, delay: 0.2, reduceMotion: reduceMotion)
                            .transition(.opacity)
                    }
                    BreakdownToggle(isOpen: $showBreakdown)
                        .appear(true, delay: 0.4, reduceMotion: reduceMotion)
                }

                Button("나의 별자리 보기", action: onShowNebula)
                    .buttonStyle(.primary)
                    .appear(true, delay: 0.6, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .background { StarField() }
    }
}

/// One full-screen writing flow. A back swipe closes it (except while analysing).
/// - New star: 05 → 06 → 07 (or 13 when kept)
/// - Rewrite:  14 → 06 → 16 (or 13 when kept)
struct ComposeFlowView: View {
    @Environment(AppModel.self) private var model
    /// Set for "이 주제로 다시 쓰기" (14 Rewrite).
    var rewriteOf: StarItem? = nil
    var onClose: () -> Void
    var onShowNebula: () -> Void
    /// "이 별 보기" on 13 → 12 Star Detail.
    var onOpenStar: (StarItem) -> Void
    /// 29 "코인 충전" → 28.
    var onCharge: () -> Void = {}
    /// 12 "별 띄우기" on a kept star: skip writing, float it, then 06/07.
    var floatingKept: StarItem? = nil
    /// 05-2 고쳐 쓰기: a new star from this one's text, joined to it (05-5).
    var revising: StarItem? = nil

    /// 05-5 고쳐 쓴 글을 새 별로 띄울까요?
    @State private var confirmRevise: StarDraft?
    @State private var reviseHeight: CGFloat = 380
    @State private var revisePublished = false

    /// 05-3 / 05-4 별빛을 받아 띄울까요?: what starlight does (the text locks) and
    /// what it costs, before 06.
    @State private var confirmFloat: (() -> Void)?
    @State private var confirmHeight: CGFloat = 330
    /// 29-1 from 05: today's free starlight is used and coins are short.
    @State private var showShortage = false
    @State private var shortageKeep: (() -> Void)?
    @State private var shortageHeight: CGFloat = 330

    private enum Step: Equatable {
        case writing
        case analyzing(StarItem)
        case card(StarItem)
        case compare(previous: StarItem, current: StarItem)
        case kept(StarItem)
        /// 37 Crisis Care, then the step that would have come next.
        case crisis(StarItem, floated: Bool)
        /// 61–64 별 탄생, between 06 and the card.
        case birth(StarItem)
        /// 35 (network) or 36 (analysis) after 06 could not finish.
        case failed(StarItem, SimulatedFailure)
        /// Live 35: the star never reached the server; it can be sent again.
        case sendFailed(StarDraft, floated: Bool)
        /// Live: the server is reading a floated star (6–12 s with the real model);
        /// 06 plays meanwhile, then again with the real values.
        case reading
    }

    /// Live: waiting for the server to save (and analyse) the star.
    @State private var sending = false

    /// 06-1 그만두기: the request being read, the star when it is known (12 별빛
    /// 받기 on a kept star), and whether the stop went through.
    @State private var readingTask: Task<Void, Never>?
    @State private var readingStarID: StarItem.ID?
    /// Names this 별빛 받기 for `POST /v1/starlight/attempts/{id}/cancel`.
    @State private var attemptID: String?
    @State private var stopping = false
    @State private var stopped = false
    /// The stopped star's page is open (06-2).
    @State private var stopShown = false
    /// 06-1: set the moment 그만두기 is pressed; true once the server stopped it.
    /// The reading's own answer waits on it, so a late success can't show 61.
    @State private var stopTask: Task<Bool, Never>?

    @State private var toast: ToastCardMessage?

    @State private var step: Step = .writing

    var body: some View {
        ZStack {
            switch step {
            case .writing:
                if let kept = floatingKept {
                    // 12-10: the sheet sits over the star's own page (12-1).
                    StarDetailView(starID: kept.id, onBack: onClose, onRewrite: {}, onReviewShare: {})
                        .allowsHitTesting(false)
                } else if let original = revising {
                    StarMakingView(onClose: onClose, onPublish: { _, _ in }, revising: original,
                                   onRevise: { confirmRevise = $0 }, revisePublished: revisePublished)
                        .transition(.opacity)
                } else if let previous = rewriteOf {
                    RewriteView(previous: previous, question: previous.analysis?.rewriteQuestion, onBack: onClose) { body, floated in
                        let publish = { (floated: Bool) in
                            if model.useLiveAPI {
                                send(StarDraft(mood: previous.mood, title: previous.title, body: body), floated: floated)
                            } else {
                                let star = model.publishRewrite(of: previous, body: body, floated: floated)
                                advance(after: star, floated: floated)
                            }
                        }
                        if floated { float { publish(true) } keep: { publishUnlit { publish(false) } } } else { publishUnlit { publish(false) } }
                    }
                    .transition(.opacity)
                } else {
                    StarMakingView(onClose: onClose) { draft, floated in
                        let publish = { (floated: Bool) in
                            if model.useLiveAPI {
                                send(draft, floated: floated)
                            } else {
                                advance(after: model.publish(draft, floated: floated), floated: floated)
                            }
                        }
                        if floated { float { publish(true) } keep: { publishUnlit { publish(false) } } } else { publishUnlit { publish(false) } }
                    }
                    .transition(.opacity)
                }
            case .analyzing(let star):
                PrismAnalysisView(analysis: star.analysis!) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        // Mock only: the dev switch stands in for a failed request.
                        if !model.useLiveAPI, let failure = model.simulatedFailure, failure != .payment {
                            step = .failed(star, failure)
                        } else {
                            step = .birth(star)
                        }
                    }
                }
                .transition(.opacity)
            case .birth(let star):
                StarBirthView(shape: star.analysis?.shape, color: star.mood.color, unlit: !star.isFloated) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        // 별빛 없이 띄운 별: its page (12-1), where starlight can come later.
                        if !star.isFloated {
                            onOpenStar(star)
                        } else {
                            step = .card(star)
                        }
                    }
                }
                .transition(.opacity)
            case .card(let star):
                StarCardView(star: star, onClose: onClose, onShowNebula: onShowNebula)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .compare(let previous, let current):
                RematchCompareView(previous: previous, current: current, onBack: onClose, onShowNebula: onShowNebula)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .kept(let star):
                // 별빛 없이 띄우기 (17.1): the star is born, then its page.
                Color.clear.background { StarField() }
                    .onAppear { withAnimation(.easeInOut(duration: 0.4)) { step = .birth(star) } }
            case .crisis(let star, let floated):
                CrisisCareView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        step = floated ? .analyzing(star) : .kept(star)
                    }
                }
                .transition(.opacity)
            case .reading:
                PrismAnalysisView(analysis: .reading, onFinish: {},
                                  onStop: model.useLiveAPI || DebugScreen.is("6-1") ? stopReading : nil,
                                  stopping: stopping)
                    .transition(.opacity)
            case .sendFailed(let draft, let floated):
                StatusView(icon: .iconWifiOff, title: "연결이 잠시 끊겼어요",
                           message: "쓰던 글은 이 기기에 안전하게 있어요.",
                           actions: [.init(title: "다시 시도", style: .primary) { send(draft, floated: floated) }])
                    .transition(.opacity)
            case .failed(let star, .network):
                StatusView(icon: .iconWifiOff, title: "연결이 잠시 끊겼어요",
                           message: "쓰던 글은 이 기기에 안전하게 있어요.",
                           actions: [.init(title: "다시 시도", style: .primary) { retry(star) }])
                    .transition(.opacity)
            case .failed(let star, _):
                StatusView(icon: .iconWarning, title: "별을 읽지 못했어요",
                           message: "글은 그대로 보관되고, 코인도 차감되지 않았어요.",
                           actions: [
                               .init(title: "다시 시도", style: .primary) { retry(star) },
                               .init(title: "별빛 없이 띄우기", style: .secondary) { keepInstead(star) },
                           ])
                    .transition(.opacity)
            }
        }
        .overlay {
            if sending && step != .reading {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView().tint(.white).controlSize(.large)
                }
                .transition(.opacity)
                .accessibilityLabel("별을 띄우는 중이에요")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sending)
        #if DEBUG
        // `-debugScreen 06|07|13|16|35|36|37|61|62`
        .onAppear {
            guard let star = DebugScreen.floatedStar(model) else { return }
            if DebugScreen.is("6") { step = .analyzing(star) }
            if DebugScreen.is("6-1") { step = .reading }
            if DebugScreen.is("7", "7-1") { step = .card(star) }
            if DebugScreen.is("13"), let kept = DebugScreen.keptStar(model) { step = .kept(kept) }
            if DebugScreen.is("16"), let previous = rewriteOf { step = .compare(previous: previous, current: star) }
            if DebugScreen.is("35") { step = .failed(star, .network) }
            if DebugScreen.is("36") { step = .failed(star, .analysis) }
            if DebugScreen.is("37") { step = .crisis(star, floated: true) }
            if DebugScreen.is("61", "62", "63", "64") { step = .birth(star) }
        }
        #endif
        .toastCard($toast)
        .onAppear {
            if DebugScreen.is("5-3", "5-4") { confirmFloat = {} }
            if DebugScreen.is("5-5"), let original = revising {
                confirmRevise = StarDraft(mood: original.mood, title: original.title, body: original.body)
            }
            if let kept = floatingKept, step == .writing {
                float { floatKept(kept) } keep: { onClose() }
            }
        }
        // 05-3 / 05-4 별빛을 받아 띄울까요?
        .sheet(isPresented: Binding(get: { confirmFloat != nil }, set: { if !$0 { confirmFloat = nil } }),
               onDismiss: { if floatingKept != nil && step == .writing { onClose() } }) {
            ActionSheetContent(
                // 05-3 / 05-4, or 12-10 (505:13915) for a star without starlight.
                title: floatingKept != nil ? "이 별에 별빛을 받을까요?" : "별빛을 받아 띄울까요?",
                message: floatingKept != nil
                    ? "별빛 프리즘이 글을 읽고 별빛·깊이·고유한 별 모양과 별빛 풀이를 줘요. \(floatCostLine)\n별빛을 받으면 이 글은 잠겨서 고칠 수 없어요. 고치고 싶은 곳이 있으면 먼저 고친 뒤 받아 주세요."
                    : "별빛 프리즘이 글을 읽고 별빛·깊이·고유한 별 모양을 줘요. \(floatCostLine)\n별빛을 받으면 이 글은 잠겨서 고칠 수 없어요. 고치고 싶으면 '고쳐 쓰기'로 새 별을 만들 수 있어요.",
                primary: (floatPrimaryTitle, {
                    let go = confirmFloat
                    confirmFloat = nil
                    go?()
                }),
                secondary: (floatingKept != nil ? "다음에" : "조금 더 쓸게요", { confirmFloat = nil }),
                ghost: nil,
                secondaryIsGhost: true
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { confirmHeight = $0 }
            .presentationDetents([.height(confirmHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "float-confirm") }
        }
        // 05-5 고쳐 쓴 글을 새 별로 띄울까요?
        .sheet(isPresented: Binding(get: { confirmRevise != nil }, set: { if !$0 { confirmRevise = nil } })) {
            if let original = revising, let draft = confirmRevise {
                ActionSheetContent(
                    title: "고쳐 쓴 글을 새 별로 띄울까요?",
                    message: "「\(original.title)」를 고쳐 쓴 글이에요. 원래 별과 별빛은 그대로 남고, 새 별이 하나 더 생겨 원래 별과 이어져요.\n"
                        + (model.isFloatFree ? "별빛을 받으면 오늘 무료 1번을 써요." : "별빛을 받으면 코인 \(AppModel.floatCost)개를 써요(지금 \(model.coins)개).")
                        + " 별빛 없이 띄우면 무료예요(오늘 \(max(0, AppModel.unlitDailyLimit - model.unlitToday))번 남음).",
                    primary: ("별빛 받고 새 별로 띄우기", {
                        confirmRevise = nil
                        guard draft.body.count >= AppModel.minFloatLength else {
                            toast = ToastCardMessage(title: "\(AppModel.minFloatLength)자부터 별빛을 받을 수 있어요",
                                                     detail: "별빛 없이 새 별로 띄울 수 있어요")
                            return
                        }
                        if model.floatNeedsCharge {
                            shortageKeep = { publishRevision(of: original, draft, floated: false) }
                            showShortage = true
                            return
                        }
                        if !model.useLiveAPI && !model.isFloatFree {
                            _ = model.spendCoins(AppModel.floatCost, for: "별빛 받기")
                        }
                        publishRevision(of: original, draft, floated: true)
                    }),
                    secondary: ("별빛 없이 새 별로 띄우기", {
                        confirmRevise = nil
                        publishUnlit { publishRevision(of: original, draft, floated: false) }
                    }),
                    ghost: ("조금 더 고칠게요", { confirmRevise = nil })
                )
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { reviseHeight = $0 }
                .presentationDetents([.height(reviseHeight)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.xl)
                .presentationBackground { SheetBackground(seed: "revise-confirm") }
            }
        }
        // 29-1 별빛 받기 · 코인 부족 (from 05, and 12-1)
        .sheet(isPresented: $showShortage) {
            ActionSheetContent(
                title: "코인이 조금 부족해요",
                message: "오늘 무료 별빛 받기는 이미 썼어요. 별빛을 받으려면 코인 \(AppModel.floatCost)개가 필요해요. 지금 코인 \(model.coins)개예요."
                    + (floatingKept == nil ? " 별빛 없이 띄우는 건 무료예요." : ""),
                primary: ("코인 충전", { showShortage = false; onCharge() }),
                secondary: (floatingKept == nil ? "별빛 없이 띄우기" : "다음에 받을게요", { showShortage = false; shortageKeep?() }),
                ghost: floatingKept == nil ? ("계속 쓰기", { showShortage = false }) : nil
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shortageHeight = $0 }
            .presentationDetents([.height(shortageHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "float-shortage") }
        }
        .edgeSwipeBack(enabled: !isAnalyzing && !sending && step != .reading, onBack: onClose)
    }

    /// Live: saves the star on the server and follows its answer.
    /// - crisis → 37, then 13 (the server keeps it unscored)
    /// - floated → 06 with the server's analysis
    /// - asked to float but kept → the analysis failed (36)
    /// - not reached → 35, which can send again
    private func send(_ draft: StarDraft, floated: Bool, rewriteOf link: StarItem.ID? = nil, onSaved: @escaping () -> Void = {}) {
        guard !sending else { return }
        // 05-2: every try (35 「다시 시도」, 29-1 「별빛 없이」) keeps the link.
        let link = link ?? revising?.id
        sending = true
        // Floating waits on the model: show 06 instead of a spinner over the editor.
        let attempt = floated ? Self.newAttempt() : nil
        if floated { beginReading(starID: nil, attempt: attempt) }
        readingTask = Task { @MainActor in
            defer { sending = false }
            var outcome: Result<(StarItem, crisis: Bool), Error>
            do {
                // 05-2 sends rewrite_of; 14 별 잇기 · 새 별 쓰기 sends link_to.
                outcome = .success(try await model.publishLive(draft, floated: floated, rewriteOf: link,
                                                               linkTo: rewriteOf.map { [$0.id] } ?? [],
                                                               attemptID: attempt))
            } catch {
                outcome = .failure(error)
            }
            // 06-1: 그만두기 was pressed; its answer decides, not this one.
            if await stopDecided() {
                await finishStopped(starID: (try? outcome.get())?.0.id.apiID ?? outcome.stopStarID)
                return
            }
            do {
                let (star, crisis) = try outcome.get()
                onSaved()
                // The server may have charged 5 coins and used today's free float.
                if floated { Task { await model.loadCoins() } }
                withAnimation(.easeInOut(duration: 0.5)) {
                    if crisis {
                        step = .crisis(star, floated: false)
                    } else if star.isFloated, star.analysis != nil {
                        step = .analyzing(star)
                    } else if floated {
                        step = .failed(star, .analysis)
                    } else {
                        step = .kept(star)
                    }
                }
            } catch let e as APIError where e.code == "offline" {
                // Timed out or cut off: the server can't tell, so stop it (nothing is used).
                if let attempt { Task { _ = await model.stopStarlight(attemptID: attempt) } }
                withAnimation(.easeInOut(duration: 0.5)) { step = .sendFailed(draft, floated: floated) }
            } catch let e as APIError where e.code == "unlit_daily_limit" {
                if step == .reading { withAnimation { step = .writing } }
                toast = ToastCardMessage(title: "별빛 없이 띄우기는 하루 \(AppModel.unlitDailyLimit)개까지예요",
                                         detail: "내일 다시 띄울 수 있어요")
            } catch let e as APIError where e.status == 402 {
                // 29-1: the server wants coins for a second starlight today.
                if step == .reading { withAnimation { step = .writing } }
                shortageKeep = { send(draft, floated: false) }
                showShortage = true
                await model.loadCoins()
            } catch let e as APIError where e.status == 422 {
                if step == .reading { withAnimation { step = .writing } }
                toast = ToastCardMessage(title: e.message)
            } catch {
                if step == .reading { withAnimation { step = .writing } }
                model.handle(error)
            }
            // Back in the editor: leaving should keep the rewrite again.
            if step == .writing { revisePublished = false }
        }
    }

    /// 05 별빛 받고 띄우기: free once a day, then 5 coins. Short of coins → 29-1,
    /// with 충전 · 별빛 없이 띄우기 · 계속 쓰기 side by side. Live, the server charges.
    private func float(_ go: @escaping () -> Void, keep: @escaping () -> Void) {
        if model.floatNeedsCharge {
            shortageKeep = keep
            showShortage = true
            return
        }
        // 05-3 / 05-4 first; the star is floated only on 「별 띄우기」.
        confirmFloat = {
            if !model.useLiveAPI && !model.isFloatFree {
                _ = model.spendCoins(AppModel.floatCost, for: "별빛 받기")
            }
            go()
        }
    }

    /// Today's free starlight left (members: today's member uses).
    private var freeLeft: Int {
        model.memberHasStar
            ? (model.memberLeftToday.stars ?? max(1, AppModel.memberDailyLimit - model.floatedToday))
            : 1
    }

    /// 05-3: "오늘 무료 1번 남았어요." 05-4: the coins it takes.
    private var floatCostLine: String {
        if model.isFloatFree { return "오늘 무료 \(freeLeft)번 남았어요." }
        return "오늘 무료를 다 썼어요. 코인 \(AppModel.floatCost)개가 사용돼요(지금 \(model.coins)개)."
    }

    /// 05-3 「별빛 받고 띄우기 · 오늘 무료 1번」 / 05-4 「… · 5코인」 (12-1: 「별빛 받기 · …」).
    private var floatPrimaryTitle: String {
        let action = floatingKept != nil ? "별빛 받기" : "별빛 받고 띄우기"
        return model.isFloatFree ? "\(action) · 오늘 무료 \(freeLeft)번" : "\(action) · \(AppModel.floatCost)코인"
    }

    /// 12 "별 띄우기" on a kept star: `POST /v1/stars/{id}/float` (mock: on device).
    private func floatKept(_ kept: StarItem) {
        guard model.useLiveAPI else {
            if let s = model.floatKeptMock(kept.id) { advance(after: s, floated: true) }
            return
        }
        let attempt = Self.newAttempt()
        beginReading(starID: kept.id, attempt: attempt)
        readingTask = Task { @MainActor in
            var outcome: Result<StarItem, Error>
            do {
                outcome = .success(try await model.floatAgain(kept.id, attemptID: attempt))
            } catch {
                outcome = .failure(error)
            }
            if await stopDecided() {
                await finishStopped(starID: kept.id.apiID)
                return
            }
            do {
                let s = try outcome.get()
                Task { await model.loadCoins() }
                withAnimation(.easeInOut(duration: 0.5)) {
                    // A crisis signal: the server keeps it unscored (37, then 13).
                    step = s.isFloated && s.analysis != nil ? .analyzing(s) : .crisis(s, floated: false)
                }
            } catch let e as APIError where e.code == "offline" {
                Task { _ = await model.stopStarlight(attemptID: attempt) }
                model.handle(e)
                onClose()
            } catch let e as APIError where e.status == 402 {
                await model.loadCoins()
                shortageKeep = { onClose() }
                showShortage = true
            } catch let e as APIError where ["too_short", "already_floated", "already_lit"].contains(e.code) {
                model.apiMessage = e.message
                onClose()
            } catch {
                model.handle(error)
                onClose()
            }
        }
    }

    /// 06 while the server reads; 06-1 can stop it.
    private func beginReading(starID: StarItem.ID?, attempt: String?) {
        readingStarID = starID
        attemptID = attempt
        stopping = false
        stopped = false
        stopShown = false
        stopTask = nil
        withAnimation(.easeInOut(duration: 0.5)) { step = .reading }
    }

    /// A fresh attempt id for each 별빛 받기 (the server refuses one used twice).
    private static func newAttempt() -> String { UUID().uuidString.lowercased() }

    /// 06-1 그만두기 → 06-2: the server keeps the star without starlight and
    /// gives back what it used; its page (12-1) opens with a toast. When the
    /// stop got there first, the star comes with the request's 409.
    private func stopReading() {
        guard !stopping else { return }
        stopping = true
        #if DEBUG
        if DebugScreen.is("6-1"), let star = DebugScreen.keptStar(model) {
            stopped = true
            showStopped(star)
            return
        }
        #endif
        guard let attemptID else { stopping = false; return }
        stopTask = Task { @MainActor () -> Bool in
            let r = await model.stopStarlight(attemptID: attemptID)
            guard r.stopped else {
                // e.g. cancel_too_late: the reading's own answer stands.
                stopping = false
                toast = ToastCardMessage(title: "그만두지 못했어요", detail: "조금만 더 기다려 주세요")
                return false
            }
            stopped = true
            Task { await model.loadCoins() }
            if let star = r.star ?? readingStarID.flatMap({ id in model.stars.first { $0.id == id } }) {
                showStopped(star)
            }
            // Otherwise the request's answer (409 starlight_cancelled) names the star.
            return true
        }
    }

    /// Whether 그만두기 went through; waits for its answer if it is on its way.
    private func stopDecided() async -> Bool {
        guard let stopTask else { return false }
        return await stopTask.value
    }

    /// After a stop: the star kept without starlight (fetched fresh), or back
    /// out when the request never saved one.
    private func finishStopped(starID: String?) async {
        guard !stopShown else { return }
        if let starID, let kept = await model.starAfterStop(starID) {
            showStopped(kept)
        } else {
            onClose()
        }
    }

    private func showStopped(_ star: StarItem) {
        guard !stopShown else { return }
        stopShown = true
        model.apiMessage = "별빛 받기를 그만뒀어요. 무료와 코인은 그대로예요."
        onOpenStar(star)
    }

    private func advance(after star: StarItem, floated: Bool) {
        withAnimation(.easeInOut(duration: 0.5)) {
            if CrisisSignal.detected(in: star.title + " " + star.body) {
                step = .crisis(star, floated: floated)
            } else {
                step = floated ? .analyzing(star) : .kept(star)
            }
        }
    }

    /// 35/36 "다시 시도": analyze again, or say the connection is still down.
    private func retry(_ star: StarItem) {
        if model.useLiveAPI {
            Task { @MainActor in
                do {
                    let floated = try await model.floatAgain(star.id)
                    withAnimation(.easeInOut(duration: 0.5)) { step = .analyzing(floated) }
                } catch let e as APIError where e.code == "offline" {
                    toast = ToastCardMessage(title: "연결을 확인해 주세요")
                } catch let e as APIError where e.code == "analysis_failed" {
                    toast = ToastCardMessage(title: e.message)
                } catch {
                    model.handle(error)
                }
            }
        } else if model.simulatedFailure == .network {
            toast = ToastCardMessage(title: "연결을 확인해 주세요")
        } else {
            withAnimation(.easeInOut(duration: 0.5)) { step = .analyzing(star) }
        }
    }

    /// 36 「별빛 없이 띄우기」: the star stays without starlight, then its page.
    private func keepInstead(_ star: StarItem) {
        guard let kept = model.keepInstead(star.id) else { return }
        withAnimation(.easeInOut(duration: 0.5)) { step = .kept(kept) }
    }

    /// 05-5: the rewrite goes out as a new star, joined to the original
    /// (live: `rewrite_of`, which the server links both ways).
    private func publishRevision(of original: StarItem, _ draft: StarDraft, floated: Bool) {
        revisePublished = true
        if model.useLiveAPI {
            send(draft, floated: floated, rewriteOf: original.id) {
                model.reviseDrafts[original.id] = nil
            }
        } else {
            advance(after: model.publishRevision(of: original, draft: draft, floated: floated), floated: floated)
        }
    }

    /// 17.1: 별빛 없이 띄우기 is free, up to ten a day (mock count; live, the
    /// server answers 429 unlit_daily_limit).
    private func publishUnlit(_ go: () -> Void) {
        if !model.useLiveAPI && model.unlitToday >= AppModel.unlitDailyLimit {
            toast = ToastCardMessage(title: "별빛 없이 띄우기는 하루 \(AppModel.unlitDailyLimit)개까지예요",
                                     detail: "내일 다시 띄울 수 있어요")
            return
        }
        go()
    }

    private var isAnalyzing: Bool {
        if case .analyzing = step { true } else { false }
    }
}

private extension Result where Failure == Error {
    /// 409 starlight_cancelled: the star the stopped request saved.
    var stopStarID: String? {
        if case .failure(let e) = self { return (e as? APIError)?.starID }
        return nil
    }
}

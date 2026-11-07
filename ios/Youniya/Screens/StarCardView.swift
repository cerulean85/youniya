import SwiftUI

/// 07 Today Star Card: the result after floating a star.
struct StarCardView: View {
    @Environment(AppModel.self) private var model
    var star: StarItem
    var title: String = "별이 떠올랐어요"
    var onClose: () -> Void
    var onShowNebula: () -> Void
    var onTelescope: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                FlowTopBar(title: title, onClose: onClose)

                if let analysis = star.analysis {
                    TodayStarCard(analysis: analysis)
                    telescopeTeaser(analysis)
                }

                Button("나의 성운 보기", action: onShowNebula)
                    .buttonStyle(.primary)
                Button("마음 망원경 켜기", action: onTelescope)
                    .buttonStyle(.ghost)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .background { StarField() }
    }

    /// Figma `Telescope Teaser`
    private func telescopeTeaser(_ analysis: StarAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top) {
                Text("마음 망원경")
                    .textStyle(.labelS)
                    .foregroundStyle(Color.brandPrimaryText)
                Spacer()
                // Only while a free telescope is left (first one, or this month's).
                if model.isTelescopeFree {
                    Text("이번 달 1회 무료")
                        .textStyle(.caption)
                        .foregroundStyle(Color.starBright)
                }
            }
            Text(analysis.telescopeTeaser)
                .textStyle(.observation)
                .foregroundStyle(Color.textPrimary)
            Text("숨은 마음의 결을 더 들여다볼 수 있어요.")
                .textStyle(.bodyS)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .cosmos("teaser", in: RoundedRectangle(cornerRadius: Radius.lg))
        .background(Color.bgSurfaceRaised, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
        .accessibilityElement(children: .combine)
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
    var onTelescope: (StarItem) -> Void
    /// "이 별 보기" on 13 → 12 Star Detail.
    var onOpenStar: (StarItem) -> Void
    /// 29 "코인 충전" → 28.
    var onCharge: () -> Void = {}

    /// 29 from 05: today's free float is used and coins are short.
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

    @State private var toast: ToastCardMessage?

    @State private var step: Step = .writing

    var body: some View {
        ZStack {
            switch step {
            case .writing:
                if let previous = rewriteOf {
                    RewriteView(previous: previous, question: model.rewriteQuestion(for: previous), onBack: onClose) { body, floated in
                        let publish = { (floated: Bool) in
                            if model.useLiveAPI {
                                send(StarDraft(mood: previous.mood, title: previous.title, body: body), floated: floated)
                            } else {
                                let star = model.publishRewrite(of: previous, body: body, floated: floated)
                                advance(after: star, floated: floated)
                            }
                        }
                        if floated { float { publish(true) } keep: { publish(false) } } else { publish(false) }
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
                        if floated { float { publish(true) } keep: { publish(false) } } else { publish(false) }
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
                StarBirthView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        if let previous = rewriteOf {
                            step = .compare(previous: previous, current: star)
                        } else {
                            step = .card(star)
                        }
                    }
                }
                .transition(.opacity)
            case .card(let star):
                StarCardView(star: star, onClose: onClose, onShowNebula: onShowNebula, onTelescope: { onTelescope(star) })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .compare(let previous, let current):
                RematchCompareView(previous: previous, current: current, onBack: onClose, onShowNebula: onShowNebula)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .kept(let star):
                KeptCompleteView(onHome: onClose, onOpenStar: { onOpenStar(star) })
                    .transition(.opacity)
            case .crisis(let star, let floated):
                CrisisCareView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        step = floated ? .analyzing(star) : .kept(star)
                    }
                }
                .transition(.opacity)
            case .reading:
                PrismAnalysisView(analysis: .reading) {}
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
                               .init(title: "조용히 간직하기", style: .secondary) { keepInstead(star) },
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
            if DebugScreen.is("7") { step = .card(star) }
            if DebugScreen.is("13"), let kept = DebugScreen.keptStar(model) { step = .kept(kept) }
            if DebugScreen.is("16"), let previous = rewriteOf { step = .compare(previous: previous, current: star) }
            if DebugScreen.is("35") { step = .failed(star, .network) }
            if DebugScreen.is("36") { step = .failed(star, .analysis) }
            if DebugScreen.is("37") { step = .crisis(star, floated: true) }
            if DebugScreen.is("61", "62") { step = .birth(star) }
        }
        #endif
        .toastCard($toast)
        // 29 코인 부족 (from 05)
        .sheet(isPresented: $showShortage) {
            ActionSheetContent(
                title: "코인이 조금 부족해요",
                message: "오늘의 무료 별 띄우기는 이미 썼어요. 다음 별은 코인 \(AppModel.floatCost)개가 필요해요. 지금 코인 \(model.coins)개예요.",
                primary: ("코인 충전", { showShortage = false; onCharge() }),
                secondary: ("조용히 간직하기", { showShortage = false; shortageKeep?() }),
                ghost: ("계속 쓰기", { showShortage = false })
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
    private func send(_ draft: StarDraft, floated: Bool) {
        guard !sending else { return }
        sending = true
        // Floating waits on the model: show 06 instead of a spinner over the editor.
        if floated { withAnimation(.easeInOut(duration: 0.5)) { step = .reading } }
        Task { @MainActor in
            defer { sending = false }
            do {
                let (star, crisis) = try await model.publishLive(draft, floated: floated, rewriteOf: rewriteOf?.id)
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
                withAnimation(.easeInOut(duration: 0.5)) { step = .sendFailed(draft, floated: floated) }
            } catch let e as APIError where e.status == 402 {
                // 29: the server wants coins for a second float today.
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
        }
    }

    /// 05 별 띄우기: free once a day, then 5 coins. Short of coins → 29, with
    /// 충전 · 조용히 간직하기 · 계속 쓰기 side by side. Live, the server charges.
    private func float(_ go: @escaping () -> Void, keep: @escaping () -> Void) {
        if model.floatNeedsCharge {
            shortageKeep = keep
            showShortage = true
            return
        }
        if !model.useLiveAPI && !model.isFloatFree {
            _ = model.spendCoins(AppModel.floatCost, for: "별 띄우기")
        }
        go()
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

    /// 36 "조용히 간직하기": keep the star without analysis, then 13.
    private func keepInstead(_ star: StarItem) {
        guard let kept = model.keepInstead(star.id) else { return }
        withAnimation(.easeInOut(duration: 0.5)) { step = .kept(kept) }
    }

    private var isAnalyzing: Bool {
        if case .analyzing = step { true } else { false }
    }
}

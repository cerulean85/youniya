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
                // Only while the free first telescope is unused.
                if model.isTelescopeFree {
                    Text("처음 한 번은 무료")
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

    private enum Step: Equatable {
        case writing
        case analyzing(StarItem)
        case card(StarItem)
        case compare(previous: StarItem, current: StarItem)
        case kept(StarItem)
        /// 37 Crisis Care, then the step that would have come next.
        case crisis(StarItem, floated: Bool)
    }

    @State private var step: Step = .writing

    var body: some View {
        ZStack {
            switch step {
            case .writing:
                if let previous = rewriteOf {
                    RewriteView(previous: previous, question: model.rewriteQuestion(for: previous), onBack: onClose) { body, floated in
                        let star = model.publishRewrite(of: previous, body: body, floated: floated)
                        advance(after: star, floated: floated)
                    }
                    .transition(.opacity)
                } else {
                    StarMakingView(onClose: onClose) { draft, floated in
                        advance(after: model.publish(draft, floated: floated), floated: floated)
                    }
                    .transition(.opacity)
                }
            case .analyzing(let star):
                PrismAnalysisView(analysis: star.analysis!) {
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
            }
        }
        .edgeSwipeBack(enabled: !isAnalyzing, onBack: onClose)
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

    private var isAnalyzing: Bool {
        if case .analyzing = step { true } else { false }
    }
}

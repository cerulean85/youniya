import SwiftUI

// MARK: - 71 Float to the sky

// MARK: - 75 Someone's star

/// 75 다른 이의 별: one anonymous star, its 대표 문장 and (75-3) its whole text,
/// resonance. Opened from a star inside a plaza nebula (73), or from a 별 기록
/// row (09-3); from the plaza there's no owner nebula to open, so 「공명 남기기」
/// is the only action.
struct GalaxyStarView: View {
    @Environment(AppModel.self) private var model
    /// From 73: the nebula and the star's title. From 09-3: the plaza star.
    var nebula: GalaxyNebula? = nil
    var starTitle: String = ""
    var plazaStar: PlazaNebula? = nil
    var onBack: () -> Void
    /// 75-2: back to the previous page with the "차단했어요" toast.
    var onBlocked: () -> Void = {}

    @State private var showMenu = DebugScreen.is("75-1")
    /// Live 75-3: the whole text, from the plaza star's detail.
    @State private var liveText: (title: String, body: String)?

    private var title: String { plazaStar?.name ?? starTitle }
    private var key: String { plazaStar?.id ?? "star:\(nebula?.name ?? ""):\(starTitle)" }
    private var resonated: Bool { model.resonated.contains(key) }
    private var quote: String { plazaStar?.line ?? nebula?.quote ?? "" }
    private var depth: Int { plazaStar?.cardDepth ?? max(1, (nebula?.stage ?? 2) - 1) }
    private var spec: StarShapeSpec {
        plazaStar?.cardShape ?? nebula?.stars.first { $0.title == starTitle }?.spec ?? .init(points: 5, sharpness: .normal)
    }
    /// 75-3: the whole star (title and body, contacts masked by the server).
    private var fullText: (title: String, body: String)? {
        guard let p = plazaStar, p.fullText else { return nil }
        if let liveText { return (liveText.title.isEmpty ? p.name : liveText.title, liveText.body) }
        return p.fullBody.map { (p.fullTitle ?? p.name, $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "다른 이의 별", onBack: onBack, onMore: { showMenu.toggle() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(title)
                        .textStyle(.h2).foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: Space.sm) {
                        Tag(text: "익명의 별지기", tone: .neutral)
                        Tag(text: "깊이 \(depth)단계", tone: .gold)
                    }

                    // Figma `Hero`: the star in gold, a dotted orbit, four small stars.
                    // Figma: a tilted elliptical orbit (190×120) with two dashed rings.
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Color.starBright.opacity(0.25), .clear],
                                                 center: .center, startRadius: 0, endRadius: 100))
                            .frame(width: 200, height: 200)
                        ForEach([1.0, 0.72], id: \.self) { k in
                            Ellipse()
                                .strokeBorder(Color.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                                .frame(width: 190 * k, height: 120 * k)
                        }
                        ForEach(0..<4, id: \.self) { i in
                            let a = [192.0, 300.0, 15.0, 120.0][i] * .pi / 180
                            Circle().fill([Color.emotionSorrow, .emotionCalm, .brandWarm, .brandPrimary][i])
                                .frame(width: i == 3 ? 7 : 10, height: i == 3 ? 7 : 10)
                                .offset(x: cos(a) * 95, y: sin(a) * 60)
                        }
                        ShapeStar(spec: spec, color: .starBright, size: 58, rays: true)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        // The quote is empty while its owner picks a new one (12-3).
                        if !quote.isEmpty {
                            Text("“\(quote)”")
                                .textStyle(.observation).foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(fullText != nil ? "대표 문장이에요. 아래에서 글 전체를 읽을 수 있어요."
                                             : "본인이 고른 한 문장만 나눈 별이에요")
                            .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.lg)
                    .flatCard(seed: "star-quote")

                    if let fullText {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text(fullText.title)
                                .textStyle(.h3).foregroundStyle(Color.textPrimary)
                            // Figma: Serif 15, line height 175%.
                            Text(fullText.body)
                                .font(.custom("NotoSerifKR-Regular", size: 15, relativeTo: .callout))
                                .lineSpacing(15 * 0.75 - 4)
                                .foregroundStyle(Color.textSecondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    actions
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .task {
            if model.useLiveAPI, let p = plazaStar, p.fullText, let id = p.serverID {
                liveText = await model.plazaStarText(id)
            }
        }
        .modifier(PlazaSafetyModifier(showMenu: $showMenu, target: .star, nebulaName: nebula?.name ?? title,
                                       serverID: plazaStar?.serverID ?? nebula?.serverID, onBlocked: onBlocked))
    }

    @ViewBuilder private var actions: some View {
        let resonate = Button(resonated ? "공명했어요" : "공명 남기기") {
            withAnimation(.snappy) { model.toggleResonance(key) }
        }
        if plazaStar != nil {
            // From the plaza: no owner nebula to open (손님별 들이기 left with 2026-11-09).
            resonate.buttonStyle(.primary)
                .accessibilityAddTraits(resonated ? .isSelected : [])
        } else {
            HStack(spacing: Space.md) {
                resonate.buttonStyle(.secondary).frame(width: 140)
                Button("이 사람의 성운 보기", action: onBack)
                    .buttonStyle(.primary)
            }
        }
    }
}

// MARK: - 65 Slowly growing nebula

// MARK: - 66 Moments

// MARK: - 86 Four stages


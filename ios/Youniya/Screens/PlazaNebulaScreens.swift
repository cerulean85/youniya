import SwiftUI

// MARK: - Model

/// Someone's drawn nebula in the plaza (72–74, 78). Anonymous; no source text,
/// only the one sentence the owner chose to show.
/// TODO: All of this comes from the plaza API.
struct GalaxyNebula: Identifiable, Hashable {
    var name: String
    var stage: Int
    var resonance: Int
    /// The owner's chosen sentence (73).
    var quote: String
    /// Order for "새로 띄운 성운" (0 = newest) and closeness for "나와 비슷한 결".
    var order: Int
    var similarity: Double
    /// Where the cluster sits in the 72 field (unit square).
    var spot: CGPoint
    /// Live: the plaza share id, and whether the owner takes lines (74).
    var serverID: String? = nil
    var receiveLines = true
    /// Live: the share's `shape` (silhouette, edges, stars' moods).
    var shape: PlazaNebulaShape? = nil
    var id: String { name }

    /// How to draw it (80 곁에 둔, cards): the share's shape, or a steady sample.
    var figure: NebulaFigure { shape.map(NebulaFigure.init(plaza:)) ?? .sample(seed: name) }

    struct Line: Identifiable, Hashable {
        var hoursAgo: Double
        var text: String
        /// Live: the line id, for 100 신고하기.
        var serverID: String? = nil
        var id: String { text }

        var age: String {
            hoursAgo < 1 ? "방금" : hoursAgo < 24 ? "\(Int(hoursAgo))시간 전" : "\(Int(hoursAgo / 24))일 전"
        }
    }

    /// Others' lines of starlight, newest first (Figma 73/74 samples).
    var lines: [Line] {
        [
            Line(hoursAgo: 1, text: "그 문장, 저도 오늘 쓰고 싶던 말이에요."),
            Line(hoursAgo: 3, text: "저도 \(max(1, stage - 1))단계에서 오래 멈춰 있었어요. 다시 쓰니까 한 칸 더 들어가지더라고요."),
            Line(hoursAgo: 30, text: "천천히 와도 괜찮다는 말을 여기서 배웠어요."),
        ]
    }

    /// The nebula's stars: a seeded constellation in the unit square, joined in order.
    var stars: [(point: CGPoint, color: Color, title: String, spec: StarShapeSpec)] {
        var rng = SeededRandom(seed: name)
        let colors: [Color] = [.emotionCalm, .starClear, .brandPrimary, .emotionSorrow, .brandWarm, .emotionInsight, .emotionAnger]
        let titles = ["고요한 새벽의 별", "비가 그친 오후", "오래 머문 별", "말없이 건넨 별", "늦게 핀 별", "멀리 간 별", "작은 안부", "다시 쓴 별", "긴 숨"]
        let count = 10 + Int(rng.next(in: 0...2.99))
        var p = CGPoint(x: rng.next(in: 0.2...0.35), y: rng.next(in: 0.6...0.8))
        return (0..<count).map { i in
            // The first eight form the line; the rest float nearby.
            p = i < 8
                ? CGPoint(x: min(0.92, max(0.08, p.x + rng.next(in: -0.12...0.2))),
                          y: min(0.92, max(0.08, p.y + rng.next(in: -0.22...0.1))))
                : CGPoint(x: rng.next(in: 0.15...0.85), y: rng.next(in: 0.1...0.9))
            return (p, colors[Int(rng.next(in: 0...Double(colors.count) - 0.01))], titles[i % titles.count],
                    StarShapeSpec(points: 4 + Int(rng.next(in: 0...3.99)),
                                  sharpness: StarShapeSpec.Sharpness(rawValue: Int(rng.next(in: 0...2.99)))!))
        }
    }

    static let samples: [GalaxyNebula] = [
        GalaxyNebula(name: "비 온 뒤 고래자리", stage: 5, resonance: 24, quote: "괜찮다는 말 뒤에 숨는 건 이제 그만하고 싶다.",
                     order: 1, similarity: 0.93, spot: CGPoint(x: 0.44, y: 0.53)),
        GalaxyNebula(name: "느린 강자리", stage: 3, resonance: 11, quote: "오늘은 조금 늦게 흘러가도 괜찮았다.",
                     order: 0, similarity: 0.71, spot: CGPoint(x: 0.17, y: 0.2)),
        GalaxyNebula(name: "어느 밤의 성운", stage: 4, resonance: 17, quote: "말하지 못한 것들이 별이 되는 것 같았다.",
                     order: 2, similarity: 0.66, spot: CGPoint(x: 0.71, y: 0.16)),
        GalaxyNebula(name: "이름 없는 성운", stage: 2, resonance: 6, quote: "비가 그치고 나서야 숨이 쉬어졌다.",
                     order: 3, similarity: 0.52, spot: CGPoint(x: 0.19, y: 0.83)),
        GalaxyNebula(name: "작은 등불자리", stage: 3, resonance: 9, quote: "누군가 기다려 준다는 게 이렇게 따뜻한 일이었다.",
                     order: 4, similarity: 0.48, spot: CGPoint(x: 0.79, y: 0.75)),
    ]
}

// MARK: - 72 Plaza · Nebula

/// 72 우주 광장 · 성운: everyone's drawn nebulae in one field. No ranking.
struct PlazaNebulaField: View {
    enum Filter: String, CaseIterable { case similar = "나와 비슷한 결", newest = "새로 띄운 성운", kept = "곁에 둔 성운" }

    @Environment(AppModel.self) private var model
    var onOpen: (GalaxyNebula) -> Void

    @State private var filter: Filter = .similar
    @State private var selected: GalaxyNebula.ID?
    @State private var level: CGFloat = 1

    private var items: [GalaxyNebula] {
        switch filter {
        case .similar: model.galaxyNebulae.sorted { $0.similarity > $1.similarity }
        case .newest: model.galaxyNebulae.sorted { $0.order < $1.order }
        case .kept: model.galaxyNebulae.filter { model.resonated.contains(Self.key($0)) }
        }
    }

    static func key(_ n: GalaxyNebula) -> String { "nebula:" + n.name }

    var body: some View {
        let items = self.items
        let current = items.first { $0.id == selected } ?? items.first
        VStack(alignment: .leading, spacing: Space.lg) {
            // Figma: two rows of dotted chips.
            FlowRow(spacing: Space.sm) {
                ForEach(Filter.allCases, id: \.self) { f in
                    DotChip(title: f.rawValue, isSelected: filter == f) {
                        withAnimation(.snappy) { filter = f; selected = nil }
                    }
                }
            }

            if items.isEmpty {
                // 103
                EmptyStateView(title: "곁에 둔 성운이 아직 없어요",
                               message: "마음이 닿은 성운을 곁에 두면\n여기서 다시 모아 볼 수 있어요.",
                               action: ("나와 비슷한 결 둘러보기", .outline, {
                                   withAnimation(.snappy) { filter = .similar; selected = nil }
                               }))
                    .padding(.top, 48)
            } else {
            ZStack(alignment: .topTrailing) {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack(alignment: .topLeading) {
                        ForEach(items) { n in
                            let on = n.id == current?.id
                            let c = CGPoint(x: size.width / 2 + (n.spot.x * size.width - size.width / 2) * level,
                                            y: size.height / 2 + (n.spot.y * size.height - size.height / 2) * level)
                            Button { withAnimation(.snappy) { selected = n.id } } label: {
                                ZStack {
                                    if on {
                                        Circle().strokeBorder(Color.starBright, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                            .frame(width: 100 * level, height: 100 * level)
                                    }
                                    // The share's real shape (silhouette, edges, moods), like 80.
                                    NebulaFigureView(figure: n.figure, compact: true)
                                        .frame(width: (on ? 76 : 60) * level, height: (on ? 64 : 50) * level)
                                        .allowsHitTesting(false)
                                }
                                .frame(width: max(64, 100 * level), height: max(64, 100 * level))
                                .contentShape(.circle)
                            }
                            .buttonStyle(.plain)
                            .position(c)
                            .accessibilityLabel("\(n.name), \(n.stage)단계, 공명 \(n.resonance)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                .clipped()
                .gesture(MagnifyGesture().onChanged { v in level = min(2.6, max(1, v.magnification)) })
                ZoomControls(level: $level, range: 1...2.6)
                    .padding(.trailing, 4)
            }
            .frame(height: 280)

            Text("두 손가락으로 확대 · 별을 눌러 보기")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
            }

            if let current {
                Button { onOpen(current) } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text(current.name).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                            HStack(spacing: Space.sm) {
                                Tag(text: "깊이 \(current.stage)단계", tone: .gold)
                                // Live: others' resonance counts are never shown.
                                if current.serverID == nil {
                                    Tag(text: "공명 \(current.resonance + (model.resonated.contains(Self.key(current)) ? 1 : 0))", tone: .violet)
                                }
                            }
                        }
                        Spacer()
                        Text("들어가기 ›").textStyle(.labelS).foregroundStyle(Color.brandPrimaryText)
                    }
                    .padding(Space.lg)
                    .cosmos("field-card", in: RoundedRectangle(cornerRadius: Radius.lg))
                    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Figma `Chip` with a leading dot (09 sort, 72 filter).
struct DotChip: View {
    @Environment(\.skyTheme) private var theme
    var title: String
    var isSelected: Bool
    var dot: Color = .brandPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(title)
                    .textStyle(.labelS)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(isSelected ? theme.accent.tint.opacity(0.16) : Color.bgSurface, in: .capsule)
            .overlay(Capsule().strokeBorder(isSelected ? theme.accent.strong : Color.borderDefault, lineWidth: 1))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Figma `Tag`: small capsule label.
struct Tag: View {
    enum Tone { case gold, violet, neutral }
    var text: String
    var tone: Tone

    var body: some View {
        Text(text)
            .textStyle(.labelS)
            .foregroundStyle(tone == .gold ? Color.starBright : tone == .violet ? Color.brandPrimaryText : Color.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(tone == .gold ? Color.tintGold : tone == .violet ? Color.tintPrimary : Color.bgSurfaceRaised, in: .capsule)
    }
}

/// Wraps chips onto new lines.
struct FlowRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in rows(bounds.width, subviews).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxW: CGFloat = 0
        var pts: [CGPoint] = []
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            maxW = max(maxW, x - spacing)
        }
        return (pts, CGSize(width: maxW, height: y + rowH))
    }
}

// MARK: - 73 / 78 Someone's nebula

/// 73 다른 이의 성운; zoomed in (≥1.8×) it becomes 78, with star shapes and a tooltip.
struct GalaxyNebulaView: View {
    @Environment(AppModel.self) private var model
    var nebula: GalaxyNebula
    var onBack: () -> Void
    var onLines: () -> Void
    var onOpenStar: (String) -> Void
    /// 75-2 from the "···" menu: back with the "차단했어요" toast.
    var onBlocked: () -> Void = {}

    @State private var showMenu = false
    /// Figma 73 at 1×; 78 is the zoomed-in view.
    @State private var level: CGFloat = DebugScreen.is("78") ? 2.2 : 1
    @State private var selected = 0

    /// 78 from about 1.8× (1 + 0.4 + 0.4 is a hair under 1.8 in floating point).
    private var zoomed: Bool { level >= 1.75 }
    private var key: String { PlazaNebulaField.key(nebula) }
    private var resonated: Bool { model.resonated.contains(key) }

    var body: some View {
        let stars = nebula.stars
        VStack(spacing: 0) {
            TopAppBar(title: "다른 이의 성운", onBack: onBack, onMore: { showMenu.toggle() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(nebula.name)
                        .textStyle(.h2)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: Space.sm) {
                        Tag(text: "익명의 별지기", tone: .neutral)
                        Tag(text: "깊이 \(nebula.stage)단계", tone: .gold)
                    }

                    ZStack(alignment: .topTrailing) {
                        GeometryReader { geo in
                            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            let box = CGSize(width: 150, height: 150)
                            // Zoomed in (78), the selected star comes to the middle.
                            let focus = zoomed ? stars[selected].point : CGPoint(x: 0.5, y: 0.5)
                            let at: (CGPoint) -> CGPoint = {
                                CGPoint(x: c.x + ($0.x - focus.x) * box.width * level, y: c.y + ($0.y - focus.y) * box.height * level)
                            }
                            ZStack(alignment: .topLeading) {
                                Path { p in
                                    guard let f = stars.first else { return }
                                    p.move(to: at(f.point))
                                    for s in stars.dropFirst().prefix(7) { p.addLine(to: at(s.point)) }
                                }
                                .stroke(zoomed ? Color.borderFocus.opacity(0.5) : Color.textTertiary.opacity(0.6),
                                        lineWidth: zoomed ? 1.5 : 1)
                                ForEach(stars.indices, id: \.self) { i in
                                    Button { withAnimation(.snappy) { selected = i } } label: {
                                        Group {
                                            if zoomed {
                                                ShapeStar(spec: stars[i].spec,
                                                          color: i == selected ? .starBright : stars[i].color,
                                                          size: (i == selected ? 26 : 12) * level, rays: i == selected)
                                            } else {
                                                Circle().fill(stars[i].color).frame(width: i % 3 == 0 ? 8 : 6, height: i % 3 == 0 ? 8 : 6)
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                        .contentShape(.circle)
                                    }
                                    .buttonStyle(.plain)
                                    .position(at(stars[i].point))
                                    .accessibilityLabel("익명의 별, \(stars[i].title)")
                                    .accessibilityAddTraits(i == selected && zoomed ? .isSelected : [])
                                }
                            }
                        }
                        .clipped()
                        .contentShape(.rect)
                        .gesture(MagnifyGesture().onChanged { v in
                            withAnimation(.snappy) { level = min(3, max(1, v.magnification)) }
                        })
                        ZoomControls(level: $level, range: 1...3)
                    }
                    .frame(height: 190)

                    Text(zoomed ? "별의 모양은 쓴 글의 결로 정해져요" : "두 손가락으로 확대 · 별을 눌러 보기")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)

                    if zoomed {
                        // 78 Star tooltip
                        Button { onOpenStar(stars[selected].title) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text("익명의 별 · \(stars[selected].title)")
                                        .textStyle(.labelM).foregroundStyle(Color.textPrimary)
                                    Text("모양: \(stars[selected].spec.label) · 공명 \(nebula.resonance)")
                                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text("별 보기 ›").textStyle(.labelM).foregroundStyle(Color.brandPrimaryText)
                            }
                            .padding(Space.lg)
                            .cosmos("tip-\(nebula.name)", in: RoundedRectangle(cornerRadius: Radius.lg))
                            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.starBright, lineWidth: 1))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("“\(nebula.quote)”")
                                .textStyle(.observation)
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("본인이 골라 가린 한 문장이에요")
                                .textStyle(.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.lg)
                        .flatCard(seed: "quote-\(nebula.name)")
                    }

                    HStack(spacing: Space.md) {
                        Button(resonated ? "공명했어요" : "공명 남기기") {
                            withAnimation(.snappy) { model.toggleResonance(key) }
                        }
                        .buttonStyle(.secondary)
                        .frame(width: 140)
                        .accessibilityValue(resonated ? "남겼어요" : "")
                        Button("별빛 한 줄", action: onLines)
                            .buttonStyle(.primary)
                    }

                    Text("별빛 한 줄")
                        .textStyle(.labelS)
                        .foregroundStyle(Color.textTertiary)
                    VStack(spacing: Space.md) {
                        ForEach(model.lines(for: nebula).prefix(2)) { line in
                            LineCard(who: "익명의 별지기", line: line, mine: false, compact: true)
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
        .modifier(PlazaSafetyModifier(showMenu: $showMenu, target: .nebula, nebulaName: nebula.name,
                                       serverID: nebula.serverID, onBlocked: onBlocked))
        .task { await model.loadLines(for: nebula) }
    }
}

// MARK: - 74 Starlight line (nebula)

/// 74 별빛 한 줄: one line per person per nebula; lines fade after a day.
struct GalaxyLinesView: View {
    @Environment(AppModel.self) private var model
    var nebula: GalaxyNebula
    var onBack: () -> Void

    @State private var draft = DebugScreen.is("99") ? "그런 생각은 한심해요." : DebugScreen.is("106") ? String(repeating: "오늘의 별빛이 참 따뜻해서 오래 머물렀어요. ", count: 3) : ""
    @State private var toast: ToastCardMessage?
    /// 99: the last line was held back by the filter.
    @State private var rejected = DebugScreen.is("99")
    /// 100: the line being reported.
    @State private var reporting: GalaxyNebula.Line?
    @State private var reportSheetHeight: CGFloat = 420
    @FocusState private var editing: Bool

    private static let reactions = ["공감해요", "저도 그랬어요", "고마워요"]
    private static let limit = 60

    private var mine: String? { model.nebulaLines[nebula.name] }
    private var over: Bool { draft.count > Self.limit }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty && !over }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "별빛 한 줄 · \(nebula.name)", onBack: onBack)

            ScrollView {
                VStack(spacing: Space.lg) {
                    Text("한 사람이 한 성운에 한 줄씩. 하루가 지나면 별빛이 희미해져요.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                    ForEach(model.lines(for: nebula)) { line in
                        if model.reportedLines.contains(line.text) {
                            // 101: a reported line is hidden right away.
                            HiddenLineCard()
                        } else {
                            LineCard(who: "익명의 별지기", line: line, mine: false, compact: false)
                                .contextMenu {
                                    Button("신고하기", systemImage: "flag") { reporting = line }
                                }
                                .accessibilityAction(named: "신고하기") { reporting = line }
                        }
                    }
                    if let mine {
                        LineCard(who: "나", line: .init(hoursAgo: 0, text: mine), mine: true, compact: false)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            VStack(alignment: .leading, spacing: Space.md) {
                if mine != nil {
                    // 107
                    NoticeBanner(message: "이 성운에는 이미 한 줄을 남겼어요")
                } else {
                    if rejected {
                        // 99
                        NoticeBanner(message: "상처가 될 수 있는 말이 있어 띄우지 못했어요", tone: .warm)
                            .transition(.opacity)
                    } else if over {
                        // 106
                        NoticeBanner(message: "\(draft.count) / \(Self.limit)자 · \(Self.limit)자 안으로 줄여 주세요", tone: .warm)
                            .transition(.opacity)
                    } else {
                        HStack(spacing: Space.sm) {
                            ForEach(Self.reactions, id: \.self) { r in
                                DotChip(title: r, isSelected: false) { send(r) }
                            }
                        }
                    }
                    composer
                }
                if mine == nil {
                    HStack(spacing: 0) {
                        Text("상처 주는 말은 별빛이 되지 못해요 · 보내기 전에 한 번 걸러요 · ")
                        Button("신고") { reporting = model.lines(for: nebula).first { !model.reportedLines.contains($0.text) } }
                            .buttonStyle(.plain)
                            .underline()
                    }
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.lg)
            .animation(.easeInOut(duration: 0.2), value: over)
            .animation(.easeInOut(duration: 0.2), value: rejected)
        }
        .background { StarField() }
        .task { await model.loadLines(for: nebula) }
        .task {
            #if DEBUG
            if DebugScreen.is("100") { reporting = model.lines(for: nebula).first }
            if DebugScreen.is("101") { toast = ToastCardMessage(title: "신고를 받았어요", detail: "살펴본 뒤 결과를 알림으로 알려 드릴게요") }
            #endif
        }
        .toastCard($toast)
        .sheet(item: $reporting) { line in
            ReportSheet(
                onReport: { reason, alsoBlock in
                    reporting = nil
                    _ = withAnimation(.snappy) { model.reportedLines.insert(line.text) }
                    Task { @MainActor in
                        if model.useLiveAPI, let id = line.serverID {
                            // Reports and, when asked, blocks in one call.
                            _ = await model.reportLive(.line(id), reason: reason, block: alsoBlock)
                        } else if alsoBlock {
                            _ = await model.block(.line, nebulaName: nil, target: nil)
                        }
                    }
                    toast = alsoBlock
                        ? ToastCardMessage(title: "신고하고 차단했어요", detail: "이 사람의 글이 더 보이지 않아요")
                        : ToastCardMessage(title: "신고를 받았어요", detail: "살펴본 뒤 결과를 알림으로 알려 드릴게요")
                },
                onCancel: { reporting = nil }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { reportSheetHeight = $0 }
            .presentationDetents([.height(reportSheetHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "report-sheet") }
        }
    }

    /// Figma `Composer`: grows with the text (68pt, 94pt over three lines).
    private var composer: some View {
        HStack(alignment: .center, spacing: Space.md) {
            TextField("", text: $draft,
                      prompt: Text("한 줄을 남겨 보세요 (\(Self.limit)자)").foregroundStyle(Color.textTertiary),
                      axis: .vertical)
                .textInputStyle(.bodyS)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1...4)
                .focused($editing)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                .onChange(of: draft) { _, _ in if rejected { withAnimation { rejected = false } } }
            // Figma `Send`: a plain 34pt violet circle (40% when it can't send).
            Button { send(draft) } label: {
                Circle().fill(Color.hex(0x8555EF))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(.iconSend).renderingMode(.template).resizable()
                            .frame(width: 18, height: 18).foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.4)
            .accessibilityLabel("보내기")
        }
        .padding(.leading, Space.lg)
        .padding(.trailing, Space.md)
        .padding(.vertical, Space.md)
        .frame(minHeight: 68)
        .itemCard(seed: "line-input", minHeight: 0)
    }

    /// Mock: a quick local filter, then save. TODO: Server-side moderation.
    private func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= Self.limit else { return }
        if LineFilter.isHurtful(t) {
            // 99: keep the text so it can be rewritten.
            withAnimation { rejected = true }
            return
        }
        editing = false
        guard model.useLiveAPI else {
            withAnimation(.snappy) { model.nebulaLines[nebula.name] = t }
            draft = ""
            return
        }
        // The server checks again (99 hurtful, 106 too long, 107 already left).
        Task { @MainActor in
            switch await model.leaveLine(t, on: nebula) {
            case nil: draft = ""
            case "hurtful": withAnimation { rejected = true }
            default: break
            }
        }
    }
}

/// 101: a line the user reported, hidden in place.
private struct HiddenLineCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("신고한 별빛").textStyle(.caption).foregroundStyle(Color.textTertiary)
            Text("가려진 별빛이에요. 살펴본 뒤 알려 드릴게요.").textStyle(.bodyS).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .flatCard(seed: "hidden-line")
        .opacity(0.7)
        .accessibilityElement(children: .combine)
    }
}

/// Figma line card: who · when, then the line. Mine is gold; old lines fade.
private struct LineCard: View {
    var who: String
    var line: GalaxyNebula.Line
    var mine: Bool
    var compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("\(who) · \(line.age)")
                .textStyle(.caption)
                .foregroundStyle(mine ? Color.starBright : Color.textTertiary)
            Text(line.text)
                .textStyle(.bodyS)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(compact ? 1 : nil)
                .fixedSize(horizontal: false, vertical: !compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .background {
            if mine {
                RoundedRectangle(cornerRadius: Radius.lg).fill(Color.tintGold)
            }
        }
        .flatCard(seed: "line-\(line.text)")
        .overlay {
            if mine { RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.starBright, lineWidth: 1) }
        }
        // "하루가 지나면 별빛이 희미해져요"
        .opacity(line.hoursAgo >= 24 ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Figma plaza cards (73, 74): surface, Cosmos BG, flat slate border.
    func flatCard(seed: String) -> some View {
        cosmos(seed, in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
    }
}

/// A small on-device first pass. TODO: Replace with the reviewed server filter.
enum LineFilter {
    private static let words = ["죽어", "꺼져", "병신", "멍청", "한심", "쓰레기", "닥쳐", "stupid", "idiot", "loser"]
    static func isHurtful(_ s: String) -> Bool {
        let t = s.lowercased()
        return words.contains { t.contains($0) }
    }
}

#Preview("72") {
    ScrollView { PlazaNebulaField(onOpen: { _ in }).padding(24) }
        .background(Color.bgCanvas)
        .environment(AppModel())
}

#Preview("73") {
    GalaxyNebulaView(nebula: GalaxyNebula.samples[0], onBack: {}, onLines: {}, onOpenStar: { _ in })
        .environment(AppModel())
}

#Preview("74") {
    GalaxyLinesView(nebula: GalaxyNebula.samples[0], onBack: {}).environment(AppModel())
}

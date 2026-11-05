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
    var id: String { name }

    struct Line: Identifiable, Hashable {
        var hoursAgo: Double
        var text: String
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
        case .similar: GalaxyNebula.samples.sorted { $0.similarity > $1.similarity }
        case .newest: GalaxyNebula.samples.sorted { $0.order < $1.order }
        case .kept: GalaxyNebula.samples.filter { model.resonated.contains(Self.key($0)) }
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
                                    MiniConstellation(nebula: n, dot: on ? 6 : 5)
                                        .frame(width: (on ? 76 : 60) * level, height: (on ? 64 : 50) * level)
                                }
                                .frame(width: max(64, 100 * level), height: max(64, 100 * level))
                                .contentShape(.circle)
                            }
                            .buttonStyle(.plain)
                            .position(c)
                            .accessibilityLabel("\(n.name), \(n.stage)단계, 공명 \(n.resonance)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                        if items.isEmpty {
                            Text("공명을 남긴 성운이 이곳에 곁에 남아요.")
                                .textStyle(.bodyS)
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: size.width, height: size.height)
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
                .textStyleBox(.caption)
                .foregroundStyle(Color.textTertiary)

            if let current {
                Button { onOpen(current) } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text(current.name).textStyleBox(.labelM).foregroundStyle(Color.textPrimary)
                            HStack(spacing: Space.sm) {
                                Tag(text: "\(current.stage)단계", tone: .gold)
                                Tag(text: "공명 \(current.resonance + (model.resonated.contains(Self.key(current)) ? 1 : 0))", tone: .violet)
                            }
                        }
                        Spacer()
                        Text("들어가기 ›").textStyleBox(.labelS).foregroundStyle(Color.brandPrimaryText)
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

/// A nebula's constellation drawn small: lines and colored dots.
struct MiniConstellation: View {
    var nebula: GalaxyNebula
    var dot: CGFloat
    var lineColor: Color = Color.textTertiary.opacity(0.6)

    var body: some View {
        GeometryReader { geo in
            let stars = nebula.stars
            let at: (CGPoint) -> CGPoint = { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }
            ZStack(alignment: .topLeading) {
                Path { p in
                    guard let f = stars.first else { return }
                    p.move(to: at(f.point))
                    for s in stars.dropFirst().prefix(7) { p.addLine(to: at(s.point)) }
                }
                .stroke(lineColor, lineWidth: 1)
                ForEach(stars.indices, id: \.self) { i in
                    Circle().fill(stars[i].color)
                        .frame(width: dot * (i % 3 == 0 ? 1.3 : 1), height: dot * (i % 3 == 0 ? 1.3 : 1))
                        .position(at(stars[i].point))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Figma `Chip` with a leading dot (09 sort, 72 filter).
private struct DotChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Circle().fill(Color.brandPrimary).frame(width: 8, height: 8)
                Text(title)
                    .textStyle(.labelS)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(isSelected ? Color.tintPrimary : Color.bgSurface, in: .capsule)
            .overlay(Capsule().strokeBorder(isSelected ? Color.brandPrimary : Color.borderDefault, lineWidth: 1))
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
            .textStyleBox(.labelS)
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

    @State private var level: CGFloat = 1
    @State private var selected = 0

    /// 78 from about 1.8× (1 + 0.4 + 0.4 is a hair under 1.8 in floating point).
    private var zoomed: Bool { level >= 1.75 }
    private var key: String { PlazaNebulaField.key(nebula) }
    private var resonated: Bool { model.resonated.contains(key) }

    var body: some View {
        let stars = nebula.stars
        VStack(spacing: 0) {
            TopAppBar(title: "다른 이의 성운", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(nebula.name)
                        .textStyleBox(.h2)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: Space.sm) {
                        Tag(text: "익명의 별지기", tone: .neutral)
                        Tag(text: "\(nebula.stage)단계", tone: .gold)
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
                        .textStyleBox(.caption)
                        .foregroundStyle(Color.textTertiary)

                    if zoomed {
                        // 78 Star tooltip
                        Button { onOpenStar(stars[selected].title) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text("익명의 별 · \(stars[selected].title)")
                                        .textStyleBox(.labelM).foregroundStyle(Color.textPrimary)
                                    Text("모양: \(stars[selected].spec.label) · 공명 \(nebula.resonance)")
                                        .textStyleBox(.caption).foregroundStyle(Color.textTertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text("별 보기 ›").textStyleBox(.labelM).foregroundStyle(Color.brandPrimaryText)
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
                                .textStyleBox(.observation)
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("본인이 골라 가린 한 문장이에요")
                                .textStyleBox(.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.lg)
                        .flatCard(seed: "quote-\(nebula.name)")
                    }

                    HStack(spacing: Space.md) {
                        Button("공명 \(nebula.resonance + (resonated ? 1 : 0))") {
                            withAnimation(.snappy) { model.toggleResonance(key) }
                        }
                        .buttonStyle(.secondary)
                        .frame(width: 140)
                        .accessibilityValue(resonated ? "남겼어요" : "")
                        Button("별빛 한 줄", action: onLines)
                            .buttonStyle(.primary)
                    }

                    Text("별빛 한 줄")
                        .textStyleBox(.labelS)
                        .foregroundStyle(Color.textTertiary)
                    VStack(spacing: Space.md) {
                        ForEach(nebula.lines.prefix(2)) { line in
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
    }
}

// MARK: - 74 Starlight line (nebula)

/// 74 별빛 한 줄: one line per person per nebula; lines fade after a day.
struct GalaxyLinesView: View {
    @Environment(AppModel.self) private var model
    var nebula: GalaxyNebula
    var onBack: () -> Void

    @State private var draft = ""
    @State private var toast: ToastCardMessage?
    @FocusState private var editing: Bool

    private static let reactions = ["공감해요", "저도 그랬어요", "고마워요"]
    private static let limit = 60

    private var mine: String? { model.nebulaLines[nebula.name] }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "별빛 한 줄 · \(nebula.name)", onBack: onBack)

            ScrollView {
                VStack(spacing: Space.lg) {
                    Text("한 사람이 한 성운에 한 줄씩. 하루가 지나면 별빛이 희미해져요.")
                        .textStyleBox(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                    ForEach(nebula.lines) { line in
                        LineCard(who: "익명의 별지기", line: line, mine: false, compact: false)
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
                if mine == nil {
                    HStack(spacing: Space.sm) {
                        ForEach(Self.reactions, id: \.self) { r in
                            DotChip(title: r, isSelected: false) { send(r) }
                        }
                    }
                    HStack(spacing: Space.md) {
                        TextField("", text: $draft,
                                  prompt: Text("한 줄을 남겨 보세요 (\(Self.limit)자)").foregroundStyle(Color.textTertiary))
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textPrimary)
                            .focused($editing)
                            .submitLabel(.send)
                            .onSubmit { send(draft) }
                            .onChange(of: draft) { _, v in
                                if v.count > Self.limit { draft = String(v.prefix(Self.limit)) }
                            }
                        // Figma `Send`: a plain 34pt violet circle.
                        Button { send(draft) } label: {
                            Circle().fill(Color.brandPrimary)
                                .frame(width: 34, height: 34)
                                .frame(width: 44, height: 44)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        .accessibilityLabel("보내기")
                    }
                    .padding(.leading, Space.lg)
                    .padding(.trailing, Space.md)
                    .frame(height: 68)
                    .cosmos("line-input", in: RoundedRectangle(cornerRadius: Radius.lg))
                    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.brandPrimary, lineWidth: 1))
                } else {
                    Text("이 성운에는 한 줄을 남겼어요.")
                        .textStyleBox(.bodyS)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: 0) {
                    Text("상처 주는 말은 별빛이 되지 못해요 · 보내기 전에 한 번 걸러요 · ")
                    Button("신고") { toast = ToastCardMessage(title: "알려 줘서 고마워요", detail: "살펴본 뒤 조용히 정리할게요") }
                        .buttonStyle(.plain)
                        .underline()
                }
                .textStyleBox(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.lg)
        }
        .background { StarField() }
        .toastCard($toast)
    }

    /// Mock: a quick local filter, then save. TODO: Server-side moderation.
    private func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if LineFilter.isHurtful(t) {
            toast = ToastCardMessage(title: "이 말은 별빛이 되지 못해요", detail: "조금 부드럽게 다시 써 볼까요?")
            return
        }
        editing = false
        withAnimation(.snappy) { model.nebulaLines[nebula.name] = t }
        draft = ""
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
                .textStyleBox(.caption)
                .foregroundStyle(mine ? Color.starBright : Color.textTertiary)
            Text(line.text)
                .textStyleBox(.bodyM)
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

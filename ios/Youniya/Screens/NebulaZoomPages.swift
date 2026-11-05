import SwiftUI

// MARK: - Shared pieces (76, 77)

/// Figma `Zoom Controls`: + / level / −, 36pt circles. − is filled violet.
private struct ZoomControls: View {
    @Binding var level: CGFloat
    var range: ClosedRange<CGFloat>

    var body: some View {
        VStack(spacing: Space.xs) {
            button("+", filled: false, label: "확대") { level = min(range.upperBound, level + 0.4) }
            Text(String(format: "%.1f×", level))
                .textStyle(.caption)
                .foregroundStyle(Color.textSecondary)
                .accessibilityHidden(true)
            button("−", filled: true, label: "축소") { level = max(range.lowerBound, level - 0.4) }
        }
    }

    private func button(_ glyph: String, filled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Text(glyph)
                .textStyle(.h3)
                .foregroundStyle(filled ? Color.white : Color.textSecondary)
                .frame(width: 36, height: 36)
                .cosmos("zoom-\(glyph)", in: Circle(), intensity: 0.6)
                .background(filled ? Color.hex(0x8555EF) : Color.bgSurfaceRaised, in: .circle)
                .overlay(Circle().strokeBorder(Color.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%.1f배", level))
    }
}

/// Figma `Star Tooltip`: the selected star, its shape, and a link to it.
private struct StarTooltip: View {
    var star: StarItem
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("내 별 · \(star.title)")
                        .textStyleBox(.labelM)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text("모양: \(StarShapeSpec(star: star).label) · 별빛 \(star.starlightValue ?? 0)")
                        .textStyleBox(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("별 보기 ›")
                    .textStyleBox(.labelM)
                    .foregroundStyle(Color.hex(0x8555EF))
            }
            .padding(Space.lg)
            .cosmos("tooltip", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.starBright, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Pinch, drag and the +/− buttons over a fixed-size drawing.
private struct ZoomPanCanvas<Content: View>: View {
    @Binding var level: CGFloat
    var range: ClosedRange<CGFloat>
    @ViewBuilder var content: (_ level: CGFloat) -> Content

    @State private var pan: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var pinchStart: CGFloat?

    var body: some View {
        content(level)
            .offset(pan)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        let start = dragStart ?? pan
                        dragStart = start
                        pan = CGSize(width: start.width + v.translation.width, height: start.height + v.translation.height)
                    }
                    .onEnded { _ in dragStart = nil }
                    .simultaneously(with: MagnifyGesture()
                        .onChanged { v in
                            let start = pinchStart ?? level
                            pinchStart = start
                            level = min(range.upperBound, max(range.lowerBound, start * v.magnification))
                        }
                        .onEnded { _ in pinchStart = nil })
            )
            .clipped()
    }
}

// MARK: - 77 My nebula, zoomed

/// 77 나의 성운 (확대): my stars as shapes, joined into petals around one star.
struct MyNebulaZoomView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void
    /// 성운 그리기 · 성운 이야기 · 자라는 모습 · 하늘에 띄우기
    var onOpen: (String) -> Void

    @State private var level: CGFloat = 2.4
    @State private var selectedID: StarItem.ID?
    @State private var toast: String?

    private var floated: [StarItem] { model.stars.filter(\.isFloated) }
    private var selected: StarItem? {
        floated.first { $0.id == selectedID } ?? floated.first
    }

    var body: some View {
        let layout = PetalLayout(stars: floated, center: selected)
        VStack(spacing: 0) {
            TopAppBar(title: "나의 성운", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(model.nebulaName)
                        .textStyleBox(.labelS)
                        .foregroundStyle(Color.starBright)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.xs)
                        .background(Color.tintGold, in: .capsule)
                    Text(layout.petals.isEmpty ? "아직 꽃잎이 없는 성운" : "\(layout.petals.count)개의 꽃잎을 가진 성운")
                        .textStyleBox(.h1)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    ZStack(alignment: .topTrailing) {
                        ZoomPanCanvas(level: $level, range: 1...3.2) { level in
                            PetalNebula(layout: layout, level: level) { selectedID = $0.id }
                        }
                        ZoomControls(level: $level, range: 1...3.2)
                            .padding(.top, 4)
                        Text("별의 모양은 쓴 글의 결로 정해져요")
                            .textStyle(.caption)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    .frame(height: 280)

                    if let selected {
                        StarTooltip(star: selected) { onOpenStar(selected) }
                    }

                    HStack(spacing: Space.sm) {
                        LinkChip(title: "성운 그리기") { onOpen("성운 그리기") }
                        LinkChip(title: "성운 이야기") { onOpen("성운 이야기") }
                        LinkChip(title: "자라는 모습") { onOpen("자라는 모습") }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Space.md) {
                // TODO: 71 하늘에 띄우기 시트
                Button("하늘에 띄우기") { onOpen("하늘에 띄우기") }
                    .buttonStyle(.primary)
                Button("이미지로 저장") { saveImage(layout) }
                    .buttonStyle(.ghost)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .toast($toast)
    }

    /// Saves the whole nebula (zoomed out) to Photos, then T2.
    @MainActor
    private func saveImage(_ layout: PetalLayout) {
        let renderer = ImageRenderer(content:
            PetalNebula(layout: layout, level: 1.4, onSelect: { _ in })
                .frame(width: 360, height: 360)
                .background(Color.bgCanvas)
        )
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        toast = "이미지로 저장했어요"
    }
}

/// Where each star sits in 77: one center star, then petals of up to three
/// stars each, newest first, going around the center.
struct PetalLayout {
    struct Node: Identifiable {
        var star: StarItem
        var point: CGPoint   // relative to the center star, at level 1
        var id: StarItem.ID { star.id }
    }

    var center: StarItem?
    var petals: [[Node]] = []

    init(stars: [StarItem], center: StarItem?) {
        self.center = center
        let others = stars.filter { $0.id != center?.id }
        guard !others.isEmpty else { return }
        let count = min(6, max(1, Int((Double(others.count) / 3).rounded(.up))))
        for p in 0..<count {
            let members = Array(others.dropFirst(p * 3).prefix(3))
            guard !members.isEmpty else { continue }
            let angle = -90.0 + Double(p) * 360 / Double(count)
            // Three stars per petal: left edge, tip, right edge.
            let shape: [(Double, Double)] = [(-20, 52), (0, 86), (20, 52)]
            petals.append(members.enumerated().map { i, star in
                let (da, r) = shape[i]
                let a = (angle + da) * .pi / 180
                return Node(star: star, point: CGPoint(x: cos(a) * r, y: sin(a) * r))
            })
        }
    }
}

/// Figma `Nebula Shape`: violet petal lines and star shapes, scaled by `level`.
private struct PetalNebula: View {
    var layout: PetalLayout
    var level: CGFloat
    var onSelect: (StarItem) -> Void

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let at: (CGPoint) -> CGPoint = { CGPoint(x: c.x + $0.x * level, y: c.y + $0.y * level) }
            ZStack(alignment: .topLeading) {
                // Petal outlines: center → stars → center.
                ForEach(layout.petals.indices, id: \.self) { i in
                    Path { p in
                        p.move(to: c)
                        for n in layout.petals[i] { p.addLine(to: at(n.point)) }
                        p.closeSubpath()
                    }
                    .stroke(Color.hex(0x8555EF).opacity(0.55), lineWidth: 2.4)
                }
                ForEach(layout.petals.flatMap { $0 }) { node in
                    star(node.star, selected: false)
                        .position(at(node.point))
                }
                if let center = layout.center {
                    star(center, selected: true)
                        .position(c)
                }
            }
        }
    }

    private func star(_ s: StarItem, selected: Bool) -> some View {
        let deep = s.analysis?.isDeep == true
        let size: CGFloat = (selected ? 36 : deep ? 23 : 13) * level
        var rng = SeededRandom(seed: s.id.uuidString)
        return Button { onSelect(s) } label: {
            ShapeStar(spec: StarShapeSpec(star: s),
                      color: selected ? .starBright : s.mood.color,
                      size: size, rays: selected || deep)
                .rotationEffect(.degrees(rng.next(in: 0...40)))
                .frame(width: max(size, 44), height: max(size, 44))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(s.title), 별빛 \(s.starlightValue ?? 0)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - 76 Galaxy, zoomed

/// 76 은하 확대: everyone's stars tonight, mine ringed in gold.
struct GalaxyZoomView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void
    var onMyNebula: () -> Void
    var onPlaza: () -> Void

    @State private var level: CGFloat = 2.6

    /// TODO: Tonight's count comes from the plaza API.
    private let tonight = 1284

    var body: some View {
        // My stars in everyone's galaxy are the ones shared to the plaza (19).
        let mine = model.stars.filter { $0.isFloated && $0.isShared }
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("TONIGHT · \(tonight.formatted())개의 마음")
                .textStyleBox(.labelS)
                .foregroundStyle(Color.starBright)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs)
                .background(Color.tintGold, in: .capsule)
            Text("오늘 밤,\n\(tonight.formatted())개의 마음이 모였어요")
                .textStyleBox(.h1)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(mine.isEmpty
                 ? "별을 우주 광장에 나누면 이 안에서 함께 빛나요. 별 하나하나는 익명이고, 글은 보이지 않아요."
                 : "내 별 \(mine.count)개가 이 안에서 빛나고 있어요. 별 하나하나는 익명이고, 글은 보이지 않아요.")
                .textStyleBox(.bodyS)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topTrailing) {
                ZoomPanCanvas(level: $level, range: 1...3.4) { level in
                    GalaxyField(mine: mine, level: level)
                }
                ZoomControls(level: $level, range: 1...3.4)
                    .padding(.top, 8)
                    .padding(.trailing, 4)
                Text("별의 모양은 쓴 글의 결로 정해져요")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }
            .frame(height: 300)

            if let first = mine.first {
                StarTooltip(star: first) { onOpenStar(first) }
            }

            Spacer(minLength: 0)

            VStack(spacing: Space.md) {
                Button("나의 성운 보기", action: onMyNebula).buttonStyle(.primary)
                Button("성운 광장 가기", action: onPlaza).buttonStyle(.secondary)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xl)
        .background { StarField() }
        // No back button in Figma: edge swipe, and the VoiceOver escape gesture.
        .accessibilityAction(.escape, onBack)
    }
}

/// Figma `Galaxy`: a warm core, about two hundred anonymous star shapes,
/// gold rings on my stars, and my newest star large in the middle.
private struct GalaxyField: View {
    var mine: [StarItem]
    var level: CGFloat

    private struct Other: Identifiable {
        var id: Int
        var point: CGPoint
        var size: CGFloat
        var color: Color
        var opacity: Double
        var spec: StarShapeSpec
        var angle: Double
    }

    /// Seeded so the sky stays the same between visits.
    private static let others: [Other] = {
        var rng = SeededRandom(seed: "galaxy-76")
        return (0..<200).map { i in
            // Spread wide, like the Figma zoom layer: only some are in view at 2.6×.
            let r = sqrt(rng.next(in: 0...1)) * 330
            let a = rng.next(in: 0...(2 * .pi))
            let tone = rng.next(in: 0...1)
            let color: Color = tone < 0.86 ? .textPrimary : tone < 0.93 ? .emotionCalm : .emotionInsight
            return Other(id: i,
                         point: CGPoint(x: cos(a) * r, y: sin(a) * r * 0.85),
                         size: rng.next(in: 16...22) / 2.6,
                         color: color,
                         opacity: rng.next(in: 0.4...0.9),
                         spec: .init(points: 4 + Int(rng.next(in: 0...3.99)),
                                     sharpness: StarShapeSpec.Sharpness(rawValue: Int(rng.next(in: 0...2.99)))!),
                         angle: rng.next(in: 0...40))
        }
    }()

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 30)
            let at: (CGPoint) -> CGPoint = { CGPoint(x: c.x + $0.x * level, y: c.y + $0.y * level) }
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: Color.hex(0xFABF4D).opacity(0.5), location: 0),
                        .init(color: Color.hex(0x8C5CF5).opacity(0.22), location: 0.5),
                        .init(color: Color.hex(0x8C5CF5).opacity(0), location: 1),
                    ], center: .center, startRadius: 0, endRadius: 130 * level))
                    .frame(width: 260 * level, height: 260 * level)
                    .position(c)

                ForEach(Self.others) { o in
                    ShapeStar(spec: o.spec, color: o.color, size: o.size * level, halo: false)
                        .rotationEffect(.degrees(o.angle))
                        .opacity(o.opacity)
                        .position(at(o.point))
                }

                // My other stars: gold shapes with a ring.
                ForEach(Array(mine.dropFirst().prefix(4).enumerated()), id: \.element.id) { i, star in
                    var rng = SeededRandom(seed: star.id.uuidString)
                    let p = CGPoint(x: rng.next(in: -120...120), y: rng.next(in: -90...60))
                    ZStack {
                        Circle().strokeBorder(Color.starBright, lineWidth: 1.5).frame(width: 20 * level, height: 20 * level)
                        ShapeStar(spec: StarShapeSpec(star: star), color: .starBright, size: 15 * level, rays: i == 0)
                    }
                    .position(at(p))
                    .accessibilityHidden(true)
                }

                if let hero = mine.first {
                    // Hero: halo, an 8-ray burst, the star, and a target ring.
                    ZStack {
                        CurvedStar(points: 8, inner: 0.3)
                            .fill(Color.starBright.opacity(0.35))
                            .frame(width: 41 * level, height: 41 * level)
                        ShapeStar(spec: StarShapeSpec(star: hero), color: .starBright, size: 26 * level, rays: true)
                        Circle().strokeBorder(Color.starBright.opacity(0.7), lineWidth: 1.5)
                            .frame(width: 76, height: 76)
                    }
                    .position(c)
                    .accessibilityElement()
                    .accessibilityLabel("내 별, \(hero.title)")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 83 Nebula story

/// 83 성운 이야기: one core sentence per star, oldest first, left as written.
struct NebulaStoryView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onSaved: () -> Void
    var onNeedCoins: () -> Void

    @State private var toast: ToastCardMessage?

    struct Line: Identifiable {
        var star: StarItem
        var sentence: String
        var id: StarItem.ID { star.id }
    }

    /// TODO: The analysis picks the core sentence; for now, the last one.
    private var lines: [Line] {
        model.stars
            .filter(\.isFloated)
            .sorted { ($0.date ?? .now) < ($1.date ?? .now) }
            .compactMap { star in
                let parts = star.body
                    .components(separatedBy: CharacterSet(charactersIn: ".!?。\n"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                guard let last = parts.last else { return nil }
                let end = star.body.contains(last + ".") ? "." : star.body.contains(last + "?") ? "?" : ""
                return Line(star: star, sentence: last + end)
            }
    }

    /// Mock bridging lines shown at ✦ after "서사 다듬기". TODO: Generated by the API.
    private static let bridges = ["그리고 며칠이 흘러,", "조금 더 지나서,", "그 마음이 이어져,", "어느 저녁에는,"]

    var body: some View {
        let lines = self.lines
        let floated = model.stars.filter(\.isFloated)
        let since = floated.compactMap(\.date).min()
        VStack(spacing: 0) {
            TopAppBar(title: "성운 이야기", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("\(model.nebulaName) 이야기")
                            .textStyleBox(.h2)
                            .foregroundStyle(Color.textPrimary)
                        Text("별마다 고른 핵심 문장을 시간순으로 엮었어요. 원문 문장은 한 글자도 바꾸지 않아요.")
                            .textStyleBox(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    HStack(spacing: Space.sm) {
                        tag(since.map { "별 \(floated.count) · \(Self.day($0))부터" } ?? "별 \(floated.count)", gold: true)
                        tag(model.storyPolished ? "서사 다듬기" : "문장 엮기", gold: false)
                    }

                    if lines.isEmpty {
                        Text("글이 있는 별을 띄우면 이야기가 엮여요.")
                            .textStyleBox(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        storyCard(lines)
                    }

                    Text("✦ 표시는 문장 사이를 잇는 자리예요. 서사 다듬기를 켜면 이 자리에만 이어 주는 말이 더해져요.")
                        .textStyleBox(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                Button(model.storyPolished ? "서사를 다듬었어요" : "서사 다듬기 · 코인 \(AppModel.storyPolishCost)") { polish() }
                    .buttonStyle(.primary)
                    .disabled(model.storyPolished || lines.count < 2)
                Button("문장만 엮어 두기 · 무료", action: onSaved)
                    .buttonStyle(.ghost)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .toastCard($toast)
    }

    private func storyCard(_ lines: [Line]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                if i > 0 {
                    Group {
                        if model.storyPolished {
                            Text(Self.bridges[(i - 1) % Self.bridges.count])
                                .textStyleBox(.bodyS)
                                .foregroundStyle(Color.starBright)
                        } else {
                            Text("✦")
                                .textStyleBox(.labelS)
                                .foregroundStyle(Color.starBright)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(line.star.shortDateText) · \(line.star.title)")
                        .textStyleBox(.caption)
                        .foregroundStyle(Color.textTertiary)
                    Text("“\(line.sentence)”")
                        .textStyleBox(.bodyM)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 20)
        .itemCard(seed: "story", minHeight: 0)
    }

    private func tag(_ text: String, gold: Bool) -> some View {
        Text(text)
            .textStyleBox(.labelS)
            .foregroundStyle(gold ? Color.starBright : Color.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(gold ? Color.tintGold : Color.bgSurfaceRaised, in: .capsule)
    }

    /// Mock: spends coins and turns on the bridging lines.
    private func polish() {
        if model.spendCoins(AppModel.storyPolishCost, for: "서사 다듬기") {
            withAnimation(.easeInOut(duration: 0.4)) { model.storyPolished = true }
        } else {
            toast = ToastCardMessage(title: "코인이 조금 부족해요", detail: "코인 충전에서 채울 수 있어요")
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                onNeedCoins()
            }
        }
    }

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

#Preview("77") {
    let model = AppModel()
    model.fillSampleStars()
    return MyNebulaZoomView(onBack: {}, onOpenStar: { _ in }, onOpen: { _ in }).environment(model)
}

#Preview("76") {
    let model = AppModel()
    model.fillSampleStars()
    return GalaxyZoomView(onBack: {}, onOpenStar: { _ in }, onMyNebula: {}, onPlaza: {}).environment(model)
}

#Preview("83") {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaStoryView(onBack: {}, onSaved: {}, onNeedCoins: {}).environment(model)
}

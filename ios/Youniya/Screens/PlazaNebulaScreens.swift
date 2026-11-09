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

// MARK: - 74 Starlight line (nebula)

extension View {
    /// Figma plaza cards (73, 74): surface, Cosmos BG, flat slate border.
    func flatCard(seed: String) -> some View {
        cosmos(seed, in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
    }
}

/// A small on-device first pass. TODO: Replace with the reviewed server filter.

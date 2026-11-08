import SwiftUI

// One way to draw a nebula from its data, used by 08, 70/77, the 80
// collection and the plaza: silhouette places with mood-colored stars,
// guests with gold rings, faint empty places, and thin gold lines. No
// decoration that isn't in the data.

/// What a nebula is made of, wherever it comes from.
struct NebulaFigure: Hashable {
    struct Dot: Hashable {
        var mood: Mood?
        var guestColor: Color?
        var isGuest: Bool { guestColor != nil }
        var color: Color { guestColor ?? mood?.color ?? .starBright }
    }

    /// nil: 직접 그리기 (the dots sit on a spiral and `edges` join them).
    var template: NebulaSilhouette?
    var dots: [Dot]
    var edges: [[Int]] = []
}

extension NebulaFigure {
    /// My nebula: its stars (in `starIDs` order), then its guests.
    init(nebula: DrawnNebula, stars: [StarItem], guests: [GuestStar]) {
        self.init(template: nebula.template,
                  dots: stars.map { Dot(mood: $0.mood) } + guests.map { Dot(guestColor: $0.color) },
                  edges: nebula.template == nil ? nebula.edges : [])
    }

    /// A plaza share's `shape` (silhouette, edges, stars with mood).
    init(plaza shape: PlazaNebulaShape) {
        self.init(template: shape.silhouette.flatMap(NebulaSilhouette.init(rawValue:)),
                  dots: shape.stars.map { Dot(mood: $0.mood) },
                  edges: shape.edges)
    }

    /// Mock plaza nebulae (no server shape): a steady figure from the name.
    static func sample(seed: String, stars: Int = 9) -> NebulaFigure {
        var rng = SeededRandom(seed: seed)
        let basic = NebulaSilhouette.basic
        let template = basic[Int(rng.next(in: 0...Double(basic.count - 1)).rounded())]
        let moods = Mood.allCases
        return NebulaFigure(template: template,
                            dots: (0..<stars).map { _ in Dot(mood: moods[Int(rng.next(in: 0...Double(moods.count - 1)).rounded())]) })
    }

    /// The drawing area inside a canvas of `size`.
    static func area(_ size: CGSize) -> CGRect {
        CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.13, dy: size.height * 0.14)
    }

    /// Where each place sits: the silhouette's places, or a spiral for 직접 그리기
    /// (always enough for every dot).
    func places(in size: CGSize) -> [CGPoint] {
        let rect = Self.area(size)
        if let template { return template.slots(in: rect, count: max(NebulaSilhouette.slotCount, dots.count)) }
        let n = max(dots.count, 1)
        return (0..<n).map { i in
            let r = sqrt((Double(i) + 0.5) / Double(n))
            let a = Double(i) * 2.39996
            return CGPoint(x: rect.midX + rect.width / 2 * r * cos(a), y: rect.midY + rect.height / 2 * r * sin(a))
        }
    }
}

/// The plaza's `shape` for a shared nebula (GET /v1/plaza/nebulae).
struct PlazaNebulaShape: Decodable, Hashable {
    struct Star: Decodable, Hashable {
        var mood: Mood
        var depthLevel: Int?
    }
    var silhouette: String?
    var edges: [[Int]]
    var stars: [Star]
}

/// Draws a `NebulaFigure`. `compact` for cards; 70/77 pass a selection and taps.
struct NebulaFigureView: View {
    var figure: NebulaFigure
    var compact = false
    var selected: Int? = nil
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let places = figure.places(in: geo.size)
            let filled = min(places.count, figure.dots.count)
            let k: CGFloat = compact ? 0.6 : 1
            ZStack(alignment: .topLeading) {
                // Thin gold lines: along the silhouette through the stars, or the drawn edges.
                Path { p in
                    if figure.template != nil, filled > 1 {
                        p.move(to: places[0])
                        for i in 1..<filled { p.addLine(to: places[i]) }
                    } else {
                        for e in figure.edges where e.count == 2 && e.allSatisfy({ $0 < filled }) {
                            p.move(to: places[e[0]])
                            p.addLine(to: places[e[1]])
                        }
                    }
                }
                .stroke(Color.starBright.opacity(0.55), lineWidth: compact ? 0.8 : 1)

                ForEach(places.indices, id: \.self) { i in
                    place(i, filled: filled, k: k).position(places[i])
                }
            }
        }
    }

    @ViewBuilder private func place(_ i: Int, filled: Int, k: CGFloat) -> some View {
        if i < filled {
            let dot = figure.dots[i]
            let size: CGFloat = [8, 10, 9][i % 3] * k
            ZStack {
                if i == selected {
                    // Figma 77 `Target Ring`: dashed, about twice the star.
                    Circle().strokeBorder(Color.starBright, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                        .frame(width: dot.isGuest ? 26 : size * 2.4, height: dot.isGuest ? 26 : size * 2.4)
                }
                if dot.isGuest {
                    Circle().strokeBorder(Color.starBright, lineWidth: 1.2).frame(width: 16 * k, height: 16 * k)
                    Circle().fill(dot.color).frame(width: 8 * k, height: 8 * k)
                } else {
                    Circle().fill(dot.color)
                        .frame(width: size, height: size)
                        .shadow(color: dot.color.opacity(0.8), radius: 5 * k)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(.circle)
            .onTapGesture { onTap?(i) }
            .allowsHitTesting(onTap != nil)
        } else if figure.template != nil {
            // Places still waiting: faint, so the lit stars lead.
            Circle().strokeBorder(Color.textTertiary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 8 * k, height: 8 * k)
        }
    }
}

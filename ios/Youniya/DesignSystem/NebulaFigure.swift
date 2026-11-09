import SwiftUI

// One way to draw a nebula from its data, used by 08, 70/77 and the
// plaza: silhouette places with mood-colored stars,
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


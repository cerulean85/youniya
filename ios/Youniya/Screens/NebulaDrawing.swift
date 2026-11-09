import SwiftUI

// MARK: - Model

/// A nebula the user drew (51–55). Saved on the device.
struct DrawnNebula: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// Silhouette raw value, or nil for 직접 그리기.
    var silhouette: String?
    var starIDs: [UUID]
    /// Index pairs into `starIDs` (직접 그리기 only).
    var edges: [[Int]] = []
    /// Titles of guest stars let into empty slots (85).
    var guests: [String] = []
    /// Live: the guests' plaza share ids.
    var guestShareIDs: [String] = []
    var shared = false
    var createdAt = Date.now
    /// Set when the shape was changed (08 shows the latest of updated/created).
    var updatedAt: Date? = nil
    /// Live: the server's nebula id, set once it is saved there.
    var serverID: String? = nil

    var lastTouched: Date { updatedAt ?? createdAt }
    var template: NebulaSilhouette? { silhouette.flatMap(NebulaSilhouette.init(rawValue:)) }
}

/// 84 silhouettes: Figma `Mini` outlines, drawn in their own box.
enum NebulaSilhouette: String, CaseIterable, Identifiable {
    case whale, lighthouse, tree, bird, flower
    /// v1.1 계절 팩 (84-1), members only. Raw values are the server's ids.
    case cherryBlossom = "cherry_blossom", wave, maple, snowflake

    var id: Self { self }

    static let basic: [NebulaSilhouette] = [.whale, .lighthouse, .tree, .bird, .flower]
    static let season: [NebulaSilhouette] = [.cherryBlossom, .wave, .maple, .snowflake]
    var isSeason: Bool { Self.season.contains(self) }

    var name: String {
        switch self {
        case .whale: "고래"
        case .lighthouse: "등대"
        case .tree: "나무"
        case .bird: "새"
        case .flower: "꽃"
        case .cherryBlossom: "벚꽃"
        case .wave: "파도"
        case .maple: "단풍"
        case .snowflake: "눈송이"
        }
    }

    /// Outline points in the Figma box, in drawing order.
    var outline: (points: [CGPoint], closed: Bool, box: CGSize) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        switch self {
        case .whale:
            return ([p(0, 13), p(10, 3), p(26, 0), p(42, 4), p(52, 13), p(40, 21), p(20, 22)], true, CGSize(width: 52, height: 22))
        case .lighthouse:
            return ([p(0, 176), p(80, 176), p(65, 36), p(40, 0), p(15, 36)], true, CGSize(width: 80, height: 176))
        case .tree:
            return ([p(14, 32), p(14, 20), p(0, 18), p(14, 0), p(28, 18), p(14, 20)], false, CGSize(width: 28, height: 32))
        case .bird:
            return ([p(0, 10), p(14, 0), p(26, 8), p(38, 0), p(52, 10)], false, CGSize(width: 52, height: 10))
        case .flower:
            return ([p(13.3, 0), p(26.6, 9.7), p(21.5, 25.3), p(5.1, 25.3), p(0, 9.7)], true, CGSize(width: 26.6, height: 25.3))
        // Figma 84-1 `Mini`. 벚꽃 and 눈송이 are spokes from the middle, drawn
        // middle → tip → middle so the stars line up along each one.
        case .cherryBlossom:
            let c = p(15.2, 15.2)
            return ([c, p(15.2, 0), c, p(30.4, 10.5), c, p(24.6, 27.5), c, p(5.8, 27.5), c, p(0, 10.5)],
                    false, CGSize(width: 30.4, height: 27.5))
        case .wave:
            return ([p(0, 18), p(10, 6), p(20, 14), p(30, 0), p(40, 12), p(52, 4)], false, CGSize(width: 52, height: 18))
        case .maple:
            return ([p(22, 0), p(30, 10), p(44, 8), p(36, 20), p(40, 32), p(22, 26), p(4, 32), p(8, 20), p(0, 8), p(14, 10)],
                    true, CGSize(width: 44, height: 32))
        case .snowflake:
            let c = p(17, 14.7)
            return ([c, p(34, 14.7), c, p(25.5, 29.4), c, p(8.5, 29.4), c, p(0, 14.7), c, p(8.5, 0), c, p(25.5, 0)],
                    false, CGSize(width: 34, height: 29.4))
        }
    }

    /// Places on the outline (Figma 등대: 12 stars + 6 empty).
    static let slotCount = 18
    /// The server's MIN_NEBULA_STARS: a nebula holds at least 3 of my stars.
    static let minStars = 3
    /// The server's name limit (54 이 성운의 이름은요?).
    static let maxNameLength = 20

    /// The outline scaled into `rect`, keeping its proportions.
    func fitted(in rect: CGRect) -> [CGPoint] {
        let o = outline
        let s = min(rect.width / o.box.width, rect.height / o.box.height)
        let ox = rect.midX - o.box.width * s / 2, oy = rect.midY - o.box.height * s / 2
        return o.points.map { CGPoint(x: ox + $0.x * s, y: oy + $0.y * s) }
    }

    /// `count` points spread evenly along the outline.
    func slots(in rect: CGRect, count: Int = slotCount) -> [CGPoint] {
        var pts = fitted(in: rect)
        if outline.closed, let first = pts.first { pts.append(first) }
        let segs = zip(pts, pts.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        let total = segs.reduce(0, +)
        guard total > 0 else { return [] }
        let step = outline.closed ? total / CGFloat(count) : total / CGFloat(max(1, count - 1))
        return (0..<count).map { i in
            var d = CGFloat(i) * step
            for (k, len) in segs.enumerated() {
                if d <= len || k == segs.count - 1 {
                    let t = len > 0 ? min(1, d / len) : 0
                    let a = pts[k], b = pts[k + 1]
                    return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                }
                d -= len
            }
            return pts.last!
        }
    }

    func path(in rect: CGRect) -> Path {
        let pts = fitted(in: rect)
        return Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            // Figma 나무: the trunk is its own stroke.
            for pt in pts.dropFirst() { p.addLine(to: pt) }
            if outline.closed { p.closeSubpath() }
        }
    }
}

/// A star from the plaza this user resonated with (85). Only color and source come along.
/// TODO: From the plaza API.
struct GuestStar: Identifiable, Hashable {
    var title: String
    var source: String
    var day: String
    var color: Color
    /// Live: the plaza share id sent as a guest (85).
    var shareID: String? = nil
    var id: String { shareID ?? title }

    static let candidates: [GuestStar] = [
        GuestStar(title: "고요한 새벽의 별", source: "비 온 뒤 고래자리", day: "11월 2일", color: .starClear),
        GuestStar(title: "비가 그친 오후", source: "이름 없는 성운", day: "10월 30일", color: .starClear),
        GuestStar(title: "오래 머문 별", source: "어느 밤의 성운", day: "10월 21일", color: .emotionSorrow),
        GuestStar(title: "말없이 건넨 별", source: "느린 강자리", day: "10월 15일", color: .emotionCalm),
    ]
    static let maxGuests = 5
}

// MARK: - Flow

// MARK: - Pieces

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}


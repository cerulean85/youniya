import SwiftUI

// 16장 월별 별자리 (2026-11-08 · 성운 → 별자리): each month has the real
// constellation of its evening sky; the month's stars fill its places in the
// order they were floated, and the rest float around it.

/// One month's fixed shape (Figma 501:13915, 342×300, x/y as 0–1).
struct ConstellationTemplate {
    var key: String
    var name: String
    /// Places in filling order.
    var slots: [CGPoint]
    /// Lines between places (0-based).
    var lines: [[Int]]

    /// By month (1–12). The server sends the same constants (live).
    static let byMonth: [Int: ConstellationTemplate] = {
        func t(_ key: String, _ name: String, _ s: [(Double, Double)], _ l: [[Int]]) -> ConstellationTemplate {
            ConstellationTemplate(key: key, name: name, slots: s.map { CGPoint(x: $0.0, y: $0.1) },
                                  lines: l.map { $0.map { $0 - 1 } })
        }
        return [
            1: t("orion", "오리온자리", [(0.439, 0.117), (0.249, 0.233), (0.658, 0.25), (0.38, 0.5), (0.453, 0.483), (0.526, 0.467), (0.292, 0.8), (0.702, 0.773)],
                 [[1, 2], [1, 3], [2, 4], [3, 6], [4, 5], [5, 6], [4, 7], [6, 8]]),
            2: t("gemini", "쌍둥이자리", [(0.278, 0.167), (0.512, 0.15), (0.292, 0.417), (0.249, 0.667), (0.19, 0.85), (0.512, 0.433), (0.556, 0.683), (0.629, 0.85)],
                 [[1, 2], [1, 3], [3, 4], [4, 5], [2, 6], [6, 7], [7, 8], [3, 6]]),
            3: t("ursa_major", "큰곰자리", [(0.132, 0.4), (0.292, 0.333), (0.439, 0.4), (0.585, 0.467), (0.76, 0.433), (0.789, 0.633), (0.614, 0.667)],
                 [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 4]]),
            4: t("leo", "사자자리", [(0.322, 0.7), (0.424, 0.5), (0.38, 0.35), (0.482, 0.267), (0.585, 0.317), (0.687, 0.45), (0.848, 0.6), (0.687, 0.683)],
                 [[1, 2], [2, 3], [3, 4], [4, 5], [2, 6], [6, 7], [7, 8], [8, 1], [8, 6]]),
            5: t("bootes", "목동자리", [(0.439, 0.833), (0.322, 0.633), (0.351, 0.4), (0.482, 0.233), (0.599, 0.417), (0.57, 0.633)],
                 [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 1]]),
            6: t("scorpius", "전갈자리", [(0.746, 0.15), (0.766, 0.283), (0.731, 0.407), (0.599, 0.45), (0.526, 0.583), (0.503, 0.717), (0.556, 0.833), (0.649, 0.873), (0.731, 0.817)],
                 [[1, 2], [2, 3], [2, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9]]),
            7: t("cygnus", "백조자리", [(0.5, 0.193), (0.5, 0.38), (0.5, 0.553), (0.5, 0.807), (0.301, 0.327), (0.181, 0.247), (0.699, 0.447), (0.819, 0.513)],
                 [[1, 2], [2, 3], [3, 4], [2, 5], [5, 6], [2, 7], [7, 8]]),
            8: t("lyra", "거문고자리", [(0.415, 0.247), (0.535, 0.38), (0.444, 0.5), (0.57, 0.733), (0.699, 0.58)],
                 [[1, 2], [2, 3], [3, 4], [4, 5], [5, 2]]),
            9: t("aquila", "독수리자리", [(0.5, 0.467), (0.444, 0.407), (0.556, 0.527), (0.275, 0.353), (0.725, 0.58), (0.5, 0.767), (0.585, 0.22)],
                 [[4, 2], [2, 1], [1, 3], [3, 5], [1, 6], [1, 7]]),
            10: t("cassiopeia", "카시오페이아자리", [(0.146, 0.367), (0.325, 0.647), (0.5, 0.433), (0.678, 0.687), (0.854, 0.313)],
                  [[1, 2], [2, 3], [3, 4], [4, 5]]),
            11: t("pegasus", "페가수스자리", [(0.395, 0.4), (0.678, 0.4), (0.678, 0.667), (0.395, 0.667), (0.784, 0.3), (0.854, 0.22), (0.251, 0.313), (0.146, 0.367), (0.287, 0.767)],
                  [[1, 2], [2, 3], [3, 4], [4, 1], [2, 5], [5, 6], [1, 7], [7, 8], [4, 9]]),
            12: t("taurus", "황소자리", [(0.497, 0.583), (0.424, 0.533), (0.351, 0.467), (0.161, 0.217), (0.541, 0.517), (0.585, 0.433), (0.716, 0.2), (0.819, 0.717)],
                  [[1, 2], [2, 3], [3, 4], [1, 5], [5, 6], [6, 7], [1, 8]]),
        ]
    }()
}

/// One month's constellation: its places, the stars in them, and the rest.
struct MonthConstellation: Equatable {
    struct Star: Equatable, Identifiable {
        var id: UUID
        var title: String
        var mood: Mood
        var hasStarlight: Bool
        var starlight: Int?
        var createdAt: Date?
        /// 16.1: a 깊은 별 is lit with depth 280+.
        var isDeep = false
        /// The star's shape (server: nil without starlight), for 08-9.
        var shape: StarShapeSpec? = nil
    }
    struct Slot: Equatable {
        var point: CGPoint
        var star: Star?
    }

    /// "2026-11"
    var month: String
    var name: String
    var slots: [Slot]
    var lines: [[Int]]
    /// Stars beyond the places: they float around the figure.
    var extra: [Star]
    /// Live: the server's count of 깊은 별 (lit, depth 280+).
    var deep: Int? = nil

    var filled: Int { slots.filter { $0.star != nil }.count }
    var total: Int { slots.count }
    var isComplete: Bool { filled == total }
    var stars: [Star] { slots.compactMap(\.star) + extra }
    var deepCount: Int { deep ?? stars.filter(\.isDeep).count }
    /// "11월"
    var monthLabel: String { "\(Int(month.suffix(2)) ?? 0)월" }
    /// "11월 · 페가수스자리"
    var title: String { "\(monthLabel) · \(name)" }

    /// A line is gold when both its places are filled.
    func isLit(_ line: [Int]) -> Bool {
        line.count == 2 && line.allSatisfy { $0 < slots.count && slots[$0].star != nil }
    }

    static func monthKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 2026, c.month ?? 1)
    }

    static func shift(_ key: String, by months: Int) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return key }
        let total = parts[0] * 12 + (parts[1] - 1) + months
        return String(format: "%04d-%02d", total / 12, total % 12 + 1)
    }

    /// Mock: built from this device's stars (floated with or without starlight).
    static func local(_ key: String, stars: [StarItem]) -> MonthConstellation {
        let m = Int(key.suffix(2)) ?? 1
        let template = ConstellationTemplate.byMonth[m] ?? ConstellationTemplate.byMonth[11]!
        let mine = stars
            .filter { $0.date.map(monthKey) == key }
            .sorted { ($0.date ?? .now) < ($1.date ?? .now) }
            .map { s in
                Star(id: s.id, title: s.title, mood: s.mood, hasStarlight: s.isFloated,
                     starlight: s.analysis?.starlight, createdAt: s.date,
                     isDeep: (s.analysis?.depthScore ?? 0) >= 280, shape: s.analysis?.shape)
            }
        let slots = template.slots.enumerated().map { i, p in Slot(point: p, star: i < mine.count ? mine[i] : nil) }
        return MonthConstellation(month: key, name: template.name, slots: slots, lines: template.lines,
                                  extra: Array(mine.dropFirst(template.slots.count)))
    }
}

// MARK: - Live (GET /v1/constellations/{YYYY-MM})

private struct ServerConstellation: Decodable {
    struct SlotOut: Decodable {
        var index: Int
        var x: Double
        var y: Double
        var star: StarOut?
    }
    struct StarOut: Decodable {
        var id: String
        var title: String
        var mood: Mood
        var hasStarlight: Bool
        var starlight: Int?
        var createdAt: Date?
        var shape: ShapeOut?
    }
    var month: String
    var name: String
    var slots: [SlotOut]
    var lines: [[Int]]
    var extra: [StarOut]?
    var deep: Int?
}

private extension MonthConstellation.Star {
    init?(_ s: ServerConstellation.StarOut) {
        guard let id = UUID(uuidString: s.id) else { return nil }
        self.init(id: id, title: s.title, mood: s.mood, hasStarlight: s.hasStarlight, starlight: s.starlight,
                  createdAt: s.createdAt, shape: s.shape?.spec)
    }
}

extension AppModel {
    /// 08-3: the month's constellation (live: the server's; mock: this device's stars).
    func constellation(_ key: String) -> MonthConstellation {
        if useLiveAPI, let c = liveConstellations[key] { return c }
        var c = MonthConstellation.local(key, stars: stars)
        // Deep from the device's analysis where the server didn't say.
        for i in c.slots.indices {
            if let s = c.slots[i].star, let star = stars.first(where: { $0.id == s.id }) {
                c.slots[i].star?.isDeep = (star.analysis?.depthScore ?? 0) >= 280
            }
        }
        return c
    }

    /// The first month that can be shown: the earliest star's (live: sign-up,
    /// where the server answers 404 before it).
    var firstConstellationMonth: String {
        let earliest = stars.compactMap(\.date).min() ?? .now
        return MonthConstellation.monthKey(earliest)
    }

    /// Live 83: the month's key sentences, oldest first.
    @MainActor func loadConstellationStory(_ key: String) async -> ServerStory? {
        guard useLiveAPI, isSignedIn else { return nil }
        return try? await APIClient.shared.get("/v1/constellations/\(key)/story")
    }

    @MainActor func loadConstellation(_ key: String) async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let r: ServerConstellation = try await APIClient.shared.get("/v1/constellations/\(key)")
            let slots = r.slots.sorted { $0.index < $1.index }.map {
                MonthConstellation.Slot(point: CGPoint(x: $0.x, y: $0.y), star: $0.star.flatMap(MonthConstellation.Star.init))
            }
            liveConstellations[key] = MonthConstellation(month: r.month, name: r.name, slots: slots, lines: r.lines,
                                                         extra: (r.extra ?? []).compactMap(MonthConstellation.Star.init),
                                                         deep: r.deep)
        } catch let e as APIError where e.status == 404 {
            // Before sign-up or in the future: nothing to show.
        } catch {
            handle(error)
        }
    }
}

import Foundation

// MARK: - Payloads

/// A star shape from the server: {"points": 6, "sharpness": "sharp"}.
struct ShapeOut: Decodable {
    var points: Int
    var sharpness: String
    var spec: StarShapeSpec {
        let s: StarShapeSpec.Sharpness = sharpness == "sharp" ? .sharp : sharpness == "soft" ? .soft : .normal
        return StarShapeSpec(points: points, sharpness: s)
    }
}

private struct PlazaStarItem: Decodable {
    var id: String
    var name: String
    /// Null while the owner picks a new 대표 문장 (12-3).
    var quote: String?
    var mood: Mood
    var depthLevel: Int?
    var shape: ShapeOut?
    var resonated: Bool
    var beside: Bool
    /// 09-3 row: when it was shared.
    var createdAt: Date?
    /// 75-3: shared with its whole text (shares from 2026-11-08).
    var fullText: Bool?
    /// 15장 / 17.2 (newer servers).
    var nickname: String?
    var title: String?
    var hasStarlight: Bool?
    var receiveLines: Bool?
    var lineLeft: Bool?
}

private struct Items<T: Decodable>: Decodable { var items: [T] }

/// 19: the 대표 문장 and, from 2026-11-08, the whole text (`full_text`).
private struct ShareIn: Encodable { var quote: String; var fullText = true }

// MARK: - Mapping

private extension PlazaNebula {
    init(_ s: PlazaStarItem, order: Int, similarity: Double) {
        var rng = SeededRandom(seed: s.id)
        self.init(name: s.name, line: s.quote ?? "", pattern: rng.next(in: 0...1) < 0.5 ? .a : .b,
                  similarity: similarity, order: order, serverID: s.id,
                  starShape: s.shape?.spec, mood: s.mood, depthLevel: s.depthLevel,
                  sharedAt: s.createdAt, fullText: s.fullText ?? false,
                  nickname: s.nickname, starTitle: s.title, hasStarlight: s.hasStarlight ?? true,
                  receiveLines: s.receiveLines ?? true, lineLeft: s.lineLeft ?? false)
    }
}

// MARK: - AppModel (live plaza)

extension AppModel {
    /// 09-5: the plaza's stars, mock samples or the server's. Mock: a blocked
    /// keeper's star is hidden here (75-2); live, the server leaves it out.
    var plazaStarItems: [PlazaNebula] {
        useLiveAPI ? plazaStarsLive : PlazaNebula.samples.filter { !blockedNebulaNames.contains($0.name) }
    }

    /// Live 09-5: loads the star feeds. "새로 뜬 것" gives `order`, "나와 결이 비슷한" gives
    /// `similarity`, so the screens keep sorting the way they do with samples.
    @MainActor func loadPlaza() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            async let newStars: Items<PlazaStarItem> = APIClient.shared.get("/v1/plaza/stars", query: ["sort": "new"])
            async let similarStars: Items<PlazaStarItem> = APIClient.shared.get("/v1/plaza/stars", query: ["sort": "similar"])
            async let besideStars: Items<PlazaStarItem> = APIClient.shared.get("/v1/plaza/stars", query: ["sort": "beside"])
            let (ns, ss, bs) = try await (newStars, similarStars, besideStars)

            let starRank = Dictionary(ss.items.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
            plazaStarsLive = ns.items.enumerated().map { i, s in
                PlazaNebula(s, order: i, similarity: 1 - Double(starRank[s.id] ?? ss.items.count) / Double(max(1, ss.items.count)))
            }
            // 「곁에 둔 것」: the server's order (most recently kept first).
            plazaStarsBeside = bs.items.enumerated().map { i, s in PlazaNebula(s, order: i, similarity: 0) }
            // One "resonated" set of star names; a resonance also keeps the star beside.
            for s in ns.items where s.resonated { resonated.insert(s.name) }
        } catch {
            handle(error)
        }
    }

    /// Live: sends a resonance toggle. It also keeps the star beside
    /// (「곁에 둔 것」), as the app shows both as one "곁에 둔" state.
    @MainActor func sendResonance(key: String, on: Bool) {
        guard let id = (plazaStarsLive + plazaStarsBeside).first(where: { $0.name == key })?.serverID else { return }
        Task { @MainActor in
            do {
                let method = on ? "PUT" : "DELETE"
                try await APIClient.shared.sendRaw(method, "/v1/plaza/star/\(id)/resonance")
                try await APIClient.shared.sendRaw(method, "/v1/plaza/star/\(id)/beside")
            } catch {
                if on { resonated.remove(key) } else { resonated.insert(key) }
                handle(error)
            }
        }
    }

    /// Live 19/20: shares a floated star with its whole text and one sentence
    /// of it as the 대표 문장, the one picked on 19-1 (sent as written; the
    /// server hides phone numbers and emails). Without a pick (20): the longest.
    @MainActor func shareStarLive(_ id: StarItem.ID, quote picked: String? = nil) async -> Bool {
        guard let star = stars.first(where: { $0.id == id }) else { return false }
        let quote = picked ?? star.body.shareSentences.max(by: { $0.count < $1.count }) ?? String(star.body.prefix(300))
        do {
            try await APIClient.shared.sendRaw("PUT", "/v1/stars/\(id.apiID)/share", body: ShareIn(quote: quote))
            if let i = stars.firstIndex(where: { $0.id == id }) {
                stars[i].sharedToPlaza = true
                stars[i].shareQuoteMissing = nil
            }
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// Live 75-3: the whole star (`GET /v1/plaza/stars/{id}`): title and body,
    /// contacts masked. Nil for one-sentence shares or when it fails.
    @MainActor func plazaStarText(_ shareID: String) async -> (title: String, body: String)? {
        struct Detail: Decodable { var titleMasked: String?; var bodyMasked: String? }
        guard let d: Detail = try? await APIClient.shared.get("/v1/plaza/stars/\(shareID)"),
              let body = d.bodyMasked else { return nil }
        return (d.titleMasked ?? "", body)
    }

    /// 76-1 별지기 페이지: GET /v1/keepers/{nickname} (only their shared stars).
    /// Nil when it can't be shown (blocked either way: 404). Mock: the samples.
    @MainActor func keeperStars(_ nickname: String) async -> [PlazaNebula]? {
        guard useLiveAPI else { return plazaStarItems.filter { $0.nickname == nickname } }
        struct Page: Decodable { var nickname: String; var mine: Bool?; var items: [PlazaStarItem] }
        do {
            let r: Page = try await APIClient.shared.get("/v1/keepers/\(nickname)")
            return r.items.enumerated().map { i, s in PlazaNebula(s, order: i, similarity: 0) }
        } catch let e as APIError where e.status == 404 {
            return nil
        } catch {
            handle(error)
            return nil
        }
    }

    /// Live: takes one star back from the plaza.
    @MainActor func unshareStarLive(_ id: StarItem.ID) async {
        do {
            try await APIClient.shared.delete("/v1/stars/\(id.apiID)/share")
            if let i = stars.firstIndex(where: { $0.id == id }) { stars[i].sharedToPlaza = false }
        } catch {
            handle(error)
        }
    }
}

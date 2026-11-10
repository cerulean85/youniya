import Foundation

// MARK: - Payloads

/// `star_view` on the server. `body` and `analysis` come only from the detail
/// and create endpoints, not from the list.
struct ServerStar: Decodable {
    var id: String
    var title: String
    var mood: Mood
    /// 17.5: every mood, the color first (newer servers).
    var moods: [Mood]?
    var state: String          // "floated" | "kept"
    var createdAt: Date
    var starlight: Int?
    var rewriteOf: String?
    var analysisFailed: Bool
    var shared: Bool
    /// 10.1 별빛 한 줄 received (detail only).
    var lineCount: Int?
    /// 별 잇기: the stars joined to this one (detail only).
    var linkedStars: [LinkedOut]?
    struct LinkedOut: Decodable { var id: String }
    var body: String?
    var analysis: ServerAnalysis?
    /// 17.6: how the starlight was read.
    var prismVersion: String?
}

/// The prism result. Only the fields the app shows today are read.
struct ServerAnalysis: Decodable {
    struct Share: Decodable { var mood: Mood; var share: Int }
    var starlight: Int
    var depth: Double
    var clarity: Double
    var weight: Double
    var depthLevel: Int?
    var moods: [Share]
    var observation: String
    var telescopeTeaser: String?
    var rewriteQuestion: String?
    /// 17.3 별빛 풀이 (newer servers; nil until then).
    var depthReason: String?
    var clarityReason: String?
    var weightReason: String?
    var interpretation: String?
}

/// POST /v1/stars and /v1/stars/{id}/float
struct StarCreated: Decodable {
    struct Crisis: Decodable {}
    var star: ServerStar
    /// 37: set when the writing shows a crisis signal; the star is then kept unscored.
    var crisis: Crisis?
    /// PATCH only: the shared 대표 문장 is gone from the edited text (12-3);
    /// the share stays, with no quote until one is picked again.
    var quoteMissing: Bool?
}

private struct StarList: Decodable {
    var items: [ServerStar]
    var nextBefore: String?
}

private struct StarIn: Encodable {
    var mood: Mood
    /// 14 별 잇기 · 새 별 쓰기: the stars the new one is joined to.
    var linkTo: [String]? = nil
    /// 17.5 (2026-11-09): every mood, the color first. Older servers ignore it.
    var moods: [Mood]
    var title: String
    var body: String
    var mode: String
    var rewriteOf: String?
}

private struct DraftIn: Encodable {
    var mood: Mood
    var title: String
    var body: String
}

private struct DraftSaved: Decodable { var saved: Bool }

private struct ServerDraft: Decodable {
    var mood: Mood
    var title: String
    var body: String
}

/// The server's ids are lowercase UUID strings; Swift prints uppercase.
extension UUID {
    var apiID: String { uuidString.lowercased() }
}

// MARK: - Mapping

extension StarItem {
    /// Builds a star from the server, keeping app-only fields (the telescope
    /// report, until that moves to the API) from `local`.
    init?(_ s: ServerStar, keeping local: StarItem? = nil) {
        guard let id = UUID(uuidString: s.id) else { return nil }
        var analysis = s.analysis.map(StarAnalysis.init)
        // "prism-v1-2026-11" → "별빛 프리즘 v1" (older stars: none, and no 풀이).
        analysis?.prismVersion = s.prismVersion.map { v in
            let parts = v.split(separator: "-")
            return parts.count > 1 ? "별빛 프리즘 \(parts[1])" : "별빛 프리즘"
        }
        self.init(
            id: id,
            title: s.title,
            dateText: StarItem.dateText(s.createdAt),
            state: s.state == "floated" ? .floated(starlight: s.starlight ?? analysis?.starlight) : .kept,
            mood: s.mood,
            extraMoods: s.moods.map { Array($0.dropFirst()) }.flatMap { $0.isEmpty ? nil : $0 } ?? local?.extraMoods,
            body: s.body ?? local?.body ?? "",
            analysis: analysis ?? local?.analysis,
            report: local?.report,
            createdAt: s.createdAt,
            rewriteOf: s.rewriteOf.flatMap(UUID.init(uuidString:)),
            sharedToPlaza: s.shared,
            lineCount: s.lineCount ?? local?.lineCount,
            linkedIDs: s.linkedStars.map { $0.compactMap { UUID(uuidString: $0.id) } } ?? local?.linkedIDs,
            // Known only from the edit's answer; kept until a new pick.
            shareQuoteMissing: s.shared ? local?.shareQuoteMissing : nil
        )
    }

    /// e.g. "11월 3일 · 21:30"
    static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 · HH:mm"
        return f.string(from: date)
    }
}

extension StarAnalysis {
    init(_ a: ServerAnalysis) {
        self.init(
            starlight: a.starlight,
            depth: a.depth,
            clarity: a.clarity,
            weight: a.weight,
            observation: a.observation,
            telescopeTeaser: a.telescopeTeaser ?? "",
            tones: a.moods.sorted { $0.share > $1.share }.map(\.mood),
            depthReason: a.depthReason,
            clarityReason: a.clarityReason,
            weightReason: a.weightReason,
            interpretation: a.interpretation,
            rewriteQuestion: a.rewriteQuestion
        )
    }
}

// MARK: - AppModel (live stars)

extension AppModel {
    /// Live: replaces `stars` with the server's. The list has no bodies, so each
    /// star's detail is fetched too. TODO: Page with `before` past 200 stars.
    @MainActor func loadStars() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let list: StarList = try await APIClient.shared.get("/v1/stars", query: ["limit": "200"])
            let details = try await withThrowingTaskGroup(of: ServerStar.self) { group in
                for item in list.items {
                    group.addTask { try await APIClient.shared.get("/v1/stars/\(item.id)") }
                }
                var out: [String: ServerStar] = [:]
                for try await s in group { out[s.id] = s }
                return out
            }
            let previous = Dictionary(stars.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            stars = list.items.compactMap { item in
                let s = details[item.id] ?? item
                return StarItem(s, keeping: UUID(uuidString: s.id).flatMap { previous[$0] })
            }
        } catch {
            handle(error)
        }
    }

    /// Live 05/14: saves the star on the server, which analyses it when floated.
    /// Returns the saved star and whether 37 Crisis Care should show.
    /// The server clears the draft; so does this.
    @MainActor func publishLive(_ d: StarDraft, floated: Bool, rewriteOf: StarItem.ID? = nil,
                                linkTo: [StarItem.ID] = []) async throws -> (StarItem, crisis: Bool) {
        // mode stays float/keep until the server ships lit/unlit (same meaning).
        var body = StarIn(mood: d.mood, moods: d.moods, title: d.title.trimmingCharacters(in: .whitespacesAndNewlines),
                          body: d.body, mode: floated ? "float" : "keep", rewriteOf: rewriteOf?.apiID)
        body.linkTo = linkTo.isEmpty ? nil : linkTo.map(\.apiID)
        let r: StarCreated = try await APIClient.shared.post("/v1/stars", body: body)
        guard let star = StarItem(r.star) else { throw APIError.badResponse }
        stars.insert(star, at: 0)
        if rewriteOf == nil { saveDraft(StarDraft()) }
        return (star, r.crisis != nil)
    }

    /// Live 36 "다시 시도": analyses a star that the server kept after a failed analysis.
    @MainActor func floatAgain(_ id: StarItem.ID) async throws -> StarItem {
        let r: StarCreated = try await APIClient.shared.post("/v1/stars/\(id.apiID)/float", body: [String: String]())
        guard let star = StarItem(r.star, keeping: stars.first { $0.id == id }) else { throw APIError.badResponse }
        if let i = stars.firstIndex(where: { $0.id == id }) { stars[i] = star }
        return star
    }

    /// 글 수정: `PATCH /v1/stars/{id}`. A star without starlight changes mood,
    /// title and body; a star with starlight is locked (17, 2026-11-09), so only
    /// its title goes (`body` nil; the server answers 409 star_locked otherwise).
    /// Mock: on device. Returns nil when it failed, or whether the new writing
    /// shows a crisis signal (37).
    @MainActor func editStar(_ id: StarItem.ID, mood: Mood?, title: String, body: String?) async -> Bool? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        func applyLocally() {
            guard let i = stars.firstIndex(where: { $0.id == id }) else { return }
            stars[i].title = t.isEmpty ? "제목 없는 별" : t
            if let body { stars[i].body = body }
            if let mood { stars[i].mood = mood }
        }
        guard useLiveAPI else {
            applyLocally()
            return CrisisSignal.detected(in: t + " " + (body ?? ""))
        }
        struct Patch: Encodable { var title: String; var body: String?; var mood: Mood? }
        do {
            // 200 {star, crisis, …}: the floated star's light, shape and report stay as they were.
            let r: StarCreated = try await APIClient.shared.send("PATCH", "/v1/stars/\(id.apiID)",
                                                                 body: Patch(title: t, body: body, mood: mood))
            if let i = stars.firstIndex(where: { $0.id == id }), var s = StarItem(r.star, keeping: stars[i]) {
                if r.quoteMissing == true && s.isShared { s.shareQuoteMissing = true }
                stars[i] = s
            } else {
                applyLocally()
            }
            return r.crisis != nil
        } catch {
            handle(error)
            return nil
        }
    }

    /// Live 15: deletes on the server first, then here.
    @MainActor func deleteStarLive(_ id: StarItem.ID) async {
        do {
            try await APIClient.shared.delete("/v1/stars/\(id.apiID)")
            stars.removeAll { $0.id == id }
        } catch let e as APIError where e.code == "not_found" {
            stars.removeAll { $0.id == id }
        } catch {
            handle(error)
        }
    }

    /// Live 34: mirrors the autosaved draft to the server (best effort).
    func syncDraft(_ d: StarDraft) {
        guard useLiveAPI, isSignedIn else { return }
        Task {
            if d.isEmpty {
                try? await APIClient.shared.delete("/v1/drafts/current")
            } else {
                let _: DraftSaved? = try? await APIClient.shared.put(
                    "/v1/drafts/current", body: DraftIn(mood: d.mood, title: d.title, body: d.body))
            }
        }
    }

    /// Live: takes the server's draft when there is none on this device.
    @MainActor func loadDraft() async {
        guard useLiveAPI, isSignedIn, draft.isEmpty else { return }
        if let d: ServerDraft? = try? await APIClient.shared.get("/v1/drafts/current"), let d {
            saveDraft(StarDraft(mood: d.mood, title: d.title, body: d.body))
        }
    }
}

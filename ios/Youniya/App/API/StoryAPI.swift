import SwiftUI

// MARK: - 83 성운 이야기

/// `GET /v1/nebulae/{id}/story`: each star's key sentence in time order, and the
/// bridging lines once "서사 다듬기" is done. The sentences are never changed.
struct ServerStory: Decodable {
    struct Entry: Decodable {
        var starId: String
        var title: String
        var sentence: String
    }
    var entries: [Entry]
    var bridges: [String]?
    var polished: Bool
    /// Only after polishing.
    var coins: Int?
}

// MARK: - 85 손님별

private struct GuestCandidates: Decodable {
    struct Item: Decodable {
        var shareId: String
        var name: String
        var mood: Mood
        var resonatedAt: Date
    }
    var items: [Item]
}

// MARK: - 69 오늘 밤

private struct Tonight: Decodable {
    var count: Int
    var mine: Int
}

extension AppModel {
    /// The newest drawn nebula's server id (83 tells its story).
    var storyNebulaID: String? { drawnNebulae.last?.serverID }

    /// Live 83: the story of my newest nebula, or nil (mock, or nothing drawn yet).
    @MainActor func loadStory() async -> ServerStory? {
        guard useLiveAPI, let id = storyNebulaID else { return nil }
        do {
            return try await APIClient.shared.get("/v1/nebulae/\(id)/story")
        } catch {
            handle(error)
            return nil
        }
    }

    /// Live 83 서사 다듬기 · 코인 20: charged by the server only when it works.
    /// Throws for 402 (not enough coins) so 83 can show its shortage toast.
    @MainActor func polishStory() async throws -> ServerStory? {
        guard let id = storyNebulaID else { return nil }
        let r: ServerStory = try await APIClient.shared.post("/v1/nebulae/\(id)/story/polish", body: [String: String]())
        if let c = r.coins { coins = c }
        storyPolished = r.polished
        await loadCoins()
        return r
    }

    /// 85: the plaza stars I left a resonance on (live), or the mock samples.
    var guestCandidates: [GuestStar] { useLiveAPI ? guestCandidatesLive : GuestStar.candidates }

    @MainActor func loadGuestCandidates() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let r: GuestCandidates = try await APIClient.shared.get("/v1/nebulae/guest-candidates")
            let f = DateFormatter()
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = "M월 d일"
            guestCandidatesLive = r.items.map {
                GuestStar(title: $0.name, source: "우주 광장", day: f.string(from: $0.resonatedAt),
                          color: $0.mood.color, shareID: $0.shareId)
            }
        } catch {
            handle(error)
        }
    }

    /// Live 69: stars floated today across everyone (Korean day).
    @MainActor func loadTonight() async {
        guard useLiveAPI, isSignedIn else { return }
        if let t: Tonight = try? await APIClient.shared.get("/v1/plaza/tonight") {
            tonightCount = t.count
            tonightMine = t.mine
        }
    }
}

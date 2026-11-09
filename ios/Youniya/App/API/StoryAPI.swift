import SwiftUI

// MARK: - 83 성운 이야기

/// `GET /v1/nebulae/{id}/story`: each star's key sentence in time order.
/// The sentences are never changed.
struct ServerStory: Decodable {
    struct Entry: Decodable {
        var starId: String
        var title: String
        var sentence: String
    }
    var entries: [Entry]
}

// MARK: - 85 손님별

private struct GuestCandidates: Decodable {
    struct Item: Decodable {
        var shareId: String
        var name: String
        var mood: Mood
        /// Null for a guest let in from 75 without a resonance.
        var resonatedAt: Date?
        var inNebula: Bool?
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
                GuestStar(title: $0.name, source: "우주 광장", day: $0.resonatedAt.map(f.string(from:)) ?? "손님별",
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

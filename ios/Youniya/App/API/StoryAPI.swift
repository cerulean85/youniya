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
    var guestCandidates: [GuestStar] {
        let base = useLiveAPI ? guestCandidatesLive : GuestStar.candidates
        // Stars let in from 75 stay candidates (85), even before the server lists them.
        return base + adoptedGuests.filter { g in !base.contains { $0.id == g.id || $0.title == g.title } }
    }

    enum GuestAdoptResult { case added(String), noNebula, full, already }

    /// 75 「손님별로 들어와 있어요」: this plaza star is already in the nebula 08 shows.
    func isGuestInLatestNebula(_ g: GuestStar) -> Bool {
        guard let n = latestNebula else { return false }
        return n.guests.contains(g.title) || (g.shareID.map(n.guestShareIDs.contains) ?? false)
    }

    /// 75 「내 성운에 손님별로 들이기」: adds the star to the nebula 08 shows
    /// (live: PATCH /v1/nebulae/{id} with its guest_share_ids). Up to five
    /// guests, and only into a silhouette's empty places.
    func adoptGuest(_ g: GuestStar) -> GuestAdoptResult {
        guard var n = latestNebula else { return .noNebula }
        if isGuestInLatestNebula(g) { return .already }
        guard n.template != nil, n.guests.count < GuestStar.maxGuests,
              n.starIDs.count + n.guests.count < NebulaSilhouette.slotCount else { return .full }
        n.guests.append(g.title)
        if let id = g.shareID { n.guestShareIDs.append(id) }
        if !adoptedGuests.contains(where: { $0.id == g.id }) { adoptedGuests.append(g) }
        updateDrawnNebula(n)
        return .added(n.name)
    }

    @MainActor func loadGuestCandidates() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            // include_guests: also the guests already in my nebulae (let in from 75).
            let r: GuestCandidates = try await APIClient.shared.get("/v1/nebulae/guest-candidates",
                                                                     query: ["include_guests": "true"])
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

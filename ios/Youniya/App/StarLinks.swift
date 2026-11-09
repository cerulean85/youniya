import Foundation

// 11.5 별 잇기 (2026-11-08): stars joined both ways, without a direction. One
// star can join many; a link can be undone at any time (the texts stay).

private struct LinksIn: Encodable { var starIds: [String] }
private struct LinksOut: Decodable {
    struct Linked: Decodable { var id: String }
    var linkedStars: [Linked]
}

extension AppModel {
    /// The stars joined to this one, newest first.
    func linkedStars(_ id: StarItem.ID) -> [StarItem] {
        let ids = Set(stars.first { $0.id == id }?.linkedIDs ?? [])
        return stars.filter { ids.contains($0.id) }.sorted { ($0.date ?? .now) > ($1.date ?? .now) }
    }

    /// Joins on this device, both ways.
    func linkLocally(_ id: StarItem.ID, _ others: [StarItem.ID]) {
        for other in others where other != id {
            if let i = stars.firstIndex(where: { $0.id == id }) {
                stars[i].linkedIDs = Array(Set((stars[i].linkedIDs ?? []) + [other]))
            }
            if let j = stars.firstIndex(where: { $0.id == other }) {
                stars[j].linkedIDs = Array(Set((stars[j].linkedIDs ?? []) + [id]))
            }
        }
    }

    private func unlinkLocally(_ id: StarItem.ID, _ other: StarItem.ID) {
        if let i = stars.firstIndex(where: { $0.id == id }) { stars[i].linkedIDs?.removeAll { $0 == other } }
        if let j = stars.firstIndex(where: { $0.id == other }) { stars[j].linkedIDs?.removeAll { $0 == id } }
    }

    /// 12-7 「N개 별 잇기」: POST /v1/stars/{id}/links (mock: on device).
    @MainActor func linkStars(_ id: StarItem.ID, _ others: [StarItem.ID]) async -> Bool {
        guard useLiveAPI else { linkLocally(id, others); return true }
        do {
            let r: LinksOut = try await APIClient.shared.post("/v1/stars/\(id.apiID)/links",
                                                              body: LinksIn(starIds: others.map(\.apiID)))
            let ids = r.linkedStars.compactMap { UUID(uuidString: $0.id) }
            if let i = stars.firstIndex(where: { $0.id == id }) { stars[i].linkedIDs = ids }
            for other in others { linkLocally(other, [id]) }
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// 「연결 끊기」: DELETE /v1/stars/{id}/links/{other} (mock: on device).
    @MainActor func unlinkStars(_ id: StarItem.ID, _ other: StarItem.ID) async {
        guard useLiveAPI else { unlinkLocally(id, other); return }
        do {
            try await APIClient.shared.delete("/v1/stars/\(id.apiID)/links/\(other.apiID)")
            unlinkLocally(id, other)
        } catch {
            handle(error)
        }
    }
}

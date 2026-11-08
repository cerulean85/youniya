import Foundation

// MARK: - Payloads

private struct NebulaIn: Encodable {
    var name: String
    var silhouette: String?
    var starIds: [String]
    var edges: [[Int]]
    /// 85: plaza share ids from GET /v1/nebulae/guest-candidates.
    var guestShareIds: [String] = []
}

/// 08 「모양 바꾸기」 PATCH: `silhouette` is always sent, so null switches to
/// 직접 그리기 (left out it would stay). `star_ids` always comes with `edges`.
private struct NebulaPatch: Encodable {
    var name: String
    var silhouette: String?
    var starIds: [String]
    var edges: [[Int]]
    var guestShareIds: [String]

    enum CodingKeys: String, CodingKey { case name, silhouette, starIds, edges, guestShareIds }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(silhouette, forKey: .silhouette)  // null when 직접 그리기
        try c.encode(starIds, forKey: .starIds)
        try c.encode(edges, forKey: .edges)
        try c.encode(guestShareIds, forKey: .guestShareIds)
    }
}

private struct NebulaCreated: Decodable { var id: String }

private struct NebulaList: Decodable {
    struct Mine: Decodable { var id: String; var createdAt: Date?; var updatedAt: Date? }
    var mine: [Mine]
}

private struct NebulaDetail: Decodable {
    /// `index`: the star's place in star_ids, which `edges` refer to.
    struct Star: Decodable { var id: String; var index: Int? }
    struct Guest: Decodable { var shareId: String; var name: String }
    var id: String
    var name: String
    var silhouette: String?
    var edges: [[Int]]
    var stars: [Star]
    var guests: [Guest]?
    var shared: Bool
    var createdAt: Date
    var updatedAt: Date?
    var plazaUpdated: Bool?
}

private struct NebulaShareIn: Encodable {
    var receiveLines: Bool
    var quote: String?
}

// MARK: - AppModel (live nebulae)

extension AppModel {
    /// Live 54 저장하기: creates the nebula on the server. The saved copy gets the
    /// server id; 55/71 wait for it when they come right after.
    @MainActor func createNebulaLive(_ n: DrawnNebula) {
        let task = Task { @MainActor () -> String? in
            do {
                let r: NebulaCreated = try await APIClient.shared.post("/v1/nebulae", body: NebulaIn(
                    name: n.name, silhouette: n.silhouette, starIds: n.starIDs.map(\.apiID), edges: n.edges,
                    guestShareIds: n.guestShareIDs))
                if let i = drawnNebulae.firstIndex(where: { $0.id == n.id }) { drawnNebulae[i].serverID = r.id }
                return r.id
            } catch {
                handle(error)
                return nil
            }
        }
        nebulaCreates[n.id] = task
    }

    /// Live 08 「모양 바꾸기」: `PATCH /v1/nebulae/{id}` with the new shape, stars,
    /// guests and name. A nebula on the plaza changes there too.
    @MainActor func updateNebulaLive(_ n: DrawnNebula) async {
        guard let serverID = await serverID(of: n.id) else { return }
        do {
            let r: NebulaDetail = try await APIClient.shared.send("PATCH", "/v1/nebulae/\(serverID)", body: NebulaPatch(
                name: n.name, silhouette: n.silhouette, starIds: n.starIDs.map(\.apiID), edges: n.edges,
                guestShareIds: n.guestShareIDs))
            if let i = drawnNebulae.firstIndex(where: { $0.id == n.id }) { drawnNebulae[i].updatedAt = r.updatedAt ?? .now }
            // A crisis-signal star keeps the plaza copy as it was.
            if r.plazaUpdated == true {
                apiMessage = "광장의 성운도 새 모양으로 바뀌었어요"
            } else if n.shared && r.plazaUpdated == false {
                apiMessage = "성운 모양을 바꿨어요. 우주 광장에는 이전 모양이 그대로 남아 있어요."
            }
        } catch {
            handle(error)
        }
    }

    /// The server id of a drawn nebula, waiting for its creation if needed.
    @MainActor private func serverID(of id: DrawnNebula.ID) async -> String? {
        if let s = drawnNebulae.first(where: { $0.id == id })?.serverID { return s }
        return await nebulaCreates[id]?.value
    }

    /// Live 55 우주 광장에 나누기 / 71 하늘에 띄우기.
    /// `quote`: the line picked on 71-1, as written in one of the nebula's stars;
    /// the server masks it again.
    @MainActor func shareNebulaLive(_ id: DrawnNebula.ID, receiveLines: Bool = true, quote: String? = nil) async -> Bool {
        guard let serverID = await serverID(of: id) else { return false }
        do {
            try await APIClient.shared.sendRaw("PUT", "/v1/nebulae/\(serverID)/share",
                                               body: NebulaShareIn(receiveLines: receiveLines, quote: quote))
            if let i = drawnNebulae.firstIndex(where: { $0.id == id }) { drawnNebulae[i].shared = true }
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// Live: my drawn nebulae from the server (another device may have drawn some).
    @MainActor func loadNebulae() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let list: NebulaList = try await APIClient.shared.get("/v1/nebulae")
            var result: [DrawnNebula] = []
            for item in list.mine {
                // Keep this device's copy unless it was reshaped since (maybe elsewhere).
                if let local = drawnNebulae.first(where: { $0.serverID == item.id }),
                   (item.updatedAt ?? .distantPast) <= (local.updatedAt ?? local.createdAt) {
                    result.append(local)
                    continue
                }
                let d: NebulaDetail = try await APIClient.shared.get("/v1/nebulae/\(item.id)")
                // edges are indices into star_ids: order the stars by their index.
                let ordered = d.stars.enumerated().sorted { ($0.element.index ?? $0.offset) < ($1.element.index ?? $1.offset) }
                let localID = drawnNebulae.first { $0.serverID == item.id }?.id
                result.append(DrawnNebula(id: localID ?? UUID(), name: d.name, silhouette: d.silhouette,
                                          starIDs: ordered.compactMap { UUID(uuidString: $0.element.id) },
                                          edges: d.edges,
                                          guests: d.guests?.map(\.name) ?? [],
                                          guestShareIDs: d.guests?.map(\.shareId) ?? [],
                                          shared: d.shared, createdAt: d.createdAt, updatedAt: d.updatedAt,
                                          serverID: d.id))
            }
            // Oldest first, like the local list (the newest is `nebulaName`).
            drawnNebulae = result.sorted { $0.createdAt < $1.createdAt }
        } catch {
            handle(error)
        }
    }
}

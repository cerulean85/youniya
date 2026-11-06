import Foundation

// MARK: - Payloads

private struct NebulaIn: Encodable {
    var name: String
    var silhouette: String?
    var starIds: [String]
    var edges: [[Int]]
    /// TODO: 85 guests from GET /v1/nebulae/guest-candidates (plaza share ids).
    var guestShareIds: [String] = []
}

private struct NebulaCreated: Decodable { var id: String }

private struct NebulaList: Decodable {
    struct Mine: Decodable { var id: String }
    var mine: [Mine]
}

private struct NebulaDetail: Decodable {
    struct Star: Decodable { var id: String }
    var id: String
    var name: String
    var silhouette: String?
    var edges: [[Int]]
    var stars: [Star]
    var shared: Bool
    var createdAt: Date
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
                    name: n.name, silhouette: n.silhouette, starIds: n.starIDs.map(\.apiID), edges: n.edges))
                if let i = drawnNebulae.firstIndex(where: { $0.id == n.id }) { drawnNebulae[i].serverID = r.id }
                return r.id
            } catch {
                handle(error)
                return nil
            }
        }
        nebulaCreates[n.id] = task
    }

    /// The server id of a drawn nebula, waiting for its creation if needed.
    @MainActor private func serverID(of id: DrawnNebula.ID) async -> String? {
        if let s = drawnNebulae.first(where: { $0.id == id })?.serverID { return s }
        return await nebulaCreates[id]?.value
    }

    /// Live 55 우주 광장에 나누기 / 71 하늘에 띄우기.
    /// `quote`: when 71 "가린 한 문장 함께 보이기" is on, a sentence from the nebula's
    /// own stars; the server masks it again.
    @MainActor func shareNebulaLive(_ id: DrawnNebula.ID, receiveLines: Bool = true, withQuote: Bool = false) async -> Bool {
        guard let serverID = await serverID(of: id),
              let nebula = drawnNebulae.first(where: { $0.id == id }) else { return false }
        var quote: String?
        if withQuote {
            // TODO: Let the user pick the sentence ("직접 골라 가린 한 줄").
            quote = stars.filter { nebula.starIDs.contains($0.id) }
                .flatMap { $0.body.split(whereSeparator: { ".!?\n".contains($0) }) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count <= 300 }
                .max(by: { $0.count < $1.count })
        }
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
                if let local = drawnNebulae.first(where: { $0.serverID == item.id }) {
                    result.append(local)
                    continue
                }
                let d: NebulaDetail = try await APIClient.shared.get("/v1/nebulae/\(item.id)")
                result.append(DrawnNebula(name: d.name, silhouette: d.silhouette,
                                          starIDs: d.stars.compactMap { UUID(uuidString: $0.id) },
                                          edges: d.edges, shared: d.shared, createdAt: d.createdAt,
                                          serverID: d.id))
            }
            // Oldest first, like the local list (the newest is `nebulaName`).
            drawnNebulae = result.sorted { $0.createdAt < $1.createdAt }
        } catch {
            handle(error)
        }
    }
}

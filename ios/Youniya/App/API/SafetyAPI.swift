import Foundation

// App Review: blocks (1.2), star and nebula reports, and the invite login (2.1).
// The server hides a blocked person's plaza content both ways.

private struct BlockIn: Encodable {
    var lineId: String?
    var starId: String?
    var nebulaId: String?
}

private struct BlockOut: Decodable {
    var id: String
    var createdAt: Date
    var source: BlockedKeeper.Source
}

private struct BlockList: Decodable { var items: [BlockOut] }

private struct PlazaReportIn: Encodable {
    var reason: String
    var block: Bool
}

private struct PlazaReportOut: Decodable {
    var reported: Bool
    var blocked: Bool?
}

private struct InviteIn: Encodable {
    var login: String
    var password: String
}

/// What a block or report points at on the server.
enum PlazaTarget {
    case line(String), star(String), nebula(String)
}

extension BlockedKeeper {
    fileprivate init(_ b: BlockOut) {
        self.init(id: b.id, source: b.source, blockedAt: b.createdAt)
    }
}

extension AppModel {
    /// Live 87-3: `GET /v1/blocks`, newest first.
    @MainActor func loadBlocks() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let r: BlockList = try await APIClient.shared.get("/v1/blocks")
            blockedKeepers = r.items.map(BlockedKeeper.init)
        } catch {
            handle(error)
        }
    }

    /// Live 75-2: `POST /v1/blocks` with one plaza id. Reloads the plaza, which
    /// the server now returns without that person. False when it failed.
    @MainActor func blockLive(_ target: PlazaTarget) async -> Bool {
        let body: BlockIn
        switch target {
        case .line(let id): body = BlockIn(lineId: id)
        case .star(let id): body = BlockIn(starId: id)
        case .nebula(let id): body = BlockIn(nebulaId: id)
        }
        do {
            let b: BlockOut = try await APIClient.shared.post("/v1/blocks", body: body)
            blockedKeepers.removeAll { $0.id == b.id }
            blockedKeepers.insert(BlockedKeeper(b), at: 0)
            await loadPlaza()
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// Live 87-3 차단 풀기: `DELETE /v1/blocks/{id}`.
    @MainActor func unblockLive(_ keeper: BlockedKeeper) async -> Bool {
        do {
            try await APIClient.shared.delete("/v1/blocks/\(keeper.id)")
            blockedKeepers.removeAll { $0.id == keeper.id }
            await loadPlaza()
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// Live 100 (and the 75-1 / 73 menu): report, and block too when asked.
    /// The item disappears for the reporter at once.
    @MainActor func reportLive(_ target: PlazaTarget, reason: String, block: Bool) async -> Bool {
        let path: String
        switch target {
        case .line(let id): path = "/v1/plaza/lines/\(id)/report"
        case .star(let id): path = "/v1/plaza/star/\(id)/report"
        case .nebula(let id): path = "/v1/plaza/nebula/\(id)/report"
        }
        do {
            let r: PlazaReportOut = try await APIClient.shared.post(path, body: PlazaReportIn(reason: reason, block: block))
            if r.blocked == true { await loadBlocks() }
            if case .line = target {} else { await loadPlaza() }
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// Live 02-1: `POST /v1/auth/invite`. False for a wrong id or password
    /// (401 invalid_credentials, the same answer for both).
    @MainActor func inviteSignInLive(username: String, password: String) async -> Bool {
        do {
            let session: AuthSession = try await APIClient.shared.inviteSignIn(login: username, password: password)
            hasConsented = !session.needsConsent
            isSignedIn = true
            await refreshMe()
            return true
        } catch let e as APIError where e.code == "invalid_credentials" {
            return false
        } catch {
            handle(error)
            return false
        }
    }
}

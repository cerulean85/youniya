import Foundation

// MARK: - Payloads

private struct CoinBalance: Decodable {
    var coins: Int
    var freeTelescopeAvailable: Bool
}

private struct CoinHistoryList: Decodable {
    struct Item: Decodable {
        var id: String
        /// purchase · spend · refund
        var kind: String
        var title: String
        var delta: Int
        var createdAt: Date
    }
    var items: [Item]
}

private struct PurchaseIn: Encodable {
    /// StoreKit 2 `Transaction.jwsRepresentation` (production).
    var signedTransaction: String?
    /// 28 "(필수) 결제·환불 정책에 동의해요": always true, the button needs the check.
    var consumptionConsent = true
    /// Development server only (TRUST_PURCHASES=1).
    var productId: String?
    var transactionId: String?
}

private struct PurchaseResult: Decodable {
    var coins: Int
    var added: Int
}

/// GET /v1/me/shares → `stars` (17 나눈 성운).
struct SharedStar: Decodable, Identifiable {
    /// The share's id.
    var id: String
    var starId: String
    var title: String
    var writtenAt: Date
    var starlight: Int?
}

private struct MyShares: Decodable {
    var stars: [SharedStar]
}

// MARK: - AppModel (live coins and shares)

extension AppModel {
    /// Live: balance, the free telescope, and 33 history from the server.
    @MainActor func loadCoins() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            async let balance: CoinBalance = APIClient.shared.get("/v1/coins")
            async let history: CoinHistoryList = APIClient.shared.get("/v1/coins/history")
            let (b, h) = try await (balance, history)
            coins = b.coins
            usedFreeTelescope = !b.freeTelescopeAvailable
            coinHistory = h.items.map {
                CoinEntry(id: UUID(uuidString: $0.id) ?? UUID(), title: $0.title, delta: $0.delta,
                          date: $0.createdAt, kind: $0.kind)
            }
        } catch {
            handle(error)
        }
    }

    /// Live 28: credits a purchase on the server, with the refund-policy consent.
    /// Returns the coins added. Debug builds use the dev server's trusted purchase;
    /// release builds need StoreKit 2 (TODO), so they fail as 38 for now.
    @MainActor func purchaseCoinsLive(_ amount: Int) async throws -> Int {
        #if DEBUG
        let body = PurchaseIn(productId: "coin_\(amount)", transactionId: "ios-dev-\(UUID().apiID)")
        #else
        // TODO: StoreKit 2 purchase with appAccountToken = /v1/me id, send
        // `transaction.jwsRepresentation`, and `finish()` after the server answers 200.
        let body = PurchaseIn(signedTransaction: nil)
        #endif
        let r: PurchaseResult = try await APIClient.shared.post("/v1/coins/purchases", body: body)
        coins = r.coins
        await loadCoins()
        return r.added
    }

    /// Live 17: the stars this user shared to the plaza, newest share first.
    @MainActor func loadSharedStars() async throws -> [SharedStar] {
        let r: MyShares = try await APIClient.shared.get("/v1/me/shares")
        return r.stars
    }

    /// Live 17 "광장에서 거두기"
    @MainActor func withdrawShareLive(starID: String) async throws {
        try await APIClient.shared.delete("/v1/stars/\(starID)/share")
        if let id = UUID(uuidString: starID), let i = stars.firstIndex(where: { $0.id == id }) {
            stars[i].sharedToPlaza = false
        }
    }
}

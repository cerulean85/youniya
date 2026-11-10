import Foundation

// MARK: - Payloads

private struct CoinBalance: Decodable {
    var coins: Int
    /// Free uses left (e24a01d): today's float (0/1).
    var freeStarToday: Int?
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

/// GET /v1/me/shares → `stars` (17 나눈 별).
struct SharedStar: Decodable, Identifiable {
    /// The share's id.
    var id: String
    var starId: String
    var title: String
    var writtenAt: Date
    var starlight: Int?
    /// 12-3: off the plaza until a new 대표 문장 is picked.
    var quoteMissing: Bool?
}

private struct MyShares: Decodable {
    struct Nebula: Decodable { var id: String }
    var stars: [SharedStar]
    var nebulae: [Nebula]
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
            applyFreeUses(star: b.freeStarToday)
            // Members: today's 10 floats / telescopes left.
            if membershipAvailable { await loadMembership() }
            coinHistory = h.items.map {
                CoinEntry(id: UUID(uuidString: $0.id) ?? UUID(), title: $0.title, delta: $0.delta,
                          date: $0.createdAt, kind: $0.kind)
            }
        } catch {
            handle(error)
        }
    }

    /// Debug builds charge through the dev server's trusted purchase (no App Store);
    /// `-realPurchases YES` uses StoreKit like release builds.
    static var usesStoreKit: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "realPurchases")
        #else
        true
        #endif
    }

    /// Live 28: buys and has the server credit it, with the refund-policy consent.
    /// Returns the coins added, or nil when the user closed the App Store sheet.
    /// Throws `purchase_unverified` (38) when the payment is pending or unconfirmed.
    @MainActor func purchaseCoinsLive(_ amount: Int) async throws -> Int? {
        let added: Int
        if Self.usesStoreKit {
            switch try await StoreKitCoins.buy(coins: amount, accountID: accountID) {
            case .credited(let balance, let n):
                coins = balance
                added = n
            case .cancelled:
                return nil
            case .pending:
                throw APIError(status: 0, code: "purchase_unverified", message: "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")
            }
        } else {
            let body = PurchaseIn(productId: "coin_\(amount)", transactionId: "ios-dev-\(UUID().apiID)")
            let r: PurchaseResult = try await APIClient.shared.post("/v1/coins/purchases", body: body)
            coins = r.coins
            added = r.added
        }
        await loadCoins()
        return added
    }

    /// Live 17: the stars this user shared to the plaza, newest share first.
    @MainActor func loadSharedStars() async throws -> [SharedStar] {
        let r: MyShares = try await APIClient.shared.get("/v1/me/shares")
        return r.stars
    }

    /// Live 12-3: whether this shared star still waits for a new 대표 문장
    /// (the edit's answer said so; this keeps it after a relaunch).
    @MainActor func refreshQuoteMissing(_ id: StarItem.ID) async {
        guard useLiveAPI, let r: MyShares = try? await APIClient.shared.get("/v1/me/shares"),
              let i = stars.firstIndex(where: { $0.id == id }) else { return }
        let share = r.stars.first { UUID(uuidString: $0.starId) == id }
        stars[i].shareQuoteMissing = share?.quoteMissing == true ? true : nil
    }

    /// Live 92: how many stars and nebulae are shared now.
    @MainActor func shareCounts() async throws -> (stars: Int, nebulae: Int) {
        let r: MyShares = try await APIClient.shared.get("/v1/me/shares")
        return (r.stars.count, r.nebulae.count)
    }

    /// Live 92 "모두 거두기": every star and nebula leaves the plaza.
    @MainActor func withdrawAllSharesLive() async {
        do {
            try await APIClient.shared.delete("/v1/me/shares")
            for i in stars.indices where stars[i].isShared { stars[i].sharedToPlaza = false }
        } catch {
            handle(error)
        }
    }

    /// Live 17 "광장에서 거두기"
    @MainActor func withdrawShareLive(starID: String) async throws {
        try await APIClient.shared.delete("/v1/stars/\(starID)/share")
        if let id = UUID(uuidString: starID), let i = stars.firstIndex(where: { $0.id == id }) {
            stars[i].sharedToPlaza = false
        }
    }
}

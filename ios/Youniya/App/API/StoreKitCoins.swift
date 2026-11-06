import Foundation
import StoreKit

/// 28 코인 충전 with StoreKit 2. The App Store product ids must match the
/// server's `COIN_PACKAGES`: coin_50, coin_120, coin_300 (consumables).
///
/// Purchase → `POST /v1/coins/purchases {signed_transaction, consumption_consent}`
/// → `finish()` only after the server credits it, so a purchase interrupted
/// on the way is delivered again by `Transaction.updates` / `unfinished`.
enum StoreKitCoins {
    static func productID(coins: Int) -> String { "coin_\(coins)" }

    enum Outcome {
        /// Credited by the server; the new balance and the coins added.
        case credited(coins: Int, added: Int)
        /// Closed by the user: nothing happened.
        case cancelled
        /// Waiting for approval (Ask to Buy) or not confirmed: 38.
        case pending
    }

    /// Buys one package. `accountID` (the /v1/me id) goes into `appAccountToken`
    /// so the server can tie the transaction to this account.
    @MainActor static func buy(coins amount: Int, accountID: String?) async throws -> Outcome {
        guard let product = try await Product.products(for: [productID(coins: amount)]).first else {
            throw APIError(status: 0, code: "product_unavailable", message: "지금은 이 상품을 살 수 없어요.")
        }
        var options: Set<Product.PurchaseOption> = []
        if let accountID, let token = UUID(uuidString: accountID) { options.insert(.appAccountToken(token)) }

        switch try await product.purchase(options: options) {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return .pending }
            let r = try await credit(verification.jwsRepresentation)
            await transaction.finish()
            return .credited(coins: r.coins, added: r.added)
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    /// Delivers purchases that were paid but not credited yet (the app closed,
    /// the network dropped). Call once at launch while signed in.
    static func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await verification in Transaction.unfinished {
                await deliver(verification)
            }
            for await verification in Transaction.updates {
                await deliver(verification)
            }
        }
    }

    private static func deliver(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification,
              transaction.productType == .consumable,
              await APIClient.shared.isSignedIn else { return }
        // Refunded or revoked: the server handles it from App Store notifications.
        if transaction.revocationDate != nil {
            await transaction.finish()
            return
        }
        do {
            _ = try await credit(verification.jwsRepresentation)
            await transaction.finish()
        } catch {
            // Left unfinished; tried again on the next launch.
        }
    }

    private struct Body: Encodable {
        var signedTransaction: String
        /// 28 "(필수) 결제·환불 정책에 동의해요" is required to buy.
        var consumptionConsent = true
    }

    struct Credited: Decodable { var coins: Int; var added: Int }

    private static func credit(_ jws: String) async throws -> Credited {
        try await APIClient.shared.post("/v1/coins/purchases", body: Body(signedTransaction: jws))
    }
}

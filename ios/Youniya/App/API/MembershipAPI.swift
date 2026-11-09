import Foundation
import UIKit

// v1.1 별지기 멤버십 (server e2f913f). While the server's MEMBERSHIP flag is off,
// GET /v1/membership is 404 and the app keeps the membership hidden.

struct MembershipOut: Decodable {
    var active: Bool
    var productId: String?
    var expiresAt: Date?
    var autoRenew: Bool?
    var status: String?
    /// Members: 10 a day each, then coins.
    var starsLeftToday: Int?
    var telescopeLeftToday: Int?
}

private struct VerifyIn: Encodable { var signedTransaction: String }

extension AppModel {
    /// Live: membership state. 404 = the membership is off on this server.
    @MainActor func loadMembership() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let m: MembershipOut = try await APIClient.shared.get("/v1/membership")
            membershipAvailable = true
            apply(m)
        } catch let e as APIError where e.status == 404 {
            membershipAvailable = false
            memberActive = false
        } catch {
            // Keep what we had; the membership is never required to use the app.
        }
    }

    @MainActor func apply(_ m: MembershipOut) {
        memberActive = m.active
        memberRenewal = m.expiresAt
        memberLeftToday = (m.starsLeftToday, m.telescopeLeftToday)
        if !m.active { endMemberLooks() }
    }

    /// When a membership ends: violet and the default icon again.
    /// (Saved nebulae keep their season silhouettes.)
    @MainActor func endMemberLooks() {
        if !settings.sky.isFree { settings.sky = .violet }
        if UIApplication.shared.alternateIconName != nil {
            Task { try? await UIApplication.shared.setAlternateIconName(nil) }
        }
    }

    /// After a purchase or a restore: `POST /v1/membership/verify`.
    @MainActor func verifyMembership(_ jws: String) async -> Bool {
        do {
            let m: MembershipOut = try await APIClient.shared.post("/v1/membership/verify",
                                                                   body: VerifyIn(signedTransaction: jws))
            apply(m)
            await loadCoins()
            return m.active
        } catch {
            handle(error)
            return false
        }
    }
}

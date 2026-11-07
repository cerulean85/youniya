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
    var telescopeLeftThisMonth: Int?
}

private struct VerifyIn: Encodable { var signedTransaction: String }

private struct MonthlyList: Decodable {
    struct Item: Decodable { var month: String; var title: String; var createdAt: Date }
    var items: [Item]
}

private struct MonthlyOut: Decodable {
    struct Lens: Decodable { var key: String; var label: String; var value: Double; var note: String }
    struct Emotion: Decodable { var mood: Mood; var label: String; var percent: Int }
    struct Brightest: Decodable { var starId: String?; var title: String?; var sentence: String }
    var month: String
    var title: String
    var lenses: [Lens]
    var emotions: [Emotion]
    var brightest: Brightest?
    var question: String
    var starCount: Int
}

/// A row of 26's monthly reports: "2026-10" and its title.
struct MonthlyReportItem: Identifiable, Hashable {
    var month: String
    var title: String
    var id: String { month }
    /// "10월"
    var monthLabel: String { "\(Int(month.suffix(2)) ?? 0)월" }
}

extension AppModel {
    /// Live: membership state. 404 = the membership is off on this server.
    @MainActor func loadMembership() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let m: MembershipOut = try await APIClient.shared.get("/v1/membership")
            membershipAvailable = true
            apply(m)
            if m.active { await loadMonthlyReports() }
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

    /// Live 26: a member's monthly reports, newest first.
    @MainActor func loadMonthlyReports() async {
        guard useLiveAPI, isMember else { return }
        if let r: MonthlyList = try? await APIClient.shared.get("/v1/reports/monthly") {
            monthlyReports = r.items.map { MonthlyReportItem(month: $0.month, title: $0.title) }
        }
    }

    /// Live 123: one month's report.
    @MainActor func monthlyReport(_ month: String) async -> MonthlyReport? {
        do {
            let r: MonthlyOut = try await APIClient.shared.get("/v1/reports/monthly/\(month)")
            return MonthlyReport(
                month: "\(Int(r.month.suffix(2)) ?? 0)월", floatedCount: r.starCount, name: r.title,
                lenses: r.lenses.map { ($0.label, $0.value, $0.note) },
                emotions: r.emotions.map { ($0.mood, $0.percent) },
                brightest: r.brightest?.sentence ?? "", question: r.question)
        } catch {
            handle(error)
            return nil
        }
    }
}

import Foundation

// 10.1 별빛 한 줄 (2026-11-08: on a shared star, not a nebula): up to 60 자,
// one per person per star, read only by the star's owner; it stays. Quick
// chips 공감해요 / 저도 그랬어요 / 고마워요. Hurtful, contact, judging or advice
// words are sent back to be rewritten (99).

struct ReceivedLine: Identifiable, Hashable {
    var id: String
    var text: String
    var nickname: String?
    var createdAt: Date
}

enum LineSendResult: Equatable {
    case sent
    /// 99 (and other 422s): why it can't go, shown over the composer.
    case rejected(String)
    /// 107
    case already
    /// The owner doesn't take lines.
    case closed
}

private struct LineIn: Encodable { var text: String?; var chip: String? }
private struct LinesOut: Decodable {
    struct Item: Decodable { var id: String; var text: String?; var chip: String?; var nickname: String?; var createdAt: Date }
    var items: [Item]
    var count: Int?
}
private struct LineReportIn: Encodable { var reason: String; var block: Bool }

extension AppModel {
    static let lineChips: [(key: String, label: String)] = [("empathize", "공감해요"), ("me_too", "저도 그랬어요"), ("thanks", "고마워요")]
    static let lineLimit = 60

    /// 74: POST /v1/plaza/stars/{share_id}/lines (mock: a few words held back).
    @MainActor func sendStarLine(to star: PlazaNebula, text: String?, chip: String?) async -> LineSendResult {
        guard useLiveAPI, let id = star.serverID else {
            if sentStarLines[star.name] != nil { return .already }
            if let t = text {
                if ["한심", "바보", "멍청", "꺼져"].contains(where: t.contains) { return .rejected("상처가 될 수 있는 말이 있어 건네지 못했어요") }
                if PrivacyScan(t, contactsOnly: true).contacts > 0 { return .rejected("연락처는 별빛 한 줄에 담을 수 없어요") }
                if ["해야 해", "하세요", "하지 마"].contains(where: t.contains) { return .rejected("조언 대신 마음을 건네 주세요") }
            }
            sentStarLines[star.name] = text ?? Self.lineChips.first { $0.key == chip }?.label ?? ""
            return .sent
        }
        do {
            try await APIClient.shared.sendRaw("POST", "/v1/plaza/stars/\(id)/lines", body: LineIn(text: text, chip: chip))
            sentStarLines[star.name] = text ?? Self.lineChips.first { $0.key == chip }?.label ?? ""
            if let i = plazaStarsLive.firstIndex(where: { $0.serverID == id }) { plazaStarsLive[i].lineLeft = true }
            return .sent
        } catch let e as APIError {
            switch e.code {
            case "already_left": return .already
            case "lines_closed": return .closed
            case "hurtful": return .rejected("상처가 될 수 있는 말이 있어 건네지 못했어요")
            case "contact": return .rejected("연락처는 별빛 한 줄에 담을 수 없어요")
            case "judging", "advice": return .rejected("판단이나 조언 대신 마음을 건네 주세요")
            case "too_long": return .rejected("\(Self.lineLimit)자 안으로 줄여 주세요")
            default: return .rejected(e.message)
            }
        } catch {
            handle(error)
            return .rejected("건네지 못했어요. 잠시 뒤에 다시 해 주세요")
        }
    }

    /// 12-4: lines on my star (GET /v1/stars/{id}/lines; mock: samples).
    @MainActor func receivedLines(_ starID: StarItem.ID) async -> [ReceivedLine] {
        guard useLiveAPI else { return mockReceivedLines[starID] ?? [] }
        do {
            let r: LinesOut = try await APIClient.shared.get("/v1/stars/\(starID.apiID)/lines")
            return r.items.map { i in
                ReceivedLine(id: i.id, text: i.text ?? Self.lineChips.first { $0.key == i.chip }?.label ?? "",
                             nickname: i.nickname, createdAt: i.createdAt)
            }
        } catch {
            handle(error)
            return []
        }
    }

    /// 12-4 「지우기」.
    @MainActor func deleteLine(_ line: ReceivedLine, on starID: StarItem.ID) async -> Bool {
        guard useLiveAPI else { mockReceivedLines[starID]?.removeAll { $0.id == line.id }; return true }
        do {
            try await APIClient.shared.delete("/v1/stars/\(starID.apiID)/lines/\(line.id)")
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// 100 신고하기 (hidden at once; `block` also blocks its keeper).
    @MainActor func reportLine(_ line: ReceivedLine, on starID: StarItem.ID, reason: String, block: Bool) async -> Bool {
        guard useLiveAPI else { mockReceivedLines[starID]?.removeAll { $0.id == line.id }; return true }
        do {
            try await APIClient.shared.sendRaw("POST", "/v1/stars/\(starID.apiID)/lines/\(line.id)/report",
                                               body: LineReportIn(reason: reason, block: block))
            return true
        } catch {
            handle(error)
            return false
        }
    }
}

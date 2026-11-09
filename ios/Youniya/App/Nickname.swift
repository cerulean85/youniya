import Foundation

// 15장 별지기 이름 (2026-11-08): 2–12자, 한글·영문·숫자, unique, no slurs or
// impersonation; changeable once every 30 days.

private struct NicknameCheck: Decodable {
    var available: Bool
    var reason: String?
    var message: String?
}
private struct NicknameIn: Encodable { var name: String }
private struct NicknameOut: Decodable {
    var nickname: String
    var nextChange: Date?
}

enum NicknameResult {
    case ok
    /// Shown under the field (red).
    case problem(String)
}

extension AppModel {
    /// The form rules, checked here before asking the server.
    static func nicknameFormProblem(_ name: String) -> String? {
        if name.count < 2 || name.count > 12 { return "2~12자로 정해 주세요" }
        if name.range(of: #"^[가-힣A-Za-z0-9]+$"#, options: .regularExpression) == nil {
            return "한글·영문·숫자만 쓸 수 있어요"
        }
        let reserved = ["운영자", "관리자", "youniya", "유니야", "admin"]
        if reserved.contains(where: { name.lowercased().contains($0) }) { return "쓸 수 없는 이름이에요" }
        return nil
    }

    /// 21-1 / 87-7: whether the name can be used (live: GET /v1/me/nickname/check).
    @MainActor func checkNickname(_ name: String) async -> NicknameResult {
        if let p = Self.nicknameFormProblem(name) { return .problem(p) }
        if name == nickname { return .ok }
        guard useLiveAPI else {
            // Mock: one name is taken (Figma 21-2).
            return name == "고요한새벽" ? .problem("이미 다른 별지기가 쓰고 있는 이름이에요") : .ok
        }
        do {
            let r: NicknameCheck = try await APIClient.shared.get("/v1/me/nickname/check", query: ["name": name])
            if r.available { return .ok }
            return .problem(r.message ?? (r.reason == "taken" ? "이미 다른 별지기가 쓰고 있는 이름이에요" : "쓸 수 없는 이름이에요"))
        } catch {
            return .problem("이름을 확인하지 못했어요. 잠시 뒤에 다시 해 주세요")
        }
    }

    /// 21-1 「이 이름으로 시작하기」 / 87-7 「바꾸기」: PUT /v1/me/nickname.
    @MainActor func setNickname(_ name: String) async -> NicknameResult {
        guard useLiveAPI else {
            if let p = Self.nicknameFormProblem(name) { return .problem(p) }
            nickname = name
            nicknameNextChange = Calendar.current.date(byAdding: .day, value: 30, to: .now)
            nicknameRenameRequired = false
            return .ok
        }
        do {
            let r: NicknameOut = try await APIClient.shared.send("PUT", "/v1/me/nickname", body: NicknameIn(name: name))
            nickname = r.nickname
            nicknameNextChange = r.nextChange
            nicknameRenameRequired = false
            return .ok
        } catch let e as APIError {
            switch e.code {
            case "nickname_too_soon": return .problem("아직 바꿀 수 없어요. 30일에 한 번 바꿀 수 있어요")
            case "nickname_taken": return .problem("이미 다른 별지기가 쓰고 있는 이름이에요")
            default: return .problem(e.message)
            }
        } catch {
            handle(error)
            return .problem("저장하지 못했어요. 잠시 뒤에 다시 해 주세요")
        }
    }

    /// "12월 8일"
    var nicknameNextChangeText: String? {
        guard let d = nicknameNextChange, d > .now else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

// MARK: - 31 새 기능·혜택 알림 (14.3)

private struct MarketingIn: Encodable { var optIn: Bool }
private struct MarketingOut: Decodable { var optIn: Bool }

extension AppModel {
    /// PUT /v1/me/marketing; the server sends the result as a push
    /// ("consent_result"). Mock: on device.
    @MainActor func setMarketing(_ on: Bool) async {
        let before = marketingOptIn
        marketingOptIn = on
        guard useLiveAPI else { return }
        do {
            let r: MarketingOut = try await APIClient.shared.send("PUT", "/v1/me/marketing", body: MarketingIn(optIn: on))
            marketingOptIn = r.optIn
        } catch {
            marketingOptIn = before
            handle(error)
        }
    }
}

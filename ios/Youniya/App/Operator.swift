import SwiftUI

// 18장 운영자 조치가 앱에 닿는 곳 (2026-11-09): 광장 이용 제한 (09-6/09-7),
// 별지기 이름 바꾸기 요청 (04-1/87-8), 알림함 (130) and 공지 (131).

/// Where a notification (push or 130 row) opens. The server's `target.screen`.
enum NotificationTarget: Equatable {
    case star(UUID)
    case nickname
    case plazaRestricted
    case plaza
    case coinHistory
    case notice(String)
    case notificationSettings
    case inbox

    init?(_ t: [String: Any]?) {
        switch t?["screen"] as? String {
        case "star": self = (t?["star_id"] as? String).flatMap(UUID.init(uuidString:)).map(Self.star) ?? .inbox
        case "nickname": self = .nickname
        case "plaza_restricted": self = .plazaRestricted
        case "plaza": self = .plaza
        case "coin_history": self = .coinHistory
        case "notice": self = (t?["notice_id"] as? String).map(Self.notice) ?? .inbox
        case "notification_settings": self = .notificationSettings
        case "notifications": self = .inbox
        default: return nil
        }
    }

    /// 130 "이동할 곳 ›"
    var label: String? {
        switch self {
        case .star: "별 보기"
        case .nickname: "이름 바꾸기"
        case .plazaRestricted: "자세히"
        case .plaza: "우주 광장"
        case .coinHistory: "코인 사용 내역"
        case .notice: "공지 보기"
        case .notificationSettings: "설정 › 알림"
        case .inbox: nil
        }
    }
}

/// One 130 row.
struct InboxItem: Identifiable, Equatable {
    var id: String
    var kind: String
    var title: String
    var body: String
    var target: NotificationTarget?
    var createdAt: Date
    var read: Bool

    /// The colored label on top.
    var kindLabel: (String, Color) {
        switch target {
        case .notice: ("공지", .brandPrimaryText)
        case .nickname: ("운영자 요청", .starBright)
        case .plazaRestricted: ("이용 제한", .brandWarm)
        case .plaza: ("이용 제한 해제", .emotionCalm)
        case .star: ("광장에서 내려감", .emotionAnger)
        case .coinHistory: ("코인", .starClear)
        case .notificationSettings: ("알림 동의", .textSecondary)
        case .inbox, nil: kind == "report_result" ? ("신고 처리 결과", .emotionCalm) : ("알림", .textSecondary)
        }
    }
}

/// 131
struct AppNoticeItem: Identifiable, Equatable {
    var id: String
    var title: String
    var body: String
    var publishedAt: Date
}

extension Notification.Name {
    /// A push was tapped; `object` is the `NotificationTarget`.
    static let openNotificationTarget = Notification.Name("openNotificationTarget")
}

private struct InboxOut: Decodable {
    struct Item: Decodable {
        var id: String
        var kind: String
        var title: String
        var body: String
        var target: [String: JSONValue]?
        var createdAt: Date
        var read: Bool
    }
    var items: [Item]
    var unread: Int
}

private struct NoticesOut: Decodable {
    struct Item: Decodable { var id: String; var title: String; var body: String; var publishedAt: Date }
    var items: [Item]
}

/// Just enough of JSON for `target`.
enum JSONValue: Decodable {
    case string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else { self = .string(try c.decode(String.self)) }
    }
    var any: Any? {
        switch self {
        case .string(let s): s
        case .number(let n): n
        case .bool(let b): b
        case .null: nil
        }
    }
}

extension AppModel {
    var isPlazaRestricted: Bool { (plazaRestrictedUntil ?? .distantPast) > .now }

    /// 09-6 "11월 16일" / 09-7 "11월 16일 오후 3시".
    func restrictedText(withTime: Bool) -> String {
        guard let d = plazaRestrictedUntil else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = withTime ? "M월 d일 a h시" : "M월 d일"
        return f.string(from: d)
    }

    /// Before a plaza action: true when it may go ahead; otherwise 09-7 opens.
    func plazaAllowed() -> Bool {
        if isPlazaRestricted { showPlazaRestricted = true; return false }
        return true
    }

    var inboxUnread: Int { inbox.filter { !$0.read }.count }

    /// 130: GET /v1/me/notifications (mock: Figma samples).
    @MainActor func loadInbox() async {
        guard useLiveAPI, isSignedIn else {
            if inbox.isEmpty, !UserDefaults.standard.bool(forKey: "mockInboxCleared") { inbox = Self.mockInbox }
            return
        }
        guard let r: InboxOut = try? await APIClient.shared.get("/v1/me/notifications") else { return }
        inbox = r.items.map {
            InboxItem(id: $0.id, kind: $0.kind, title: $0.title, body: $0.body,
                      target: NotificationTarget($0.target?.compactMapValues(\.any)),
                      createdAt: $0.createdAt, read: $0.read)
        }
    }

    @MainActor func markRead(_ ids: [String]) async {
        for i in inbox.indices where ids.contains(inbox[i].id) { inbox[i].read = true }
        guard useLiveAPI, isSignedIn, !ids.isEmpty else { return }
        struct Body: Encodable { var ids: [String] }
        try? await APIClient.shared.sendRaw("POST", "/v1/me/notifications/read", body: Body(ids: ids))
    }

    /// 131: GET /v1/notices.
    @MainActor func loadNotices() async {
        guard useLiveAPI, isSignedIn else {
            if notices.isEmpty { notices = Self.mockNotices }
            return
        }
        if let r: NoticesOut = try? await APIClient.shared.get("/v1/notices") {
            notices = r.items.map { AppNoticeItem(id: $0.id, title: $0.title, body: $0.body, publishedAt: $0.publishedAt) }
        }
    }

    static let mockNotices = [
        AppNoticeItem(id: "n1", title: "11월 별자리는 페가수스자리예요",
                      body: "이번 달 저녁 하늘의 별자리를 채워 보세요. 별을 띄울 때마다 빈 자리가 하나씩 채워져요.",
                      publishedAt: .now.addingTimeInterval(-3600)),
    ]

    static let mockInbox: [InboxItem] = [
        InboxItem(id: "i1", kind: "notice", title: "11월 별자리는 페가수스자리예요", body: "이번 달 저녁 하늘의 별자리를 채워 보세요.",
                  target: .notice("n1"), createdAt: .now.addingTimeInterval(-3600), read: false),
        InboxItem(id: "i2", kind: "report_result", title: "별지기 이름을 바꿔 주세요",
                  body: "사칭으로 보일 수 있다는 신고가 확인됐어요. 30일 제한 없이 바로 바꿀 수 있어요.",
                  target: .nickname, createdAt: .now.addingTimeInterval(-3 * 3600), read: false),
        InboxItem(id: "i3", kind: "report_result", title: "광장 이용이 11월 16일까지 멈춰요",
                  body: "나누기·공명·곁에 두기·별빛 한 줄을 남길 수 없어요. 기록은 그대로예요.",
                  target: .plazaRestricted, createdAt: .now.addingTimeInterval(-3 * 3600), read: true),
        InboxItem(id: "i4", kind: "report_result", title: "신고하신 별을 확인했어요",
                  body: "광장에서 내렸어요. 알려 주셔서 고마워요.",
                  target: .inbox, createdAt: .now.addingTimeInterval(-86_400), read: true),
        InboxItem(id: "i5", kind: "operator_alert", title: "코인 330개를 받았어요", body: "결제 확인이 늦어 운영자가 지급했어요.",
                  target: .coinHistory, createdAt: .now.addingTimeInterval(-2 * 86_400), read: true),
        InboxItem(id: "i6", kind: "consent_result", title: "새 기능·혜택 알림 수신에 동의했어요",
                  body: "2026년 11월 9일 · 설정 › 알림에서 끌 수 있어요.",
                  target: .notificationSettings, createdAt: .now.addingTimeInterval(-2 * 86_400), read: true),
    ]
}

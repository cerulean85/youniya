import SwiftUI
import Observation

/// Emotion tone for a star (Figma `Chip` · Tone).
enum Mood: String, CaseIterable, Identifiable, Codable {
    case calm, sorrow, anger, insight
    var id: Self { self }

    var label: String {
        switch self {
        case .calm: "평온"
        case .sorrow: "슬픔"
        case .anger: "분노"
        case .insight: "통찰"
        }
    }

    var color: Color {
        switch self {
        case .calm: .emotionCalm
        case .sorrow: .emotionSorrow
        case .anger: .emotionAnger
        case .insight: .emotionInsight
        }
    }

    var tint: Color {
        switch self {
        case .calm: .tintCalm
        case .sorrow: .tintSorrow
        case .anger: .tintAnger
        case .insight: .tintInsight
        }
    }
}

/// Result of the starlight prism (06). Values are 0...1 except `starlight` (0–999).
struct StarAnalysis: Hashable, Codable {
    var starlight: Int
    var depth: Double
    var clarity: Double
    var weight: Double
    var observation: String
    var telescopeTeaser: String
    var tones: [Mood]
    /// 17.3 별빛 풀이: one or two sentences per score, and 2–4 sentences
    /// overall. Nil until the server sends them (and for older stars).
    var depthReason: String? = nil
    var clarityReason: String? = nil
    var weightReason: String? = nil
    var interpretation: String? = nil
    /// 17.6: how it was read, e.g. "별빛 프리즘 v1 · 2026년 11월 방식으로 읽었어요".
    var prismVersion: String? = nil

    var isDeep: Bool { depth >= 0.7 }
    /// 17.3: the three scores that add up to the starlight (깊이 0–400,
    /// 선명함 0–300, 무게 0–300).
    var depthScore: Int { Int((depth * 400).rounded()) }
    var clarityScore: Int { Int((clarity * 300).rounded()) }
    var weightScore: Int { Int((weight * 300).rounded()) }

    /// 06 while the server is still reading: empty meters.
    static let reading = StarAnalysis(starlight: 0, depth: 0, clarity: 0, weight: 0,
                                      observation: "", telescopeTeaser: "", tones: [])
    /// Figma 90: "별빛이 700을 넘어 크게 빛난 별".
    /// Figma and the API both count 900+ starlight as a supernova.
    var isSupernova: Bool { starlight >= 900 }

    /// TODO: Replace with the real analysis API. This mock is deterministic per text
    /// so the same draft always gives the same card.
    static func mock(for draft: StarDraft) -> StarAnalysis {
        let seed = draft.body.unicodeScalars.reduce(UInt64(draft.title.count)) { ($0 &* 31) &+ UInt64($1.value) }
        func unit(_ salt: UInt64) -> Double {
            var x = seed &+ salt &* 0x9E3779B97F4A7C15
            x ^= x >> 33; x = x &* 0xFF51AFD7ED558CCD; x ^= x >> 33
            return Double(x % 1000) / 1000
        }
        let length = min(1, Double(draft.body.count) / 400)
        let observations: [Mood: String] = [
            .calm: "그런 마음이 머물렀군요.\n오늘의 별은 조용히 숨을 고르고 있어요.",
            .sorrow: "그 마음을 꺼내어 주었군요.\n오늘의 별은 천천히 젖은 빛을 말리고 있어요.",
            .anger: "뜨거운 마음이 지나갔군요.\n오늘의 별은 붉은 숨을 가라앉히고 있어요.",
            .insight: "무언가를 알아차렸군요.\n오늘의 별은 맑은 빛으로 반짝이고 있어요.",
        ]
        let second: Mood = Mood.allCases[Int(unit(4) * 4) % 4]
        return StarAnalysis(
            starlight: 300 + Int((0.45 * length + 0.55 * unit(1)) * 650),
            depth: 0.3 + 0.6 * max(length, unit(2)),
            clarity: 0.3 + 0.6 * unit(3),
            weight: 0.2 + 0.6 * unit(5),
            observation: observations[draft.mood] ?? "",
            telescopeTeaser: "기다림 속에 작은 안도가 섞여 있어요.",
            tones: second == draft.mood ? [draft.mood] : [draft.mood, second],
            depthReason: sampleReasons.depth,
            clarityReason: sampleReasons.clarity,
            weightReason: sampleReasons.weight,
            interpretation: sampleReasons.interpretation,
            prismVersion: "별빛 프리즘 v1"
        )
    }

    /// Figma 07-1 / 12-5 sample 별빛 풀이 (mock).
    static let sampleReasons = (
        depth: "사건을 늘어놓는 데서 멈추지 않고 '쉬고 싶었는지도 몰라요'처럼 그때 느낀 마음까지 내려갔어요.",
        clarity: "'느리게', '싫지만은 않았어요'처럼 마음을 꽤 구체적으로 불렀지만, 서운함과 안도가 함께 섞여 있어 조금 흐릿한 곳도 있어요.",
        weight: "기다림을 남 탓으로 돌리지 않고 '나는 쉬고 싶었다'고 내 마음으로 받아 안았어요.",
        interpretation: "오늘의 글은 바쁜 하루 속에서 멈춰 선 자신을 알아차린 기록이에요. 기다림이 길었다는 사실보다, 그 느림 속에서 '쉬고 싶었다'는 마음을 스스로 찾아낸 점이 별빛을 밝혔어요. 서운함과 안도가 함께 있는 마음은 아직 이름이 섞여 있어서, 망원경으로 보면 그 결이 더 또렷해질 수 있어요."
    )
}

/// Mind telescope report (10): a closer look at one floated star.
struct TelescopeReport: Hashable, Codable {
    struct Lens: Hashable, Codable {
        var label: String
        var value: Double
        var note: String
    }
    struct Share: Hashable, Codable {
        var mood: Mood
        var percent: Int
    }

    var starName: String
    var lenses: [Lens]
    var emotions: [Share]
    /// A sentence quoted from the user's own text.
    var evidence: String
    var question: String
    /// 17.3 망원경 (2026-11-08): what clouded the writing, and how the mood
    /// moved through it. Nil until the server sends them.
    struct Fog: Hashable, Codable { var kind: String; var sentence: String; var note: String }
    struct Flow: Hashable, Codable { var part: String; var moods: String; var note: String }
    var fogItems: [Fog]? = nil
    var moodFlow: [Flow]? = nil
    var moodInterpretation: String? = nil
    var isSaved = false
    /// The server's report id (live), for 보관하기.
    var serverID: String? = nil

    /// TODO: Replace with the real report API. Uses the star's analysis and quotes
    /// the longest sentence the user wrote.
    static func mock(for star: StarItem) -> TelescopeReport {
        let a = star.analysis
        let names: [Mood: String] = [.calm: "기다림이 머문 별", .sorrow: "젖은 빛을 품은 별", .anger: "뜨거움을 지난 별", .insight: "맑게 깨어난 별"]
        let questions: [Mood: String] = [
            .calm: "쉬고 싶다는 마음은 어디에서 오고 있을까요?",
            .sorrow: "그 아픔 곁에 오늘은 무엇을 놓아두고 싶나요?",
            .anger: "그 뜨거움이 지키려던 것은 무엇이었을까요?",
            .insight: "오늘 알아차린 것을 내일의 나에게 어떻게 전하고 싶나요?",
        ]
        let sentences = star.body
            .split(whereSeparator: { ".!?\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let evidence = sentences.max(by: { $0.count < $1.count }).map { $0 + "." } ?? star.title

        let tones = a?.tones ?? [star.mood]
        let shares: [Share]
        switch tones.count {
        case 1: shares = [Share(mood: tones[0], percent: 100)]
        default: shares = [Share(mood: tones[0], percent: 58), Share(mood: tones[1], percent: 42)]
        }
        return TelescopeReport(
            starName: names[star.mood] ?? "오늘의 별",
            lenses: [
                Lens(label: "별의 깊이", value: a?.depth ?? 0.5, note: "사건을 지나 속마음 가까이까지 내려가 마주했어요."),
                Lens(label: "빛의 선명함", value: a?.clarity ?? 0.5, note: "마음의 결이 또렷하게 구분돼요."),
                Lens(label: "마음의 무게", value: a?.weight ?? 0.5, note: "무게를 밖이 아닌 내 마음으로 품어냈어요."),
            ],
            emotions: shares,
            evidence: evidence,
            question: questions[star.mood] ?? "",
            fogItems: [Fog(kind: "한 걸음 물러서기", sentence: evidence,
                           note: "'어쩌면', '~지도'가 붙으면서 내 마음을 확신하기 직전에 한 발 뒤로 물러섰어요.")],
            moodFlow: [
                Flow(part: "글의 시작", moods: tones[0].label, note: "처음 마음이 먼저 있었어요."),
                Flow(part: "글의 끝", moods: tones.map(\.label).joined(separator: " · "), note: "쓰는 동안 마음이 조금씩 옮겨 갔어요."),
            ],
            moodInterpretation: "\(tones[0].label)이 가장 크게 남았어요. 글을 쓰는 동안 마음이 천천히 옮겨 갔어요."
        )
    }

    /// Figma `10 Mind Telescope Report` sample.
    static let sample = TelescopeReport(
        starName: "기다림이 머문 별",
        lenses: [
            Lens(label: "별의 깊이", value: 0.82, note: "사건을 지나 속마음 가까이까지 내려가 마주했어요."),
            Lens(label: "빛의 선명함", value: 0.55, note: "평온과 슬픔의 결이 또렷하게 구분돼요."),
            Lens(label: "마음의 무게", value: 0.55, note: "느림을 밖이 아닌 내 마음으로 품어냈어요."),
        ],
        emotions: [Share(mood: .calm, percent: 42), Share(mood: .sorrow, percent: 31), Share(mood: .insight, percent: 27)],
        evidence: "어쩌면 나는 쉬고 싶었는지도 몰라요.",
        question: "쉬고 싶다는 마음은 어디에서 오고 있을까요?",
        // Figma 12-2 (398:16202)
        fogItems: [
            Fog(kind: "한 걸음 물러서기", sentence: "어쩌면 나는 쉬고 싶었는지도 몰라요.",
                note: "'어쩌면', '~지도'가 붙으면서 내 마음을 확신하기 직전에 한 발 뒤로 물러섰어요."),
            Fog(kind: "이름 없이 지나간 감정", sentence: "친구의 답장은 오지 않았고, 나는 휴대폰을 엎어 두었어요.",
                note: "행동만 적고 그때의 마음(서운함)은 이름 붙이지 않고 지나갔어요."),
        ],
        moodFlow: [
            Flow(part: "글의 시작", moods: "슬픔", note: "기다림이 길어지며 서운함이 먼저 있었어요."),
            Flow(part: "글의 중간", moods: "슬픔 → 평온", note: "느림이 싫지만은 않다고 적으며 마음이 풀리기 시작했어요."),
            Flow(part: "글의 끝", moods: "평온 · 통찰", note: "'쉬고 싶었다'는 마음을 알아차리며 조용히 가라앉았어요."),
        ],
        moodInterpretation: "평온(42%)이 가장 크지만 슬픔(31%)도 가까이 있어요. 슬픔이 사라진 게 아니라, 글을 쓰는 동안 평온 쪽으로 천천히 옮겨 갔어요."
    )
}

struct StarItem: Identifiable, Hashable, Codable {
    enum State: Hashable, Codable {
        /// Floated to the sky with its starlight (0–999).
        case floated(starlight: Int?)
        /// Kept quietly, without analysis.
        case kept
    }

    var id = UUID()
    var title: String
    var dateText: String
    var state: State
    var mood: Mood = .calm
    /// 17.5: the other moods picked when it was written (shown as chips).
    var extraMoods: [Mood]? = nil
    var body: String = ""
    var analysis: StarAnalysis?
    var report: TelescopeReport?
    /// Nil for stars saved before this field existed (and the samples).
    var createdAt: Date?
    /// The star this one rewrites (14 Rewrite).
    var rewriteOf: UUID?
    /// Shared anonymously to the plaza (19). Optional so older saves still load.
    var sharedToPlaza: Bool?
    /// 10.1: lines received on this star (detail's line_count).
    var lineCount: Int? = nil
    /// 별 잇기 (11.5): the stars joined to this one, both ways, no direction.
    var linkedIDs: [UUID]? = nil
    /// 12-3: the text was edited and the shared 대표 문장 is no longer in it
    /// (the server's `quote_missing`); pick it again on 19-1.
    var shareQuoteMissing: Bool?

    var isShared: Bool { sharedToPlaza == true }

    /// e.g. "11월 3일" (17/18 record cards).
    var shortDateText: String {
        guard let createdAt else { return dateText.components(separatedBy: " ·").first ?? dateText }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: createdAt)
    }

    var isFloated: Bool {
        if case .floated = state { true } else { false }
    }

    /// Starlight of a floated star (from the analysis, or the saved value).
    var starlightValue: Int? {
        if let analysis { return analysis.starlight }
        if case .floated(let value) = state { return value }
        return nil
    }

    /// e.g. "11월 3일 화요일 · 21:30" (12 Star Detail header).
    var longDateText: String {
        guard let createdAt else { return dateText }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE · HH:mm"
        return f.string(from: createdAt)
    }

    /// The kept sample's writing (over 50 characters, so it can be floated later).
    static let keptSampleBody = "오늘도 끝내 그 말을 꺼내지 못했어요. 괜찮다고 웃었지만 마음 한쪽이 계속 무거웠어요. 언젠가는 천천히 말할 수 있을 것 같아요."

    /// Sample stars from the Figma `04 Home` frame.
    static let samples: [StarItem] = [
        StarItem(title: "느리게 흘러간 하루", dateText: "11월 3일 · 21:30", state: .floated(starlight: 742),
                 body: "오늘은 마음이 조금 느리게 흘렀어요. 해야 할 일은 많았는데 자꾸만 창밖을 보게 됐어요.\n\n민지 언니를 기다리는 일이 이렇게 오래 걸릴 줄 몰랐어요. 그래도 그 느림이 싫지만은 않았어요. 어쩌면 나는 쉬고 싶었는지도 몰라요.",
                 // Figma 07-1: 318 + 176 + 248 = 742.
                 analysis: StarAnalysis(starlight: 742, depth: 318.0 / 400, clarity: 176.0 / 300, weight: 248.0 / 300,
                                        observation: "그런 마음이 머물렀군요.\n오늘의 별은 조용히 숨을 고르고 있어요.",
                                        telescopeTeaser: "기다림 속에 작은 안도가 섞여 있어요.",
                                        tones: [.calm, .sorrow],
                                        depthReason: StarAnalysis.sampleReasons.depth,
                                        clarityReason: StarAnalysis.sampleReasons.clarity,
                                        weightReason: StarAnalysis.sampleReasons.weight,
                                        interpretation: StarAnalysis.sampleReasons.interpretation,
                                        prismVersion: "별빛 프리즘 v1")),
        StarItem(title: "말하지 못한 이야기", dateText: "11월 2일 · 23:10", state: .kept,
                 body: Self.keptSampleBody),
        StarItem(title: "비 오는 날의 안도", dateText: "11월 1일 · 22:04", state: .floated(starlight: 742)),
        StarItem(title: "다시 꺼내본 약속", dateText: "10월 30일 · 20:48", state: .floated(starlight: 742)),
    ]
}

/// The star being written in `05 Star Making`. Kept across close/reopen.
struct StarDraft: Codable, Equatable {
    /// The first mood picked: the star's color (17.5).
    var mood: Mood = .calm
    /// 17.5: more moods picked after the first, in order. Optional so older
    /// saved drafts still load.
    var extraMoods: [Mood]? = nil
    var title: String = ""
    var body: String = ""

    /// Every mood picked, the color first.
    var moods: [Mood] { [mood] + (extraMoods ?? []) }

    /// 05 mood chips: tap to add or remove; at least one stays, and removing
    /// the first moves the color to the next one.
    mutating func toggle(_ m: Mood) {
        var all = moods
        if let i = all.firstIndex(of: m) {
            guard all.count > 1 else { return }
            all.remove(at: i)
        } else {
            all.append(m)
        }
        mood = all[0]
        extraMoods = all.count > 1 ? Array(all.dropFirst()) : nil
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Saves values as JSON files in Application Support, protected while the device
/// is locked. Journal text is sensitive, so it never goes to UserDefaults.
struct LocalStore {
    var directory: URL = URL.applicationSupportDirectory.appending(path: "Youniya", directoryHint: .isDirectory)

    private func url(_ name: String) -> URL { directory.appending(path: "\(name).json") }

    func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = url(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            // Keep the unreadable file aside instead of overwriting it later.
            let backup = directory.appending(path: "\(name).corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return nil
        }
    }

    func save<T: Encodable>(_ value: T, to name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(value)
            try data.write(to: url(name), options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Saving \(name) failed: \(error)")
        }
    }

    func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }
}

/// One line of 33 Coin History.
struct CoinEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    /// +charged / −spent
    var delta: Int
    var date: Date = .now
    /// The server's purchase · spend · refund (121). Nil for mock entries.
    var kind: String? = nil

    /// 121: a refund takes coins back; shown as "충전 취소 · App Store 환불".
    var displayTitle: String { kind == "refund" ? "충전 취소 · App Store 환불" : title }
}

/// 87 Settings values. New fields need defaults so old saves still decode.
/// Dev-only failure modes, to see 35, 36 and 38 without a server.
enum SimulatedFailure: String, CaseIterable {
    case network = "연결 끊김"   // 35
    case analysis = "분석 실패"  // 36
    case payment = "결제 미완료" // 38
}

struct AppSettings: Codable, Equatable {
    var reduceAnimations = false
    var haptics = true
    var ambience = true
    var sound = "밤바람"
    var starReminder = false
    /// 87-2: the reminder's time of day, in minutes after midnight (오후 9:30).
    var reminderMinutes = 21 * 60 + 30
    /// 68 우주의 색
    var sky: SkyTheme = .violet

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        reduceAnimations = try c.decodeIfPresent(Bool.self, forKey: .reduceAnimations) ?? d.reduceAnimations
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        ambience = try c.decodeIfPresent(Bool.self, forKey: .ambience) ?? d.ambience
        sound = try c.decodeIfPresent(String.self, forKey: .sound) ?? d.sound
        starReminder = try c.decodeIfPresent(Bool.self, forKey: .starReminder) ?? d.starReminder
        reminderMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes) ?? d.reminderMinutes
        sky = (try? c.decodeIfPresent(SkyTheme.self, forKey: .sky)) ?? d.sky
    }
}

/// App-wide state. No backend yet: sign-in is mocked; stars are saved on device.
@Observable
final class AppModel {
    var isSignedIn: Bool {
        didSet {
            UserDefaults.standard.set(isSignedIn, forKey: "isSignedIn")
            // Remember which server the session belongs to (see init).
            if isSignedIn { UserDefaults.standard.set(APIConfig.baseURL.absoluteString, forKey: "signedInBaseURL") }
        }
    }
    /// 11 Consent accepted (required terms). Asked once per device.
    var hasConsented: Bool {
        didSet { UserDefaults.standard.set(hasConsented, forKey: "hasConsented") }
    }
    /// 15장 별지기 이름 (2–12자, unique). Nil until chosen.
    var nickname: String? = UserDefaults.standard.string(forKey: "nickname") {
        didSet { UserDefaults.standard.set(nickname, forKey: "nickname") }
    }
    /// The first day it can change again (30 days after the last change).
    var nicknameNextChange: Date? = UserDefaults.standard.object(forKey: "nicknameNextChange") as? Date {
        didSet { UserDefaults.standard.set(nicknameNextChange, forKey: "nicknameNextChange") }
    }
    /// 21-1 follows 11 right after sign-up; older accounts are asked on the plaza.
    var justConsented = false
    /// Optional "새 기능·혜택 알림" consent.
    var marketingOptIn: Bool {
        didSet { UserDefaults.standard.set(marketingOptIn, forKey: "marketingOptIn") }
    }
    /// v1.1 membership: the server says it is on (TODO: GET /v1/membership; 404 = off).
    var membershipAvailable = false
    /// Mock, or the current StoreKit entitlement.
    var memberActive = false
    var memberRenewal: Date?
    /// Live: a member's uses left today (stars, telescope); 10 each a day.
    var memberLeftToday: (stars: Int?, telescope: Int?) = (nil, nil)
    static let memberDailyLimit = 10
    /// A member still has today's included float / telescope.
    /// Mock: stars floated today; telescopes are counted by the server only.
    var memberHasStar: Bool { isMember && (memberLeftToday.stars ?? (Self.memberDailyLimit - floatedToday)) > 0 }
    var memberHasTelescope: Bool { isMember && (memberLeftToday.telescope ?? Self.memberDailyLimit) > 0 }
    /// 68-1: a locked sky shown for 3 seconds before M1.
    var previewSky: SkyTheme?
    /// Debug: `-debugTheme aurora+ / ember+ / rose+` shows the member scene.
    var debugScene = false
    /// v1.1: the scene behind a member's sky (or the 68-1 preview of one).
    var showsSkyScene: Bool { (isMember || debugScene || previewSky != nil) && (previewSky ?? settings.sky).hasScene }
    /// 87-3 차단한 별지기 (75-2, 100). Saved on device; mock and live kept apart.
    var blockedKeepers: [BlockedKeeper] = [] {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(blockedKeepers),
                                      forKey: useLiveAPI ? "blockedKeepers-live" : "blockedKeepers")
        }
    }
    /// 03-1 환영 안내: shown once on this device, the first time 03 opens.
    var hasSeenWelcome: Bool {
        didSet { UserDefaults.standard.set(hasSeenWelcome, forKey: "hasSeenWelcome") }
    }
    /// 21 Plaza Welcome is shown until "둘러보기" is tapped once.
    var hasSeenPlazaIntro: Bool {
        didSet { UserDefaults.standard.set(hasSeenPlazaIntro, forKey: "hasSeenPlazaIntro") }
    }
    /// Coin balance: mocked on device, or the server's when live (kept apart).
    var coins: Int {
        didSet { UserDefaults.standard.set(coins, forKey: useLiveAPI ? "coins-live" : "coins") }
    }
    /// 33 Coin history, newest first. Not sensitive, so kept in UserDefaults.
    var coinHistory: [CoinEntry] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(coinHistory), forKey: useLiveAPI ? "coinHistory-live" : "coinHistory") }
    }
    /// 87 Settings
    var settings: AppSettings {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: "settings")
            if settings.starReminder != oldValue.starReminder || settings.reminderMinutes != oldValue.reminderMinutes {
                Task { @MainActor in StarReminder.reschedule(self) }
            }
        }
    }
    /// Set once the free first telescope ("처음 한 번은 무료", 07) is used.
    var usedFreeTelescope: Bool {
        didSet { UserDefaults.standard.set(usedFreeTelescope, forKey: "usedFreeTelescope") }
    }
    /// 23 lines the user saved from others' stars (anonymous, no source kept).
    var savedLines: [String] {
        didSet { UserDefaults.standard.set(savedLines, forKey: "savedLines") }
    }
    /// 39–41: a notice covering the whole app. Not saved.
    var appNotice: AppNotice?
    /// Dev only: makes analysis or payment fail until turned off (35, 36, 38).
    var simulatedFailure: SimulatedFailure?
    /// Dev only: screens show their 47–50, 110–112 skeletons for a moment before content.
    /// Also on with the `-simulateLoading YES` launch argument. Not saved.
    var simulateLoading = UserDefaults.standard.bool(forKey: "simulateLoading")
    /// Dev: talk to the API server (`APIConfig.baseURL`) instead of the on-device
    /// mock. Saved; also `-useLiveAPI YES`. Features move over to it step by step.
    /// Release/TestFlight builds always use the API.
    var useLiveAPI: Bool = AppModel.savedLiveAPI {
        didSet { UserDefaults.standard.set(useLiveAPI, forKey: "useLiveAPI") }
    }
    private static var savedLiveAPI: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "useLiveAPI")
        #else
        true
        #endif
    }
    /// Debug builds sign in with the dev server's `/v1/auth/dev` (no Apple ID on the
    /// simulator needed); `-realSignIn YES` uses Sign in with Apple / Google instead.
    static var usesDevSignIn: Bool {
        #if DEBUG
        !UserDefaults.standard.bool(forKey: "realSignIn")
        #else
        false
        #endif
    }
    /// A server or network message for the root toast.
    var apiMessage: String?
    /// 120-1: when a rate-limited request may be tried again.
    var retryAvailableAt: Date?
    /// Live plaza (09, 72, 74), loaded by `loadPlaza()` / `loadLines(for:)`.
    var plazaStarsLive: [PlazaNebula] = []
    /// Live 「곁에 둔 것」: the server's beside list, most recently kept first.
    var plazaStarsBeside: [PlazaNebula] = []
    /// Live 08-3: month constellations by "YYYY-MM".
    var liveConstellations: [String: MonthConstellation] = [:]
    /// 74: the line I left on each plaza star (by name; memory).
    var sentStarLines: [String: String] = [:]
    /// Mock 12-4: lines received on my stars.
    var mockReceivedLines: [StarItem.ID: [ReceivedLine]] = [:]
    /// Live 08-3: month constellations by "YYYY-MM".
    /// Live: the server's account id (/v1/me), used as StoreKit's appAccountToken.
    var accountID: String?
    var tonightCount: Int?
    /// Of tonight's stars, how many are mine (`/v1/plaza/tonight` mine).
    var tonightMine: Int?
    /// Live: stars whose telescope report is being made on the server (25 → 10).
    var pendingReports: Set<StarItem.ID> = []
    /// The dev sign-in name; the same name is the same server account.
    static var devLoginName: String {
        UserDefaults.standard.string(forKey: "devLoginName") ?? "ios-dev"
    }
    /// How long the simulated load lasts; `-simulateLoadingSeconds 5` to hold it longer.
    static var simulatedLoadSeconds: Double {
        let s = UserDefaults.standard.double(forKey: "simulateLoadingSeconds")
        return s > 0 ? s : 1.5
    }
    /// Plaza nebulae this user left a resonance on (09, 22).
    /// TODO: Send to the plaza API; kept in memory for now.
    var resonated: Set<String> = []
    /// Saved to `stars.json` on every change.
    /// Saved to `stars.json`, or `stars-live.json` (a cache of the server's) when live.
    var stars: [StarItem] = [] {
        didSet {
            store.save(stars, to: starsFile)
            // 87: today's reminder goes once a star is written.
            if settings.starReminder { Task { @MainActor in StarReminder.reschedule(self) } }
        }
    }
    private var starsFile: String { useLiveAPI ? "stars-live" : "stars" }
    /// Autosaved draft, saved to `draft.json`.
    private(set) var draft: StarDraft
    @ObservationIgnored private let store: LocalStore

    init(store: LocalStore = LocalStore()) {
        self.store = store
        // A session from another server (e.g. the dev server moved) is no good
        // here: start signed out instead of showing that server's leftovers.
        var signedIn = UserDefaults.standard.bool(forKey: "isSignedIn")
        let was = UserDefaults.standard.string(forKey: "signedInBaseURL")
        #if DEBUG
        let moved = was != APIConfig.baseURL.absoluteString  // also before this was recorded
        #else
        let moved = was.map { $0 != APIConfig.baseURL.absoluteString } ?? false
        #endif
        if Self.savedLiveAPI, signedIn, moved {
            signedIn = false
            UserDefaults.standard.set(false, forKey: "isSignedIn")
            store.save([StarItem](), to: "stars-live")
            Task { await APIClient.shared.forget() }
        }
        isSignedIn = signedIn
        hasConsented = UserDefaults.standard.bool(forKey: "hasConsented")
        marketingOptIn = UserDefaults.standard.bool(forKey: "marketingOptIn")
        hasSeenPlazaIntro = UserDefaults.standard.bool(forKey: "hasSeenPlazaIntro")
        hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome")
        let live = Self.savedLiveAPI
        blockedKeepers = UserDefaults.standard.data(forKey: live ? "blockedKeepers-live" : "blockedKeepers")
            .flatMap { try? JSONDecoder().decode([BlockedKeeper].self, from: $0) } ?? []
        coins = Self.savedCoins(live: live)
        savedLines = UserDefaults.standard.stringArray(forKey: "savedLines") ?? []
        usedFreeTelescope = UserDefaults.standard.bool(forKey: "usedFreeTelescope")
        monthlyFreeTelescopeMonth = UserDefaults.standard.string(forKey: "monthlyFreeTelescopeMonth")
        coinHistory = Self.savedCoinHistory(live: live)
        var saved = UserDefaults.standard.data(forKey: "settings")
            .flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
        // v1.0 hides the membership skies: a saved one goes back to violet.
        // TODO(v1.1): keep it for members once the membership state is known.
        // (`-debugTheme` still sets any sky afterwards, in DebugScreen.prepare.)
        if !saved.sky.isFree { saved.sky = .violet }
        settings = saved
        draft = store.load(StarDraft.self, from: "draft") ?? StarDraft()
        stars = store.load([StarItem].self, from: live ? "stars-live" : "stars") ?? []

        // One-time move of a draft saved by older builds in UserDefaults.
        if let data = UserDefaults.standard.data(forKey: "starDraft") {
            if draft.isEmpty, let old = try? JSONDecoder().decode(StarDraft.self, from: data) {
                saveDraft(old)
            }
            UserDefaults.standard.removeObject(forKey: "starDraft")
        }
    }

    enum SignInProvider { case apple, google }

    /// 02 로그인. Live: Sign in with Apple or Google (or the dev sign-in in Debug builds).
    func signIn(with provider: SignInProvider = .apple) {
        guard useLiveAPI else { isSignedIn = true; return }
        Task { @MainActor in
            do {
                let session: AuthSession
                if Self.usesDevSignIn {
                    session = try await APIClient.shared.devSignIn(name: Self.devLoginName)
                } else if provider == .apple {
                    let token = try await AppleSignIn().identityToken()
                    session = try await APIClient.shared.signIn(provider: "apple", idToken: token)
                } else {
                    let token = try await GoogleSignIn().idToken()
                    session = try await APIClient.shared.signIn(provider: "google", idToken: token)
                }
                hasConsented = !session.needsConsent
                isSignedIn = true
                await refreshMe()
            } catch is AppleSignIn.Cancelled, is GoogleSignIn.Cancelled {
                // Closed the Apple or Google sheet: stay on 02.
            } catch {
                handle(error)
            }
        }
    }

    /// 02-1 초대 계정으로 로그인. False when the id or password is wrong.
    /// Mock: any id and password.
    @MainActor func inviteSignIn(username: String, password: String) async -> Bool {
        guard useLiveAPI else { isSignedIn = true; return true }
        return await inviteSignInLive(username: username, password: password)
    }

    /// 11 가입 동의
    func acceptConsent(marketing: Bool) {
        justConsented = true
        guard useLiveAPI else {
            marketingOptIn = marketing
            hasConsented = true
            return
        }
        Task { @MainActor in
            do {
                let r: ConsentResult = try await APIClient.shared.post("/v1/me/consent", body: ConsentBody(marketing: marketing))
                marketingOptIn = r.marketingOptIn
                hasConsented = !r.needsConsent
            } catch {
                handle(error)
            }
        }
    }

    /// Live: pulls the account (consent, marketing choice, coins) from the server.
    @MainActor func refreshMe() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let me: MeResponse = try await APIClient.shared.get("/v1/me")
            accountID = me.id
            hasConsented = !me.needsConsent
            marketingOptIn = me.marketingOptIn
            coins = me.coins
            nickname = me.nickname
            nicknameNextChange = me.nicknameNextChange
            applyFreeUses(telescopeAvailable: me.freeTelescopeAvailable, star: me.freeStarToday,
                          telescope: me.freeTelescope)
        } catch {
            handle(error)
            return
        }
        await loadStars()
        await loadReports()
        await loadDraft()
        await loadCoins()
        await loadBlocks()
        await loadMembership()
        await PushRegistration.refresh(signedIn: isSignedIn)
    }

    private static func savedCoins(live: Bool) -> Int {
        let key = live ? "coins-live" : "coins"
        if UserDefaults.standard.object(forKey: key) == nil { return live ? 0 : starterCoins }
        return UserDefaults.standard.integer(forKey: key)
    }


    private static func savedCoinHistory(live: Bool) -> [CoinEntry] {
        UserDefaults.standard.data(forKey: live ? "coinHistory-live" : "coinHistory")
            .flatMap { try? JSONDecoder().decode([CoinEntry].self, from: $0) } ?? []
    }

    /// Dev drawer: switches between the mock and the API server. Going live
    /// without a server session goes back to 02 Login.
    func setLiveAPI(_ on: Bool) {
        #if !DEBUG
        return
        #endif
        useLiveAPI = on
        // Each side keeps its own stars and coins on this device.
        stars = store.load([StarItem].self, from: starsFile) ?? []
        coins = Self.savedCoins(live: on)
        coinHistory = Self.savedCoinHistory(live: on)
        guard on else { return }
        Task { @MainActor in
            if await APIClient.shared.isSignedIn {
                await refreshMe()
            } else {
                isSignedIn = false
            }
        }
    }

    /// Turns an API failure into the screen that fits: 39 for an expired session,
    /// 40 for an old app, 41 for maintenance, otherwise a toast with the server's copy.
    @MainActor func handle(_ error: Error) {
        guard let e = error as? APIError else {
            apiMessage = APIError.offline.message
            return
        }
        switch e.code {
        // `unauthorized`: a token the server can't use any more (its keys or
        // database changed). Like an expired session: 39, then sign in again.
        case "token_expired", "signed_out", "unauthorized":
            appNotice = .loginExpired
        case "update_required":
            appNotice = .updateRequired
        case "maintenance":
            appNotice = .maintenance(e.until.map(Self.maintenanceText) ?? "곧 다시 열어요")
        case "consent_required":
            hasConsented = false
        case "rate_limited":
            retryAvailableAt = e.retryAfter.map { Date.now.addingTimeInterval(TimeInterval($0)) }
            appNotice = .rateLimited
        default:
            apiMessage = e.message
        }
    }

    /// e.g. "11월 4일 04:00까지" in Korean time.
    private static func maintenanceText(_ until: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "M월 d일 HH:mm까지"
        return f.string(from: until)
    }

    /// 19: share to / withdraw from the plaza. `quote`: the sentence picked on 19-1.
    func setShared(_ shared: Bool, for id: StarItem.ID, quote: String? = nil) {
        if useLiveAPI {
            Task { @MainActor in
                if shared { _ = await shareStarLive(id, quote: quote) } else { await unshareStarLive(id) }
            }
            return
        }
        guard let i = stars.firstIndex(where: { $0.id == id }) else { return }
        stars[i].sharedToPlaza = shared
        stars[i].shareQuoteMissing = nil
    }

    func deleteStar(_ id: StarItem.ID) {
        guard useLiveAPI else { stars.removeAll { $0.id == id }; return }
        Task { @MainActor in await deleteStarLive(id) }
    }

    /// Stars stay on the device: there is no server copy yet, so clearing them
    /// on sign-out would lose the user's journal.
    /// Mock balance for a new device.
    static let starterCoins = 120
    /// 24 "코인 20개로 켜기" (first one after sign-up, and one a month, free).
    static let telescopeCost = 20
    /// 05: floating is free once a day; from the second star that day, 5 coins.
    /// Keeping quietly is always free.
    static let floatCost = 5

    /// Stars floated today (Korean day on this device).
    var floatedToday: Int {
        stars.filter { $0.isFloated && ($0.createdAt.map(Calendar.current.isDateInToday) ?? false) }.count
    }
    /// Live: today's free float is left (`free_star_today`, Korean day on the server).
    var serverFreeFloat: Bool?
    var isFloatFree: Bool { memberHasStar || ((useLiveAPI ? serverFreeFloat : nil) ?? (floatedToday == 0)) }
    /// 05 「별빛 받고 띄우기」 (the price is on 05-3 / 05-4).
    var floatButtonTitle: String { "별빛 받고 띄우기" }
    /// 17.1: 별빛 없이 띄우기, free and up to ten a day.
    static let unlitDailyLimit = 10
    var unlitToday: Int {
        stars.filter { !$0.isFloated && ($0.createdAt.map(Calendar.current.isDateInToday) ?? false) }.count
    }
    /// 29 from 05: floating would need coins the user doesn't have.
    var floatNeedsCharge: Bool { !isFloatFree && coins < Self.floatCost }

    /// Mock: the month ("2026-11") whose free telescope was used.
    var monthlyFreeTelescopeMonth: String? {
        didSet { UserDefaults.standard.set(monthlyFreeTelescopeMonth, forKey: "monthlyFreeTelescopeMonth") }
    }
    private static var thisMonth: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: .now)
    }

    /// Takes coins if the balance allows it, and records it in 33.
    func spendCoins(_ amount: Int, for title: String = "마음 망원경") -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        coinHistory.insert(CoinEntry(title: title, delta: -amount), at: 0)
        return true
    }

    /// 28 mock purchase. TODO: Credit only after the server verifies a StoreKit receipt.
    func addCoins(_ amount: Int) {
        coins += amount
        coinHistory.insert(CoinEntry(title: "코인 충전", delta: amount), at: 0)
    }

    /// Live: free uses left, from /v1/me and /v1/coins.
    func applyFreeUses(telescopeAvailable: Bool, star: Int?, telescope: Int?) {
        usedFreeTelescope = !(telescope.map { $0 > 0 } ?? telescopeAvailable)
        serverFreeFloat = star.map { $0 > 0 }
    }

    /// The first telescope after sign-up is free, and one each month.
    /// Live: the server's `free_telescope_available`.
    var isTelescopeFree: Bool {
        // v1.1: members get 10 a day (counted by the server), then the usual rules.
        if memberHasTelescope { return true }
        if useLiveAPI { return !usedFreeTelescope }
        return !usedFreeTelescope || monthlyFreeTelescopeMonth != Self.thisMonth
    }

    func useFreeTelescope() {
        if useLiveAPI || !usedFreeTelescope { usedFreeTelescope = true } else { monthlyFreeTelescopeMonth = Self.thisMonth }
    }

    func saveLine(_ line: String) {
        if !savedLines.contains(line) { savedLines.append(line) }
    }

    func toggleResonance(_ id: String) {
        let on = !resonated.contains(id)
        if on { resonated.insert(id) } else { resonated.remove(id) }
        if useLiveAPI { Task { @MainActor in sendResonance(key: id, on: on) } }
    }

    func signOut() {
        isSignedIn = false
        if useLiveAPI {
            // The server keeps the journal; drop this device's copy.
            stars = []
            blockedKeepers = []
            Task {
                await PushRegistration.unregister()
                await APIClient.shared.signOut()
            }
        }
    }

    /// 36 "조용히 간직하기": the star stays, without starlight or analysis.
    func keepInstead(_ id: StarItem.ID) -> StarItem? {
        guard let i = stars.firstIndex(where: { $0.id == id }) else { return nil }
        stars[i].state = .kept
        stars[i].analysis = nil
        stars[i].sharedToPlaza = nil
        return stars[i]
    }

    /// 92: takes every star back from the plaza. Resonance and lines received stay.
    /// TODO: Send to the plaza API.
    func withdrawAllShares() {
        if useLiveAPI {
            Task { @MainActor in await withdrawAllSharesLive() }
            return
        }
        for i in stars.indices where stars[i].isShared {
            stars[i].sharedToPlaza = false
        }
    }

    /// 91: live, deletes the server account first; then removes everything on
    /// this device and goes back to 02 Login.
    func deleteAccount() {
        guard useLiveAPI else { clearLocalAccount(); return }
        Task { @MainActor in
            do {
                try await APIClient.shared.delete("/v1/me")
                await APIClient.shared.forget()
                clearLocalAccount()
            } catch {
                handle(error)
            }
        }
    }

    private func clearLocalAccount() {
        stars = []
        saveDraft(StarDraft())
        coinHistory = []
        savedLines = []
        resonated = []
        settings = AppSettings()
        coins = Self.starterCoins
        usedFreeTelescope = false
        monthlyFreeTelescopeMonth = nil
        hasSeenPlazaIntro = false
        marketingOptIn = false
        hasConsented = false
        nickname = nil
        nicknameNextChange = nil
        isSignedIn = false
        appNotice = .accountDeleted
    }

    /// 93: every star as plain text, newest first.
    func exportText() -> String {
        var out = "YOUNIYA 기록 내보내기\n\n"
        for s in stars {
            out += "■ \(s.title)\n\(s.dateText) · \(s.isFloated ? "별빛 받은 별" : "별빛 없는 별")\n"
            if !s.body.isEmpty { out += "\n\(s.body)\n" }
            out += "\n"
        }
        return out
    }

    /// Dev shortcut to reach `04 Home` quickly.
    /// Dev only: a draft long enough to float (over `minFloatLength`), for checking 05 → 06 → 07.
    func fillLongDraft() {
        saveDraft(StarDraft(mood: .calm, title: "느려도 결국 닿는 하루",
                            body: "오늘은 아침부터 마음이 조금 무거웠다. 알람이 울리기 전에 눈이 떠졌는데, 창밖은 아직 어두웠고 방 안은 이상하게 조용했다. 어제 미처 끝내지 못한 일들이 머릿속을 천천히 지나갔다. 보내지 못한 메일, 미뤄 둔 전화, 그리고 오랫동안 연락하지 못한 친구의 얼굴. 하나하나는 별일 아닌데 한꺼번에 떠오르니 숨이 조금 막히는 것 같았다.\n\n출근길 버스에서는 창가 자리에 앉았다. 유리창에 비친 내 얼굴이 생각보다 지쳐 보여서 괜히 웃음이 났다. 이어폰을 꽂았지만 음악은 틀지 않았다. 사람들의 낮은 목소리, 브레이크 소리, 정류장 안내 방송이 섞여서 오히려 마음이 가라앉았다. 가끔은 아무것도 듣지 않는 시간이 필요하다는 걸 요즘 들어 자주 느낀다.\n\n점심에는 회사 근처 작은 공원에 혼자 앉아 있었다. 바람이 불 때마다 나뭇잎이 반짝였고, 비둘기 몇 마리가 발밑을 서성였다. 휴대폰을 꺼내려다 다시 넣었다. 누구에게 무슨 말을 하고 싶은지 잘 모르겠어서였다. 대신 하늘을 오래 올려다봤다. 구름이 아주 느리게 움직이고 있었다. 저렇게 느려도 결국은 어딘가에 닿겠지, 하는 생각이 들었다.\n\n오후에는 회의가 길어졌다. 내 의견을 말할 차례가 왔을 때 목소리가 조금 떨렸다. 다들 고개를 끄덕여 주었지만 회의가 끝나고 나서도 내가 한 말을 몇 번이나 되짚었다. 너무 조심스러웠나, 아니면 너무 앞서 나갔나. 그런 생각을 하다가 문득, 나는 왜 이렇게 나 자신에게 엄격할까 싶었다. 친구가 똑같이 말했다면 나는 분명 잘했다고 말해 줬을 텐데.\n\n퇴근길에는 일부러 한 정거장 먼저 내려서 걸었다. 해가 지면서 하늘이 보라색에서 남색으로 천천히 바뀌었다. 편의점 불빛, 신호등, 창문마다 켜지는 작은 불들이 하나씩 별처럼 보였다. 그 사이를 걸으면서 오늘 하루를 조금씩 내려놓았다.\n\n집에 와서 따뜻한 차를 한 잔 끓였다. 오랫동안 연락하지 못한 친구에게 짧은 메시지를 보냈다. 잘 지내냐고, 문득 생각났다고. 답장은 아직 오지 않았지만 보낸 것만으로도 마음 한쪽이 가벼워졌다. 내일은 오늘보다 조금 더 나에게 다정해 보기로 한다. 완벽하지 않아도 괜찮다고, 느려도 결국 닿는다고, 오늘 본 구름처럼."))
    }

    func fillSampleStars() {
        var samples = StarItem.samples
        samples[0].report = .sample
        stars = samples
    }

    /// Creates the star's telescope report the first time it is opened.
    /// Returns false for stars without one (kept stars).
    @discardableResult
    func prepareReport(for id: StarItem.ID) -> Bool {
        guard let i = stars.firstIndex(where: { $0.id == id }), stars[i].isFloated else { return false }
        if stars[i].report == nil {
            if useLiveAPI {
                Task { @MainActor in requestReportLive(for: id) }
            } else {
                stars[i].report = TelescopeReport.mock(for: stars[i])
            }
        }
        return true
    }

    func report(for id: StarItem.ID) -> TelescopeReport? {
        stars.first(where: { $0.id == id })?.report
    }

    func saveReport(for id: StarItem.ID) {
        guard let i = stars.firstIndex(where: { $0.id == id }) else { return }
        stars[i].report?.isSaved = true
        if useLiveAPI, let serverID = stars[i].report?.serverID { saveReportLive(serverID) }
    }

    /// The question shown on 14 Rewrite: the report's question if there is one.
    func rewriteQuestion(for star: StarItem) -> String {
        star.report?.question ?? TelescopeReport.mock(for: star).question
    }

    /// 05-2 고쳐 쓰기: the working copy per original star (memory only; the
    /// original stays as it is until a new star is floated).
    var reviseDrafts: [StarItem.ID: StarDraft] = [:]

    /// Mock 05-5: the rewritten text becomes a new star joined to the original.
    func publishRevision(of original: StarItem, draft d: StarDraft, floated: Bool) -> StarItem {
        var star = makeStar(d, floated: floated)
        star.rewriteOf = original.id
        stars.insert(star, at: 0)
        reviseDrafts[original.id] = nil
        linkLocally(star.id, [original.id])
        return star
    }

    /// Saves a rewrite (14) as a new star with the same title and mood.
    /// Leaves the 05 draft untouched.
    @discardableResult
    func publishRewrite(of previous: StarItem, body: String, floated: Bool) -> StarItem {
        let d = StarDraft(mood: previous.mood, title: previous.title, body: body)
        let star = makeStar(d, floated: floated)
        stars.insert(star, at: 0)
        // 14 별 잇기 · 새 별 쓰기: the new star is joined to the one it follows.
        linkLocally(star.id, [previous.id])
        return stars[0]
    }

    // MARK: Nebula stats (08)
    var floatedCount: Int { stars.filter(\.isFloated).count }
    var deepCount: Int { stars.filter { $0.analysis?.isDeep == true }.count }
    var supernovaCount: Int { stars.filter { $0.analysis?.isSupernova == true }.count }
    /// 104/105: a star can be floated (analyzed) from 50 characters; keeping has no minimum.
    static let minFloatLength = 50
    func saveDraft(_ d: StarDraft) {
        if d != draft { syncDraft(d) }
        draft = d
        if d.isEmpty {
            store.remove("draft")
        } else {
            store.save(d, to: "draft")
        }
    }

    /// Adds the draft as a new star at the top of the list and clears the draft.
    /// Floated stars get a (mock) analysis.
    @discardableResult
    func publish(_ d: StarDraft, floated: Bool) -> StarItem {
        let star = makeStar(d, floated: floated)
        stars.insert(star, at: 0)
        saveDraft(StarDraft())
        return star
    }

    /// Mock 12 "별 띄우기" on a kept star: analyzed now, same writing date.
    func floatKeptMock(_ id: StarItem.ID) -> StarItem? {
        guard let i = stars.firstIndex(where: { $0.id == id }), !stars[i].isFloated else { return nil }
        let s = stars[i]
        let analysis = StarAnalysis.mock(for: StarDraft(mood: s.mood, title: s.title, body: s.body))
        stars[i].analysis = analysis
        stars[i].state = .floated(starlight: analysis.starlight)
        return stars[i]
    }

    private func makeStar(_ d: StarDraft, floated: Bool) -> StarItem {
        let title = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let analysis = floated ? StarAnalysis.mock(for: d) : nil
        return StarItem(
            title: title.isEmpty ? "제목 없는 별" : title,
            dateText: Self.dateText(.now),
            state: floated ? .floated(starlight: analysis?.starlight) : .kept,
            mood: d.mood,
            extraMoods: d.extraMoods,
            body: d.body,
            analysis: analysis,
            createdAt: .now
        )
    }

    /// e.g. "11월 3일 · 21:30"
    private static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 · HH:mm"
        return f.string(from: date)
    }
}

// MARK: - API payloads (account)

private struct ConsentBody: Encodable {
    var terms = true
    var privacy = true
    var sensitive = true
    var marketing: Bool
}

private struct ConsentResult: Decodable {
    var needsConsent: Bool
    var marketingOptIn: Bool
}

/// GET /v1/me
struct MeResponse: Decodable {
    var id: String
    var provider: String
    var needsConsent: Bool
    var marketingOptIn: Bool
    var coins: Int
    var freeTelescopeAvailable: Bool
    var freeStarToday: Int?
    var freeTelescope: Int?
    /// 15장 (newer servers).
    var nickname: String?
    var nicknameNextChange: Date?
}

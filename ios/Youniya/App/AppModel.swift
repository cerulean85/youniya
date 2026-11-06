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

    var isDeep: Bool { depth >= 0.7 }
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
            tones: second == draft.mood ? [draft.mood] : [draft.mood, second]
        )
    }
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
    var isSaved = false

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
            question: questions[star.mood] ?? ""
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
        question: "쉬고 싶다는 마음은 어디에서 오고 있을까요?"
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
    var body: String = ""
    var analysis: StarAnalysis?
    var report: TelescopeReport?
    /// Nil for stars saved before this field existed (and the samples).
    var createdAt: Date?
    /// The star this one rewrites (14 Rewrite).
    var rewriteOf: UUID?
    /// Shared anonymously to the plaza (19). Optional so older saves still load.
    var sharedToPlaza: Bool?

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

    /// Sample stars from the Figma `04 Home` frame.
    static let samples: [StarItem] = [
        StarItem(title: "느리게 흘러간 하루", dateText: "11월 3일 · 21:30", state: .floated(starlight: 742),
                 body: "오늘은 마음이 조금 느리게 흘렀어요. 해야 할 일은 많았는데 자꾸만 창밖을 보게 됐어요.\n\n기다리는 일이 이렇게 오래 걸릴 줄 몰랐어요. 그래도 그 느림이 싫지만은 않았어요. 어쩌면 나는 쉬고 싶었는지도 몰라요.",
                 analysis: StarAnalysis(starlight: 742, depth: 0.82, clarity: 0.55, weight: 0.55,
                                        observation: "그런 마음이 머물렀군요.\n오늘의 별은 조용히 숨을 고르고 있어요.",
                                        telescopeTeaser: "기다림 속에 작은 안도가 섞여 있어요.",
                                        tones: [.calm, .sorrow])),
        StarItem(title: "말하지 못한 이야기", dateText: "11월 2일 · 23:10", state: .kept),
        StarItem(title: "비 오는 날의 안도", dateText: "11월 1일 · 22:04", state: .floated(starlight: 742)),
        StarItem(title: "다시 꺼내본 약속", dateText: "10월 30일 · 20:48", state: .floated(starlight: 742)),
    ]
}

/// The star being written in `05 Star Making`. Kept across close/reopen.
struct StarDraft: Codable, Equatable {
    var mood: Mood = .calm
    var title: String = ""
    var body: String = ""

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
}

/// 87 Settings values. New fields need defaults so old saves still decode.
/// 71 하늘에 띄우기 options.
struct NebulaSkyShare: Codable, Equatable {
    var name: String
    var receiveLines = true
    var showQuote = false
    var date = Date.now
}

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
        sky = (try? c.decodeIfPresent(SkyTheme.self, forKey: .sky)) ?? d.sky
    }
}

/// App-wide state. No backend yet: sign-in is mocked; stars are saved on device.
@Observable
final class AppModel {
    var isSignedIn: Bool {
        didSet { UserDefaults.standard.set(isSignedIn, forKey: "isSignedIn") }
    }
    /// 11 Consent accepted (required terms). Asked once per device.
    var hasConsented: Bool {
        didSet { UserDefaults.standard.set(hasConsented, forKey: "hasConsented") }
    }
    /// Optional "새 기능·혜택 알림" consent.
    var marketingOptIn: Bool {
        didSet { UserDefaults.standard.set(marketingOptIn, forKey: "marketingOptIn") }
    }
    /// 56–60 story is shown the first time the nebula tab opens.
    var hasSeenNebulaStory: Bool {
        didSet { UserDefaults.standard.set(hasSeenNebulaStory, forKey: "hasSeenNebulaStory") }
    }
    /// 21 Plaza Welcome is shown until "둘러보기" is tapped once.
    var hasSeenPlazaIntro: Bool {
        didSet { UserDefaults.standard.set(hasSeenPlazaIntro, forKey: "hasSeenPlazaIntro") }
    }
    /// Coin balance. TODO: Comes from the store/server; mocked on device.
    var coins: Int {
        didSet { UserDefaults.standard.set(coins, forKey: "coins") }
    }
    /// 33 Coin history, newest first. Not sensitive, so kept in UserDefaults.
    var coinHistory: [CoinEntry] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(coinHistory), forKey: "coinHistory") }
    }
    /// 87 Settings
    var settings: AppSettings {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: "settings") }
    }
    /// Set once the free first telescope ("처음 한 번은 무료", 07) is used.
    var usedFreeTelescope: Bool {
        didSet { UserDefaults.standard.set(usedFreeTelescope, forKey: "usedFreeTelescope") }
    }
    /// 23 lines the user saved from others' stars (anonymous, no source kept).
    var savedLines: [String] {
        didSet { UserDefaults.standard.set(savedLines, forKey: "savedLines") }
    }
    /// 83: the story was polished once (coins spent); keeps the bridging lines.
    var storyPolished: Bool {
        didSet { UserDefaults.standard.set(storyPolished, forKey: "storyPolished") }
    }
    /// 100/101: other people's lines this user reported (hidden for them).
    var reportedLines: Set<String> {
        didSet { UserDefaults.standard.set(Array(reportedLines), forKey: "reportedLines") }
    }
    /// 71: my nebula floated to the sky, and what goes with it. TODO: Plaza API.
    var skyShare: NebulaSkyShare? {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(skyShare), forKey: "skyShare") }
    }
    /// 74: my one line per plaza nebula, by nebula name. TODO: Plaza API.
    var nebulaLines: [String: String] {
        didSet { UserDefaults.standard.set(nebulaLines, forKey: "nebulaLines") }
    }
    /// Nebulae the user drew (51–55), newest last.
    var drawnNebulae: [DrawnNebula] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(drawnNebulae), forKey: "drawnNebulae") }
    }
    /// Shown until the user draws and names one (08, 77, 83). TODO: From the backend.
    static let defaultNebulaName = "늦은 밤의 등대자리"
    /// The user's nebula name: the latest drawn one, or the default.
    var nebulaName: String { drawnNebulae.last?.name ?? Self.defaultNebulaName }
    /// 83 "서사 다듬기"
    static let storyPolishCost = 20
    /// 39–41: a notice covering the whole app. Not saved.
    var appNotice: AppNotice?
    /// Dev only: makes analysis or payment fail until turned off (35, 36, 38).
    var simulatedFailure: SimulatedFailure?
    /// Dev only: screens show their 47–50, 110–112 skeletons for a moment before content.
    /// Also on with the `-simulateLoading YES` launch argument. Not saved.
    var simulateLoading = UserDefaults.standard.bool(forKey: "simulateLoading")
    /// Dev: talk to the API server (`APIConfig.baseURL`) instead of the on-device
    /// mock. Saved; also `-useLiveAPI YES`. Features move over to it step by step.
    var useLiveAPI: Bool = UserDefaults.standard.bool(forKey: "useLiveAPI") {
        didSet { UserDefaults.standard.set(useLiveAPI, forKey: "useLiveAPI") }
    }
    /// A server or network message for the root toast.
    var apiMessage: String?
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
        didSet { store.save(stars, to: starsFile) }
    }
    private var starsFile: String { useLiveAPI ? "stars-live" : "stars" }
    /// Autosaved draft, saved to `draft.json`.
    private(set) var draft: StarDraft
    @ObservationIgnored private let store: LocalStore

    init(store: LocalStore = LocalStore()) {
        self.store = store
        isSignedIn = UserDefaults.standard.bool(forKey: "isSignedIn")
        hasConsented = UserDefaults.standard.bool(forKey: "hasConsented")
        marketingOptIn = UserDefaults.standard.bool(forKey: "marketingOptIn")
        hasSeenPlazaIntro = UserDefaults.standard.bool(forKey: "hasSeenPlazaIntro")
        hasSeenNebulaStory = UserDefaults.standard.bool(forKey: "hasSeenNebulaStory")
        coins = UserDefaults.standard.object(forKey: "coins") == nil ? Self.starterCoins : UserDefaults.standard.integer(forKey: "coins")
        savedLines = UserDefaults.standard.stringArray(forKey: "savedLines") ?? []
        usedFreeTelescope = UserDefaults.standard.bool(forKey: "usedFreeTelescope")
        storyPolished = UserDefaults.standard.bool(forKey: "storyPolished")
        nebulaLines = UserDefaults.standard.dictionary(forKey: "nebulaLines") as? [String: String] ?? [:]
        reportedLines = Set(UserDefaults.standard.stringArray(forKey: "reportedLines") ?? [])
        skyShare = UserDefaults.standard.data(forKey: "skyShare")
            .flatMap { try? JSONDecoder().decode(NebulaSkyShare.self, from: $0) }
        drawnNebulae = UserDefaults.standard.data(forKey: "drawnNebulae")
            .flatMap { try? JSONDecoder().decode([DrawnNebula].self, from: $0) } ?? []
        coinHistory = UserDefaults.standard.data(forKey: "coinHistory")
            .flatMap { try? JSONDecoder().decode([CoinEntry].self, from: $0) } ?? []
        settings = UserDefaults.standard.data(forKey: "settings")
            .flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
        draft = store.load(StarDraft.self, from: "draft") ?? StarDraft()
        stars = store.load([StarItem].self, from: useLiveAPI ? "stars-live" : "stars") ?? []

        // One-time move of a draft saved by older builds in UserDefaults.
        if let data = UserDefaults.standard.data(forKey: "starDraft") {
            if draft.isEmpty, let old = try? JSONDecoder().decode(StarDraft.self, from: data) {
                saveDraft(old)
            }
            UserDefaults.standard.removeObject(forKey: "starDraft")
        }
    }

    /// 02 로그인. Live: the dev sign-in until Sign in with Apple / Google is wired up.
    func signIn() {
        guard useLiveAPI else { isSignedIn = true; return }
        Task { @MainActor in
            do {
                let session = try await APIClient.shared.devSignIn(name: Self.devLoginName)
                hasConsented = !session.needsConsent
                isSignedIn = true
                await refreshMe()
            } catch {
                handle(error)
            }
        }
    }

    /// 11 가입 동의
    func acceptConsent(marketing: Bool) {
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
            hasConsented = !me.needsConsent
            marketingOptIn = me.marketingOptIn
            coins = me.coins
            usedFreeTelescope = !me.freeTelescopeAvailable
        } catch {
            handle(error)
            return
        }
        await loadStars()
        await loadDraft()
    }

    /// Dev drawer: switches between the mock and the API server. Going live
    /// without a server session goes back to 02 Login.
    func setLiveAPI(_ on: Bool) {
        useLiveAPI = on
        // Each side keeps its own stars on this device.
        stars = store.load([StarItem].self, from: starsFile) ?? []
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
        case "token_expired", "signed_out":
            appNotice = .loginExpired
        case "update_required":
            appNotice = .updateRequired
        case "maintenance":
            appNotice = .maintenance(e.until.map(Self.maintenanceText) ?? "곧 다시 열어요")
        case "consent_required":
            hasConsented = false
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

    /// 19: share to / withdraw from the plaza.
    /// TODO: send to the plaza API; for now it's a local flag.
    func setShared(_ shared: Bool, for id: StarItem.ID) {
        guard let i = stars.firstIndex(where: { $0.id == id }) else { return }
        stars[i].sharedToPlaza = shared
    }

    func deleteStar(_ id: StarItem.ID) {
        guard useLiveAPI else { stars.removeAll { $0.id == id }; return }
        Task { @MainActor in await deleteStarLive(id) }
    }

    /// Stars stay on the device: there is no server copy yet, so clearing them
    /// on sign-out would lose the user's journal.
    /// Mock balance for a new device.
    static let starterCoins = 120
    /// 24 "코인 30개로 켜기"
    static let telescopeCost = 30

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

    /// The first telescope is free. Users who already have a report
    /// (from before this rule) have used it.
    var isTelescopeFree: Bool {
        !usedFreeTelescope && !stars.contains { $0.report != nil }
    }

    func useFreeTelescope() { usedFreeTelescope = true }

    func saveLine(_ line: String) {
        if !savedLines.contains(line) { savedLines.append(line) }
    }

    func toggleResonance(_ id: String) {
        if resonated.contains(id) { resonated.remove(id) } else { resonated.insert(id) }
    }

    func signOut() {
        isSignedIn = false
        if useLiveAPI {
            // The server keeps the journal; drop this device's copy.
            stars = []
            Task { await APIClient.shared.signOut() }
        }
    }

    /// 54 저장하기
    func saveDrawnNebula(_ n: DrawnNebula) { drawnNebulae.append(n) }

    /// 55 우주 광장에 나누기. TODO: Send to the plaza API.
    func shareDrawnNebula(_ id: DrawnNebula.ID) {
        guard let i = drawnNebulae.firstIndex(where: { $0.id == id }) else { return }
        drawnNebulae[i].shared = true
    }

    /// 36 "조용히 품기": the star stays, without starlight or analysis.
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
        drawnNebulae = []
        storyPolished = false
        nebulaLines = [:]
        reportedLines = []
        skyShare = nil
        hasSeenPlazaIntro = false
        hasSeenNebulaStory = false
        marketingOptIn = false
        hasConsented = false
        isSignedIn = false
        appNotice = .accountDeleted
    }

    /// 93: every star as plain text, newest first.
    func exportText() -> String {
        var out = "YOUNIYA 기록 내보내기\n\n"
        for s in stars {
            out += "■ \(s.title)\n\(s.dateText) · \(s.isFloated ? "띄운 별" : "품은 별")\n"
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
        if stars[i].report == nil { stars[i].report = TelescopeReport.mock(for: stars[i]) }
        return true
    }

    func report(for id: StarItem.ID) -> TelescopeReport? {
        stars.first(where: { $0.id == id })?.report
    }

    func saveReport(for id: StarItem.ID) {
        guard let i = stars.firstIndex(where: { $0.id == id }) else { return }
        stars[i].report?.isSaved = true
    }

    /// The question shown on 14 Rewrite: the report's question if there is one.
    func rewriteQuestion(for star: StarItem) -> String {
        star.report?.question ?? TelescopeReport.mock(for: star).question
    }

    /// Saves a rewrite (14) as a new star with the same title and mood.
    /// Leaves the 05 draft untouched.
    @discardableResult
    func publishRewrite(of previous: StarItem, body: String, floated: Bool) -> StarItem {
        let d = StarDraft(mood: previous.mood, title: previous.title, body: body)
        var star = makeStar(d, floated: floated)
        star.rewriteOf = previous.id
        stars.insert(star, at: 0)
        return star
    }

    // MARK: Nebula stats (08)
    var floatedCount: Int { stars.filter(\.isFloated).count }
    var deepCount: Int { stars.filter { $0.analysis?.isDeep == true }.count }
    var supernovaCount: Int { stars.filter { $0.analysis?.isSupernova == true }.count }
    /// 104/105: a star can be floated (analyzed) from 1,000 characters; keeping has no minimum.
    static let minFloatLength = 1000
    /// Deep stars needed to reach the next nebula stage.
    static let nextStageDeepStars = 15

    /// 86 성운이 자라는 네 걸음. 1 첫 별들 · 2 따뜻한 빛줄기 (깊은 별 6) ·
    /// 3 짙어지는 성운 (깊은 별 15 · 별빛 900 이상 1번) · 4 온전한 은하수 (깊은 별 30 · 여러 감정의 결).
    /// TODO: The backend decides the stage.
    var growthStage: Int {
        let bright = stars.contains { ($0.starlightValue ?? 0) >= 900 }
        let moods = Set(stars.filter(\.isFloated).map(\.mood)).count
        if deepCount >= 30 && moods >= 3 { return 4 }
        if deepCount >= Self.nextStageDeepStars && bright { return 3 }
        if deepCount >= 6 { return 2 }
        return 1
    }

    static let stageNames = ["첫 별들", "따뜻한 빛줄기", "짙어지는 성운", "온전한 은하수"]
    var stageName: String { Self.stageNames[growthStage - 1] }

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

    private func makeStar(_ d: StarDraft, floated: Bool) -> StarItem {
        let title = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let analysis = floated ? StarAnalysis.mock(for: d) : nil
        return StarItem(
            title: title.isEmpty ? "제목 없는 별" : title,
            dateText: Self.dateText(.now),
            state: floated ? .floated(starlight: analysis?.starlight) : .kept,
            mood: d.mood,
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
}

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
    /// 21 Plaza Welcome is shown until "둘러보기" is tapped once.
    var hasSeenPlazaIntro: Bool {
        didSet { UserDefaults.standard.set(hasSeenPlazaIntro, forKey: "hasSeenPlazaIntro") }
    }
    /// Coin balance. TODO: Comes from the store/server; mocked on device.
    var coins: Int {
        didSet { UserDefaults.standard.set(coins, forKey: "coins") }
    }
    /// 23 lines the user saved from others' stars (anonymous, no source kept).
    var savedLines: [String] {
        didSet { UserDefaults.standard.set(savedLines, forKey: "savedLines") }
    }
    /// Plaza nebulae this user left a resonance on (09, 22).
    /// TODO: Send to the plaza API; kept in memory for now.
    var resonated: Set<String> = []
    /// Saved to `stars.json` on every change.
    var stars: [StarItem] = [] {
        didSet { store.save(stars, to: "stars") }
    }
    /// Autosaved draft, saved to `draft.json`.
    private(set) var draft: StarDraft
    @ObservationIgnored private let store: LocalStore

    init(store: LocalStore = LocalStore()) {
        self.store = store
        isSignedIn = UserDefaults.standard.bool(forKey: "isSignedIn")
        hasConsented = UserDefaults.standard.bool(forKey: "hasConsented")
        marketingOptIn = UserDefaults.standard.bool(forKey: "marketingOptIn")
        hasSeenPlazaIntro = UserDefaults.standard.bool(forKey: "hasSeenPlazaIntro")
        coins = UserDefaults.standard.object(forKey: "coins") == nil ? Self.starterCoins : UserDefaults.standard.integer(forKey: "coins")
        savedLines = UserDefaults.standard.stringArray(forKey: "savedLines") ?? []
        draft = store.load(StarDraft.self, from: "draft") ?? StarDraft()
        stars = store.load([StarItem].self, from: "stars") ?? []

        // One-time move of a draft saved by older builds in UserDefaults.
        if let data = UserDefaults.standard.data(forKey: "starDraft") {
            if draft.isEmpty, let old = try? JSONDecoder().decode(StarDraft.self, from: data) {
                saveDraft(old)
            }
            UserDefaults.standard.removeObject(forKey: "starDraft")
        }
    }

    func signIn() { isSignedIn = true }

    func acceptConsent(marketing: Bool) {
        marketingOptIn = marketing
        hasConsented = true
    }

    /// 19: share to / withdraw from the plaza.
    /// TODO: send to the plaza API; for now it's a local flag.
    func setShared(_ shared: Bool, for id: StarItem.ID) {
        guard let i = stars.firstIndex(where: { $0.id == id }) else { return }
        stars[i].sharedToPlaza = shared
    }

    func deleteStar(_ id: StarItem.ID) {
        stars.removeAll { $0.id == id }
    }

    /// Stars stay on the device: there is no server copy yet, so clearing them
    /// on sign-out would lose the user's journal.
    /// Mock balance for a new device.
    static let starterCoins = 120
    /// 24 "코인 30개로 켜기"
    static let telescopeCost = 30

    /// Takes coins if the balance allows it.
    func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        return true
    }

    func saveLine(_ line: String) {
        if !savedLines.contains(line) { savedLines.append(line) }
    }

    func toggleResonance(_ id: String) {
        if resonated.contains(id) { resonated.remove(id) } else { resonated.insert(id) }
    }

    func signOut() {
        isSignedIn = false
    }

    /// Dev shortcut to reach `04 Home` quickly.
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
    /// Deep stars needed to reach the next nebula stage.
    static let nextStageDeepStars = 15

    func saveDraft(_ d: StarDraft) {
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

import Foundation

/// `-debugScreen <Figma frame number>` (Debug builds only): opens that Mobile
/// page frame on launch with mock data, for visual review without taps.
/// e.g. `-debugScreen 07`, `-debugScreen 28-1`. Unsupported numbers are ignored.
///
/// The app-wide part (sign-in, notices, tabs, pushed pages) is set up here and in
/// `MainView`; screens with their own sheet or step read `DebugScreen.is(...)`
/// in their initial state.
enum DebugScreen {
    static var current: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "debugScreen").map(normalized)
        #else
        nil
        #endif
    }

    /// True when the launch asks for one of `numbers` ("7" and "07" both match).
    static func `is`(_ numbers: String...) -> Bool {
        guard let current else { return false }
        return numbers.map(normalized).contains(current)
    }

    private static func normalized(_ s: String) -> String {
        let parts = s.split(separator: "-", maxSplits: 1)
        let head = String(Int(parts.first ?? "") ?? 0)
        return parts.count > 1 ? head + "-" + parts[1] : head
    }

    /// Frames that open (see `prepare` and `MainView.openDebugScreen`).
    /// Not supported: 30/67 (popup menu, the app uses the 67-1 drawer), 42 (toast
    /// sheet), 52–55/84/85 (later drawing steps), 57–60 (later story pages),
    /// 63/64 (later birth stages), 88 (telescope observing), 103 (plaza filter).
    static let supported: Set<String> = Set("""
    1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 28-1 29 31 32 33 34 35 36 37 38
    39 40 41 43 44 45 46 47 48 49 50 51 56 61 62 65 66 67-1 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83
    86 87 89 90 91 92 93 94 95 96 97 98 99 100 101 102 104 105 106 107 108 109 110 111 112 113 114 115 116 117
    118 119 120 120-1 121 122 122-1 86-1 19-1 71-1
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    /// App-wide state for the screen, before the first page shows.
    @MainActor static func prepare(_ model: AppModel) {
        #if DEBUG
        // `-debugTheme violet|aurora|ember|ocean|rose`: 68 우주의 색 for the review.
        if let raw = UserDefaults.standard.string(forKey: "debugTheme"), let theme = SkyTheme(rawValue: raw) {
            model.settings.sky = theme
        }
        guard let s = current, supported.contains(s) else { return }
        UserDefaults.standard.set(false, forKey: "useLiveAPI")
        model.useLiveAPI = false
        model.isSignedIn = s != "2"
        model.hasConsented = s != "11"
        model.hasSeenNebulaStory = s != "56"
        model.hasSeenPlazaIntro = s != "21"
        model.simulatedFailure = nil
        if s == "3" {
            model.stars = []
        } else if model.stars.filter(\.isFloated).count < 3 || model.stars.first?.report == nil
                    // 19-1 / 71-1 show the masked name in the current sample text.
                    || s == "19-1" || s == "71-1" {
            model.fillSampleStars()
        }
        switch s {
        case "39": model.appNotice = .loginExpired
        case "40": model.appNotice = .updateRequired
        case "41": model.appNotice = .maintenance("11월 4일 02:00~04:00")
        case "113": model.appNotice = .accountDeleted
        case "120": model.appNotice = .rateLimited
        case "120-1":
            model.retryAvailableAt = .now.addingTimeInterval(170)  // "3분 뒤"
            model.appNotice = .rateLimited
        case "99", "100", "106":
            model.nebulaLines[GalaxyNebula.samples[0].name] = nil  // not left a line yet
            model.reportedLines.remove("그 문장, 저도 오늘 쓰고 싶던 말이에요.")
        case "118":
            if !model.stars.contains(where: { !$0.isFloated }) { model.fillSampleStars() }
        case "80":
            if model.drawnNebulae.isEmpty {
                model.drawnNebulae = [DrawnNebula(name: AppModel.defaultNebulaName, silhouette: "lighthouse",
                                                  starIDs: model.stars.filter(\.isFloated).map(\.id))]
            }
        case "69":
            model.resonated.insert("nebula:" + GalaxyNebula.samples[0].name)
            for star in model.stars.filter(\.isFloated).prefix(2) { model.setShared(true, for: star.id) }
        case "47", "48", "49", "50", "110", "111", "112":
            UserDefaults.standard.set(600, forKey: "simulateLoadingSeconds")
            model.simulateLoading = true
        case "98":
            for i in model.stars.indices { model.stars[i].report = nil }
        case "108": model.coinHistory = []
        case "29": model.coins = 10  // fewer than the 30 a telescope needs
        case "109":
            // Fewer than three floated stars.
            model.stars = model.stars.filter { !$0.isFloated } + model.stars.filter(\.isFloated).prefix(2)
        case "101":
            model.reportedLines.insert("그 문장, 저도 오늘 쓰고 싶던 말이에요.")
        case "107":
            model.nebulaLines[GalaxyNebula.samples[0].name] = "천천히 와도 괜찮아요."
        case "119":
            model.stars = model.stars.filter(\.isFloated)
        case "121":
            if !model.coinHistory.contains(where: { $0.kind == "refund" }) {
                model.coinHistory.insert(CoinEntry(title: "환불", delta: -120, date: .now.addingTimeInterval(-86_400),
                                                   kind: "refund"), at: 0)
            }
        case "17", "92", "76":
            for star in model.stars.filter(\.isFloated).prefix(2) { model.setShared(true, for: star.id) }
        case "18":
            for star in model.stars where star.isShared { model.setShared(false, for: star.id) }
        case "96":
            model.drawnNebulae = []
        default: break
        }
        #endif
    }

    /// A floated sample star with a body, analysis and report.
    @MainActor static func floatedStar(_ model: AppModel) -> StarItem? {
        model.stars.first { $0.isFloated && $0.analysis != nil } ?? model.stars.first(where: \.isFloated)
    }

    @MainActor static func keptStar(_ model: AppModel) -> StarItem? {
        model.stars.first { !$0.isFloated }
    }
}

import SwiftUI

// MARK: - 83 별자리 이야기

/// `GET /v1/constellations/{month}/story`: each star's key sentence in time
/// order. The sentences are never changed.
struct ServerStory: Decodable {
    struct Entry: Decodable {
        var starId: String
        var title: String
        var sentence: String
    }
    var entries: [Entry]
}

// MARK: - 69 오늘 밤

private struct Tonight: Decodable {
    var count: Int
    var mine: Int
}

extension AppModel {
    /// Live 69: stars floated today across everyone (Korean day).
    @MainActor func loadTonight() async {
        guard useLiveAPI, isSignedIn else { return }
        if let t: Tonight = try? await APIClient.shared.get("/v1/plaza/tonight") {
            tonightCount = t.count
            tonightMine = t.mine
        }
    }
}

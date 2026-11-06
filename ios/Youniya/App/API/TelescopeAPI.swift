import Foundation

// MARK: - Payloads

private struct ServerReportBody: Decodable {
    struct Lens: Decodable { var label: String; var value: Double; var note: String }
    struct Emotion: Decodable { var mood: Mood; var percent: Int }
    var starName: String
    var lenses: [Lens]
    var emotions: [Emotion]
    var evidence: String
    var question: String
}

private struct ServerReport: Decodable {
    var id: String
    var saved: Bool
    var starIds: [String]
    var report: ServerReportBody
    /// Only on create.
    var coins: Int?
}

private struct ReportList: Decodable {
    struct Item: Decodable { var id: String; var starCount: Int }
    var items: [Item]
}

private struct ReportIn: Encodable {
    var starIds: [String]
}

private extension TelescopeReport {
    init(_ r: ServerReport) {
        self.init(
            starName: r.report.starName,
            lenses: r.report.lenses.map { Lens(label: $0.label, value: $0.value, note: $0.note) },
            emotions: r.report.emotions.map { Share(mood: $0.mood, percent: $0.percent) },
            evidence: r.report.evidence,
            question: r.report.question,
            isSaved: r.saved,
            serverID: r.id
        )
    }
}

// MARK: - AppModel (live telescope)

extension AppModel {
    /// Live 24 → 25: asks the server for one star's report. The server charges
    /// (or uses the free first one) only once the report exists. Runs once per
    /// star at a time; 10 waits on `pendingReports` while it does.
    @MainActor func requestReportLive(for id: StarItem.ID) {
        guard !pendingReports.contains(id) else { return }
        pendingReports.insert(id)
        Task { @MainActor in
            defer { pendingReports.remove(id) }
            do {
                let r: ServerReport = try await APIClient.shared.post("/v1/telescope/reports",
                                                                       body: ReportIn(starIds: [id.apiID]))
                if let i = stars.firstIndex(where: { $0.id == id }) { stars[i].report = TelescopeReport(r) }
                if let c = r.coins { coins = c }
                usedFreeTelescope = true
                await loadCoins()
            } catch {
                handle(error)
            }
        }
    }

    /// Live 26: attaches the server's one-star reports to their stars.
    /// TODO: Weekly reports over several stars (98 with no star chosen) have no
    /// single star to hang on; show them once 26 lists reports by id.
    @MainActor func loadReports() async {
        guard useLiveAPI, isSignedIn else { return }
        do {
            let list: ReportList = try await APIClient.shared.get("/v1/telescope/reports")
            for item in list.items where item.starCount == 1 {
                let r: ServerReport = try await APIClient.shared.get("/v1/telescope/reports/\(item.id)")
                guard let starID = r.starIds.first.flatMap(UUID.init(uuidString:)),
                      let i = stars.firstIndex(where: { $0.id == starID }),
                      stars[i].report?.serverID != r.id else { continue }
                stars[i].report = TelescopeReport(r)
            }
        } catch {
            handle(error)
        }
    }

    /// Live 10 "리포트 보관하기"
    func saveReportLive(_ serverID: String) {
        Task { @MainActor in
            do {
                try await APIClient.shared.sendRaw("POST", "/v1/telescope/reports/\(serverID)/save")
            } catch {
                handle(error)
            }
        }
    }
}

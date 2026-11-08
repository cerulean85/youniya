import SwiftUI

/// Signed-in shell: tab content, custom tab bar with the compose FAB,
/// pushed pages (left-edge swipe goes back) and a right-edge drawer menu.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: SkyTab = .sky
    /// Pushed pages, bottom to top. A back swipe pops the top one.
    @State private var stack: [Entry] = []

    private struct Entry: Identifiable {
        let id = UUID()
        var route: Route
    }
    @State private var drawerOpen = false
    /// The home-indicator inset, for the tab bar (0 on iPhone SE).
    @State private var bottomSafeArea: CGFloat = 0
    /// 115/118: the records tab filter (the menu's "간직한 별" opens it on .kept).
    @State private var recordsFilter: RecordsFilter = .all
    /// 42 toast shown over whatever page is on top.
    @State private var toast: ToastCardMessage?
    /// 03-1 환영 안내 (once, over 03).
    @State private var showWelcome = false
    @State private var welcomeHeight: CGFloat = 460

    /// Pages that slide in over the tabs.
    enum Route: Equatable {
        /// 05 flow, or 14 Rewrite when a star ID is given.
        case compose(rewriteOf: StarItem.ID? = nil)
        case detail(StarItem.ID)
        case report(StarItem.ID)
        case records   // 17
        case kept      // 18
        case privacy(StarItem.ID)  // 20
        case otherNebula(String)   // 22, by plaza nebula name
        case starlightLine(String) // 23
        case telescopeConfirm(StarItem.ID) // 24
        case scanning(StarItem.ID)  // 25
        case reports   // 26
        case coins     // 28
        case coinHistory // 33
        case settings  // 87
        case inquiry   // 32
        case sky       // 68
        case policy(PolicyDoc) // 43–46
        case nebulaStars(NebulaStarsView.Kind) // 89/90
        case brightness // 82
        case milkyWay   // 81
        case galaxyZoom // 76
        case myNebulaZoom // 77
        case nebulaStory // 83
        case drawNebula  // 51–55, 84, 85
        case galaxyNebula(String) // 73/78, by name
        case galaxyLines(String)  // 74
        case galaxyStar(nebula: String, star: String) // 75
        case growth     // 65
        case moments    // 66
        case stages     // 86
        case collection // 79·80
        case sharedStars // 87 › 나눈 별
        case blockedKeepers // 87-3 차단한 별지기
        case editStar(StarItem.ID)  // 글 수정
        case reshapeNebula          // 08 「모양 바꾸기」 → 84 … 54
        case floatKept(StarItem.ID) // a kept star's "별 띄우기" → 06/07
        case monthlyReport(String?)  // 123 (v1.1): a month, or the mock sample
        case page(String)
    }

    var body: some View {
        ZStack {
            tabs
                .edgeSwipeDrawer(isOpen: $drawerOpen, enabled: stack.isEmpty) {
                    DrawerMenu(onSelect: { title in
                        drawerOpen = false
                        if title == "마음 망원경" {
                            push(.reports)
                        } else if title == "코인" {
                            push(.coins)
                        } else if title == "설정" {
                            push(.settings)
                        } else if title == "문의하기" {
                            push(.inquiry)
                        } else if title == "별빛 기록" {
                            recordsFilter = .all
                            tab = .records
                        } else if title == "컬렉션" {
                            push(.collection)
                        } else if title == "간직한 별" {
                            recordsFilter = .kept
                            tab = .records
                        } else {
                            push(.page(title))
                        }
                    }, onDev: handleDev)
                }

            ForEach(Array(stack.enumerated()), id: \.element.id) { index, entry in
                routeView(entry.route)
                    .transition(.move(edge: .trailing))
                    .zIndex(Double(index + 1))
            }

            // 56–60 Story, over the tab bar, the first time the nebula tab opens.
            if tab == .nebula && !model.hasSeenNebulaStory && stack.isEmpty {
                NebulaStoryIntroView {
                    withAnimation(.easeInOut(duration: 0.4)) { model.hasSeenNebulaStory = true }
                }
                .transition(.opacity)
                .zIndex(0.5)
            }

            // 21 Plaza Welcome, over the tab bar, the first time the plaza opens.
            if tab == .plaza && !model.hasSeenPlazaIntro && stack.isEmpty {
                PlazaWelcomeView(
                    onBrowse: { withAnimation(.easeInOut(duration: 0.3)) { model.hasSeenPlazaIntro = true } },
                    onLater: { withAnimation(.easeInOut(duration: 0.3)) { tab = .sky } }
                )
                .transition(.opacity)
                .zIndex(0.5)
            }
        }
        .toastCard($toast)
        #if DEBUG
        // `-debugRoute <name>`: open a page on launch, for checking screens without taps
        // (names in the switch below).
        .task { openDebugScreen() }
        .task {
            switch UserDefaults.standard.string(forKey: "debugRoute") {
            case "coins": push(.coins)
            case "settings": push(.settings)
            case "reports": push(.reports)
            case "collection": push(.collection)
            case "plaza", "plazaNebula": tab = .plaza     // 09 / 72
            case "compose": push(.compose())              // 05
            case "myNebula": push(.myNebulaZoom)          // 77
            case "galaxy": push(.galaxyZoom)              // 69
            case "story": push(.nebulaStory)              // 83
            case "missingReport": push(.report(UUID()))   // 122-1
            // Visual review (mock data):
            case "coinsAgreed": push(.coins)              // 28-1
            case "policyPayment": push(.policy(.payment))     // 46
            case "policyMarketing": push(.policy(.marketing)) // 31
            case "withdrawShares", "notificationsOff": push(.settings) // 92 / 95 sheet over 87
            case "sharedStars":                           // 17 with two shared stars
                if model.stars.filter(\.isFloated).count < 2 { model.fillSampleStars() }
                for star in model.stars.filter(\.isFloated).prefix(2) { model.setShared(true, for: star.id) }
                push(.sharedStars)
            case "sharedStarsEmpty":                      // 18
                for star in model.stars where star.isShared { model.setShared(false, for: star.id) }
                push(.sharedStars)
            case "coinHistoryRefund":                     // 121 with one refund row
                if !model.coinHistory.contains(where: { $0.kind == "refund" }) {
                    model.coinHistory.insert(CoinEntry(title: "환불", delta: -330,
                                                       date: .now.addingTimeInterval(-86_400), kind: "refund"), at: 0)
                }
                push(.coinHistory)
            case "missingStar": push(.detail(UUID()))     // 122
            // 08-1 / 08-2 / 84 reshape (2026-11-08)
            case "nebulaDrawn", "reshapeNebula":
                // A fresh mock nebula every time (an older one may point at stars
                // that are gone), with every mood and two guests.
                if model.stars.filter(\.isFloated).count < 3 { model.fillSampleStars() }
                let moods: [Mood] = [.calm, .sorrow, .anger, .insight]
                for (k, i) in model.stars.indices.filter({ model.stars[$0].isFloated }).enumerated() {
                    model.stars[i].mood = moods[k % moods.count]
                }
                let ids = model.stars.filter(\.isFloated).map(\.id)
                model.drawnNebulae = [DrawnNebula(name: "느린 저녁의 성운", silhouette: NebulaSilhouette.lighthouse.rawValue,
                                                  starIDs: ids, guests: GuestStar.candidates.prefix(2).map(\.title))]
                if UserDefaults.standard.string(forKey: "debugRoute") == "reshapeNebula" { push(.reshapeNebula) } else { tab = .nebula }
            case "nebulaEmpty":
                model.drawnNebulae = []
                tab = .nebula
            // 글 수정 / 간직한 별 띄우기 (2026-11-08)
            case "keptStar", "keptShort":
                // keptStar: over 50 characters (can float); keptShort: under 50.
                if let i = model.stars.firstIndex(where: { !$0.isFloated }) {
                    model.stars[i].body = UserDefaults.standard.string(forKey: "debugRoute") == "keptShort"
                        ? "말하지 못한 말이 남았어요." : StarItem.keptSampleBody
                    push(.detail(model.stars[i].id))
                }
            case "editStar":
                if let star = model.stars.first(where: \.isFloated) { push(.editStar(star.id)) }
            case "editKept":
                if let i = model.stars.firstIndex(where: { !$0.isFloated }) {
                    model.stars[i].body = StarItem.keptSampleBody
                    push(.editStar(model.stars[i].id))
                }
            default: break
            }
        }
        #endif
    }

    // MARK: Tabs

    private var tabs: some View {
        ZStack {
            switch tab {
            case .sky:
                if model.stars.isEmpty {
                    FirstNightSkyView(onCompose: { push(.compose()) })
                        .onAppear {
                            if !model.hasSeenWelcome {
                                model.hasSeenWelcome = true
                                showWelcome = true
                            }
                        }
                } else {
                    LoadingGate {
                        HomeView(onCompose: { push(.compose()) }, onOpenStar: openStar,
                                 onSeeAll: { recordsFilter = .all; tab = .records })
                    } placeholder: { HomeSkeleton() }
                }
            case .nebula:
                NebulaView(onOpen: openFromNebula)
            case .plaza:
                LoadingGate {
                    PlazaView(onOpen: { push(.otherNebula($0)) },
                              onOpenNebula: { push(.galaxyNebula($0.name)) })
                } placeholder: { ListSkeleton(titleWidth: 160, rowHeight: 100, rows: 3) }
            case .records:
                LoadingGate {
                    RecordsView(onOpenStar: openStar, onBrightness: { push(.brightness) },
                                onCompose: { push(.compose()) }, filter: $recordsFilter)
                } placeholder: { ListSkeleton(titleWidth: 180, rowHeight: 76, rows: 4) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topTrailing) {
            MenuButton {
                withAnimation(.spring(duration: 0.35, bounce: 0.1)) { drawerOpen.toggle() }
            }
            .padding(.trailing, 16)
            .padding(.top, 2)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Figma 84pt bar: the labels sit 20pt into the home-indicator area.
            SkyTabBar(selection: $tab) { push(.compose()) }
                .padding(.bottom, -min(20, bottomSafeArea))
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomSafeArea = $0 }
        // v1.1 scenes move on the night-sky tabs only (04, 성운, 광장).
        .background {
            StarField()
                .environment(\.sceneMotion, tab != .records)
                .environment(\.sceneOnHome, tab == .sky)
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet(
                onCompose: { showWelcome = false; push(.compose()) },
                onBrowse: { showWelcome = false }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { welcomeHeight = $0 }
            .presentationDetents([.height(welcomeHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "welcome-sheet") }
        }
    }

    // MARK: Routes

    @ViewBuilder
    private func routeView(_ route: Route) -> some View {
        switch route {
        case .compose(let rewriteID):
            ComposeFlowView(
                rewriteOf: rewriteID.flatMap { id in model.stars.first { $0.id == id } },
                onClose: pop,
                onShowNebula: {
                    tab = .nebula
                    pop()
                },
                onTelescope: { openReport($0, replacing: true) },
                onOpenStar: { replace(with: .detail($0.id)) },
                onCharge: { push(.coins) }
            )
        case .detail(let id):
            StarDetailView(
                starID: id,
                onBack: pop,
                onRewrite: { replace(with: .compose(rewriteOf: id)) },
                onReviewShare: { push(.privacy(id)) },
                onDeleted: {
                    pop()
                    toast = ToastCardMessage(title: "삭제되었어요", detail: "되돌릴 수 없어요")
                },
                onEdit: { push(.editStar(id)) },
                onFloat: { replace(with: .floatKept(id)) }
            )
            .edgeSwipeBack(onBack: pop)
        case .report(let id):
            TelescopeReportView(starID: id, onClose: pop,
                                onRewrite: { replace(with: .compose(rewriteOf: id)) },
                                onReportList: { replace(with: .reports) })
            .edgeSwipeBack(onBack: pop)
        case .records:
            // Pushed copy (older links); the tab is the main entry now.
            VStack(spacing: 0) {
                TopAppBar(title: "기록", onBack: pop)
                RecordsView(onOpenStar: { push(.detail($0.id)) }, onBrightness: { push(.brightness) },
                            onCompose: { push(.compose()) }, filter: $recordsFilter)
            }
            .background { StarField() }
            .edgeSwipeBack(onBack: pop)
        case .kept:
            KeptView(onBack: pop, onOpenStar: { push(.detail($0.id)) })
                .edgeSwipeBack(onBack: pop)
        case .privacy(let id):
            PrivacyCheckView(starID: id, onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .otherNebula(let name):
            if let nebula = model.plazaStarItems.first(where: { $0.name == name }) {
                OtherNebulaView(nebula: nebula, onBack: pop, onOpenLine: { push(.starlightLine($0)) })
                    .edgeSwipeBack(onBack: pop)
            } else {
                PlaceholderPage(title: "이름 없는 성운", onBack: pop)
                    .edgeSwipeBack(onBack: pop)
            }
        case .starlightLine(let line):
            StarlightLineView(line: line, onClose: pop)
                .edgeSwipeBack(onBack: pop)
        case .telescopeConfirm(let id):
            TelescopeConfirmView(
                starID: id,
                onStart: { replace(with: .scanning(id)) },
                onCharge: { replace(with: .coins) },
                onLater: pop
            )
            .edgeSwipeBack(onBack: pop)
        case .scanning(let id):
            TelescopeScanView(starID: id, onDone: { replace(with: .report(id)) }, onBackground: pop)
        case .reports:
            ReportListView(onBack: pop, onOpen: { push(.report($0.id)) },
                           onTurnOn: {
                               // 98 "최근 별 보러 가기": the telescope is turned on from a star.
                               if let star = model.stars.filter(\.isFloated).max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) {
                                   replace(with: .detail(star.id))
                               } else {
                                   replace(with: .compose())
                               }
                           },
                           onMonthly: { push(.monthlyReport($0)) })
                .edgeSwipeBack(onBack: pop)
        case .coins:
            CoinChargeView(onBack: pop, onPolicy: { push(.policy(.payment)) },
                           onHistory: { push(.coinHistory) })
                .edgeSwipeBack(onBack: pop)
        case .coinHistory:
            CoinHistoryView(onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .settings:
            SettingsView(onBack: pop, onOpen: { push($0 == "차단한 별지기" ? .blockedKeepers : .sharedStars) },
                         onSky: { push(.sky) }, onPolicy: { push(.policy($0)) })
                .edgeSwipeBack(onBack: pop)
        case .inquiry:
            InquiryView(onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .sky:
            SkyColorView(onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .policy(let doc):
            PolicyDocView(doc: doc, onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .nebulaStars(let kind):
            NebulaStarsView(initial: kind, onBack: pop, onOpenStar: openStar)
                .edgeSwipeBack(onBack: pop)
        case .brightness:
            BrightnessFlowView(onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .milkyWay:
            MilkyWayView(onBack: pop, onOpenStar: openStar)
                .edgeSwipeBack(onBack: pop)
        case .galaxyZoom:
            GalaxyZoomView(onBack: pop, onOpenStar: openStar,
                           onMyNebula: { replace(with: .myNebulaZoom) },
                           onPlaza: {
                               withAnimation(.easeInOut(duration: 0.32)) { stack.removeAll() }
                               tab = .plaza
                           })
                .edgeSwipeBack(onBack: pop)
        case .myNebulaZoom:
            MyNebulaZoomView(onBack: pop, onOpenStar: openStar, onOpen: { title in
                switch title {
                case "성운 이야기": push(.nebulaStory)
                case "성운 그리기": push(.drawNebula)
        case "모양 바꾸기": push(.reshapeNebula)
                case "자라는 모습": push(.growth)
                default: push(.page(title))
                }
            })
            .edgeSwipeBack(onBack: pop)
        case .nebulaStory:
            NebulaStoryView(onBack: pop,
                            onSaved: {
                                pop()
                                toast = ToastCardMessage(title: "성운 이야기를 엮어 두었어요")
                            },
                            onNeedCoins: { push(.coins) })
                .edgeSwipeBack(onBack: pop)
        case .drawNebula:
            NebulaDrawingFlow(
                onClose: pop,
                onHome: {
                    withAnimation(.easeInOut(duration: 0.32)) { stack.removeAll() }
                    tab = .sky
                },
                onShare: {
                    withAnimation(.easeInOut(duration: 0.32)) { stack.removeAll() }
                    tab = .plaza
                    toast = ToastCardMessage(title: "우주 광장에 나눴어요")
                }
            )
        case .galaxyNebula(let name):
            if let n = model.galaxyNebulae.first(where: { $0.name == name }) {
                GalaxyNebulaView(nebula: n, onBack: pop,
                                 onLines: { push(.galaxyLines(name)) },
                                 onOpenStar: { push(.galaxyStar(nebula: name, star: $0)) },
                                 onBlocked: blocked)
                    .edgeSwipeBack(onBack: pop)
            }
        case .galaxyLines(let name):
            if let n = model.galaxyNebulae.first(where: { $0.name == name }) {
                GalaxyLinesView(nebula: n, onBack: pop)
                    .edgeSwipeBack(onBack: pop)
            }
        case .galaxyStar(let name, let star):
            if let n = model.galaxyNebulae.first(where: { $0.name == name }) {
                GalaxyStarView(nebula: n, starTitle: star, onBack: pop, onBlocked: blocked)
                    .edgeSwipeBack(onBack: pop)
            }
        case .growth:
            NebulaGrowthView(onBack: pop, onMoments: { push(.moments) }, onDraw: { push(.drawNebula) })
                .edgeSwipeBack(onBack: pop)
        case .moments:
            GrowthMomentsView(onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .stages:
            GrowthStagesView(onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .collection:
            CollectionView(
                onBack: pop,
                onOpenStar: openStar,
                onOpenOtherStar: { push(.galaxyStar(nebula: $0, star: $1)) },
                onOpenMyNebula: { push(.myNebulaZoom) },
                onOpenOtherNebula: { push(.galaxyNebula($0.name)) },
                onDraw: { push(.drawNebula) },
                onPlaza: {
                    withAnimation(.easeInOut(duration: 0.32)) { stack.removeAll() }
                    tab = .plaza
                }
            )
            .edgeSwipeBack(onBack: pop)
        case .reshapeNebula:
            NebulaDrawingFlow(onClose: pop, onHome: pop, onShare: pop, editing: model.latestNebula)
        case .editStar(let id):
            StarEditView(starID: id, onClose: pop)
        case .floatKept(let id):
            ComposeFlowView(
                onClose: pop,
                onShowNebula: { tab = .nebula; pop() },
                onTelescope: { openReport($0, replacing: true) },
                onOpenStar: { replace(with: .detail($0.id)) },
                onCharge: { push(.coins) },
                floatingKept: model.stars.first { $0.id == id }
            )
        case .blockedKeepers:
            BlockedKeepersView(onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .monthlyReport(let month):
            MonthlyReportView(month: month, onClose: pop, onStars: {
                withAnimation(.easeInOut(duration: 0.32)) { stack.removeAll() }
                tab = .records
            })
            .edgeSwipeBack(onBack: pop)
        case .sharedStars:
            SharedStarsView(
                onBack: pop,
                onOpenStar: openStar,
                onPlaza: {
                    withAnimation(.easeInOut(duration: 0.32)) { stack.removeAll() }
                    tab = .plaza
                }
            )
            .edgeSwipeBack(onBack: pop)
        case .page(let title):
            PlaceholderPage(title: title, onBack: pop)
                .edgeSwipeBack(onBack: pop)
        }
    }

    #if DEBUG
    /// `-debugScreen <Figma frame>`: the tab or page for that frame (see `DebugScreen`).
    private func openDebugScreen() {
        guard let screen = DebugScreen.current, DebugScreen.supported.contains(screen) else { return }
        let floated = DebugScreen.floatedStar(model)
        let fresh = model.stars.first { $0.isFloated && $0.report == nil }
        let nebula = GalaxyNebula.samples[0]
        switch screen {
        case "3", "4", "47": tab = .sky
        case "3-1": tab = .sky; showWelcome = true
        case "8", "56": tab = .nebula
        case "9", "21", "50", "72": tab = .plaza
        case "115", "116", "117", "49": tab = .records
        case "118", "119": recordsFilter = .kept; tab = .records
        case "67-1": drawerOpen = true
        case "5", "6", "7", "13", "35", "36", "37", "61", "62", "34":
            if screen == "34" { model.saveDraft(StarDraft(mood: .calm, title: "쓰던 글", body: "오늘은 마음이 조금 느리게 흘렀어요.")) }
            push(.compose())
        case "104":
            model.saveDraft(StarDraft(mood: .calm, title: "", body: "오늘은 조금 느렸다."))
            push(.compose())
        case "14", "16", "105": if let floated { push(.compose(rewriteOf: floated.id)) }
        case "10": if let floated { push(.report(floated.id)) }
        case "12", "15", "19", "19-1", "48": if let floated { push(.detail(floated.id)) }
        case "20": if let floated { push(.privacy(floated.id)) }
        case "24", "29": if let s = fresh ?? floated { push(.telescopeConfirm(s.id)) }
        case "25": if let s = fresh ?? floated { push(.scanning(s.id)) }
        case "26", "27", "98", "111": push(.reports)
        case "17", "18": push(.sharedStars)
        case "22": push(.otherNebula(PlazaNebula.samples[0].name))
        case "23": push(.starlightLine("그런 마음이 어둠 속에서도 조용히 빛나고 있어요."))
        case "28", "28-1", "38", "102": push(.coins)
        case "33", "108", "121": push(.coinHistory)
        case "31": push(.policy(.marketing))
        case "43": push(.policy(.terms))
        case "44": push(.policy(.privacy))
        case "45": push(.policy(.sensitive))
        case "46": push(.policy(.payment))
        case "32": push(.inquiry)
        case "51": push(.drawNebula)
        case "86-1": push(.stages)
        case "65": push(.growth)
        case "66": push(.moments)
        case "86": push(.stages)
        case "68": push(.sky)
        case "69", "76": push(.galaxyZoom)
        case "70", "71", "71-1", "77", "112": push(.myNebulaZoom)
        case "81": push(.milkyWay)
        case "82", "109": push(.brightness)
        case "83": push(.nebulaStory)
        case "89": push(.nebulaStars(.floated))
        case "90": push(.nebulaStars(.supernova))
        case "73", "78": push(.galaxyNebula(nebula.name))
        case "74", "99", "100", "101", "106", "107": push(.galaxyLines(nebula.name))
        case "75", "75-1", "75-2": push(.galaxyStar(nebula: nebula.name, star: nebula.stars[0].title))
        case "87-3": push(.blockedKeepers)
        case "M1", "28-2": push(.coins)
        case "68-1": push(.sky)
        case "84-1": push(.drawNebula)
        case "87-4": push(.settings)
        case "123": push(.monthlyReport(nil))
        case "79", "80", "96", "97", "110": push(.collection)
        case "87", "87-1", "87-2", "91", "92", "93", "94", "95", "114": push(.settings)
        case "122": push(.detail(UUID()))
        case "122-1": push(.report(UUID()))
        default: break
        }
    }
    #endif

    /// 75-2 차단하기: leave the blocked keeper's page (and the nebula it came
    /// from, which is now hidden), then "차단했어요".
    private func blocked() {
        withAnimation(.easeInOut(duration: 0.32)) {
            stack.removeAll {
                switch $0.route {
                case .galaxyStar, .galaxyNebula, .galaxyLines: true
                default: false
                }
            }
        }
        toast = ToastCardMessage(title: "차단했어요", detail: "설정 › 차단한 별지기에서 풀 수 있어요")
    }

    private func push(_ r: Route) {
        withAnimation(.easeInOut(duration: 0.32)) { stack.append(Entry(route: r)) }
    }

    private func pop() {
        withAnimation(.easeInOut(duration: 0.32)) { _ = stack.popLast() }
    }

    /// Swaps the top page (e.g. 07 → 10, 13 → 12) so back skips the finished one.
    private func replace(with r: Route) {
        _ = stack.popLast()
        DispatchQueue.main.async { push(r) }
    }

    /// 10 Mind Telescope Report for a floated star. A star without a report
    /// goes through 24 (spend coins) and 25 (scanning); the very first one
    /// is free and goes straight to 25.
    private func openReport(_ star: StarItem, replacing: Bool = false) {
        guard star.isFloated else { return }
        let route: Route
        if model.report(for: star.id) != nil {
            route = .report(star.id)
        } else if model.isTelescopeFree {
            // "처음 한 번은 무료": skip the coin sheet.
            model.useFreeTelescope()
            route = .scanning(star.id)
        } else {
            route = .telescopeConfirm(star.id)
        }
        if replacing { replace(with: route) } else { push(route) }
    }

    /// 12 Star Detail
    private func openStar(_ star: StarItem) {
        push(.detail(star.id))
    }

    /// 08 links: stat cards (89), 나의 은하수 (81), 모두의 은하 (76),
    /// 자세히 보기 (77), 성운 이야기 (83), 성운 그리기 (51).
    private func openFromNebula(_ title: String) {
        switch title {
        case "떠 있는 별": push(.nebulaStars(.floated))
        case "깊은 별": push(.nebulaStars(.deep))
        case "초신성": push(.nebulaStars(.supernova))
        case "나의 은하수": push(.milkyWay)
        case "성운 모음": push(.collection)
        case "모두의 은하": push(.galaxyZoom)
        case "나의 성운 확대": push(.myNebulaZoom)
        case "성운 이야기": push(.nebulaStory)
        case "성운 그리기": push(.drawNebula)
        case "성장 단계": push(.stages)
        default: push(.page(title))
        }
    }

    private func handleDev(_ action: DrawerMenu.DevAction) {
        drawerOpen = false
        switch action {
        case .fillSamples: model.fillSampleStars()
        case .longDraft:
            model.fillLongDraft()
            push(.compose())
        case .clearStars: model.stars = []
        case .signOut: model.signOut()
        case .cycleFailure:
            // 없음 → 연결 끊김 → 분석 실패 → 결제 미완료 → 없음
            let all = SimulatedFailure.allCases
            if let f = model.simulatedFailure, let i = all.firstIndex(of: f) {
                model.simulatedFailure = i + 1 < all.count ? all[i + 1] : nil
            } else {
                model.simulatedFailure = all.first
            }
            drawerOpen = true
        case .toggleLiveAPI:
            model.setLiveAPI(!model.useLiveAPI)
        case .toggleLoading:
            model.simulateLoading.toggle()
            drawerOpen = true
        case .notice(let notice): model.appNotice = notice
        }
    }
}

/// Header shared by 03 and 04.
struct SkyHeader: View {
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("나의 밤하늘")
                .textStyle(.h1)
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .textStyle(.bodyM)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Placeholder for screens not built yet.
struct ComingSoonView: View {
    var title: String

    var body: some View {
        VStack(spacing: Space.sm) {
            Text(title)
                .textStyle(.h3)
                .foregroundStyle(Color.textPrimary)
            Text("다음 단계에서 만들어질 화면이에요.")
                .textStyle(.bodyM)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A pushed page for screens not built yet; supports the back swipe.
struct PlaceholderPage: View {
    var title: String
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FlowTopBar(title: title, closeLabel: "뒤로", onClose: onBack)
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
            ComingSoonView(title: title)
        }
        .background { StarField() }
    }
}

#Preview("First night") {
    MainView().environment(AppModel())
}

#Preview("Home") {
    let model = AppModel()
    model.fillSampleStars()
    return MainView().environment(model)
}

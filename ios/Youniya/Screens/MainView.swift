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
                        } else if title == "별빛 기록" {
                            push(.records)
                        } else if title == "보관함" {
                            push(.kept)
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
    }

    // MARK: Tabs

    private var tabs: some View {
        ZStack {
            switch tab {
            case .sky:
                if model.stars.isEmpty {
                    FirstNightSkyView(onCompose: { push(.compose()) })
                } else {
                    HomeView(onCompose: { push(.compose()) }, onOpenStar: openStar)
                }
            case .nebula:
                NebulaView(onOpen: { push(.page($0)) })
            case .plaza:
                PlazaView(onOpen: { push(.otherNebula($0)) })
            case .records:
                RecordsView(onOpenStar: openStar)
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
            SkyTabBar(selection: $tab) { push(.compose()) }
        }
        .background { StarField() }
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
                onOpenStar: { replace(with: .detail($0.id)) }
            )
        case .detail(let id):
            StarDetailView(
                starID: id,
                onBack: pop,
                onRewrite: { replace(with: .compose(rewriteOf: id)) },
                onReviewShare: { push(.privacy(id)) }
            )
            .edgeSwipeBack(onBack: pop)
        case .report(let id):
            TelescopeReportView(starID: id, onClose: pop) {
                replace(with: .compose(rewriteOf: id))
            }
            .edgeSwipeBack(onBack: pop)
        case .records:
            RecordsView(onBack: pop, onOpenStar: { push(.detail($0.id)) })
                .background { StarField() }
                .edgeSwipeBack(onBack: pop)
        case .kept:
            KeptView(onBack: pop, onOpenStar: { push(.detail($0.id)) })
                .edgeSwipeBack(onBack: pop)
        case .privacy(let id):
            PrivacyCheckView(starID: id, onBack: pop)
                .edgeSwipeBack(onBack: pop)
        case .otherNebula(let name):
            if let nebula = PlazaNebula.samples.first(where: { $0.name == name }) {
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
                onStart: { replace(with: .scanning(id)) },
                onCharge: { replace(with: .coins) },
                onLater: pop
            )
            .edgeSwipeBack(onBack: pop)
        case .scanning(let id):
            TelescopeScanView(starID: id, onDone: { replace(with: .report(id)) }, onBackground: pop)
        case .reports:
            ReportListView(onBack: pop, onOpen: { push(.report($0.id)) })
                .edgeSwipeBack(onBack: pop)
        case .coins:
            CoinChargeView(onBack: pop, onPolicy: { push(.page("결제·환불 정책")) })
                .edgeSwipeBack(onBack: pop)
        case .page(let title):
            PlaceholderPage(title: title, onBack: pop)
                .edgeSwipeBack(onBack: pop)
        }
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

    private func handleDev(_ action: DrawerMenu.DevAction) {
        drawerOpen = false
        switch action {
        case .fillSamples: model.fillSampleStars()
        case .clearStars: model.stars = []
        case .signOut: model.signOut()
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

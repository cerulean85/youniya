import SwiftUI

@main
struct YouniyaApp: App {
    @State private var model = AppModel()

    init() {
        AppFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

/// Splash → Login → Main (night sky tabs).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var showSplash = true

    var body: some View {
        @Bindable var model = model
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if model.isSignedIn && !model.hasConsented {
                ConsentView(onBack: model.signOut)
                    .edgeSwipeBack(onBack: model.signOut)
                    .transition(.move(edge: .trailing))
            } else if model.isSignedIn {
                MainView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }

            // 39–41 cover everything until handled.
            if let notice = model.appNotice {
                AppNoticeView(notice: notice)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.appNotice?.id)
        .animation(.easeInOut(duration: 0.6), value: showSplash)
        .animation(.easeInOut(duration: 0.6), value: model.isSignedIn)
        .environment(\.motionReduced, systemReduceMotion || model.settings.reduceAnimations)
        .environment(\.skyTheme, model.settings.sky)
        .animation(.easeInOut(duration: 0.4), value: model.hasConsented)
        // Network and server messages (live API).
        .toast($model.apiMessage)
        .task {
            #if DEBUG
            // `-debugNotice 39|40|41|113|120`: show a status screen on launch (for checking it).
            switch UserDefaults.standard.string(forKey: "debugNotice") {
            case "39": model.appNotice = .loginExpired
            case "40": model.appNotice = .updateRequired
            case "41": model.appNotice = .maintenance("11월 4일 02:00~04:00")
            case "113": model.appNotice = .accountDeleted
            case "120": model.appNotice = .rateLimited
            default: break
            }
            // `-autoDevSignIn YES`: sign in to the live API on launch (for testing without taps).
            if model.useLiveAPI && !model.isSignedIn && UserDefaults.standard.bool(forKey: "autoDevSignIn") {
                model.signIn()
                return
            }
            #endif
            await model.refreshMe()
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            showSplash = false
        }
    }
}

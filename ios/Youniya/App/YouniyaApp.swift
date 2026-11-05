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
        .task {
            try? await Task.sleep(for: .seconds(2))
            showSplash = false
        }
    }
}

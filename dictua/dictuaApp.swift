import SwiftUI

@main
struct dictuaApp: App {
    @StateObject private var appEnv = AppEnvironment.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootView
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        ContentView()
            .environmentObject(appEnv)
            .environmentObject(appEnv.authViewModel)
            .environmentObject(appEnv.settingsViewModel)
            .onOpenURL(perform: handleURL)
            .onContinueUserActivity("com.dictua.viewEntry", perform: handleUserActivity)
    }

    private func handleScenePhase(_ newPhase: ScenePhase) {
        if newPhase == .active {
            Task { await appEnv.onForeground() }
            NotificationScheduler.shared.clearBadge()
        }
    }

    private func handleURL(_ url: URL) {
        Task { @MainActor in
            appEnv.handleDeepLink(url)
        }
    }

    private func handleUserActivity(_ activity: NSUserActivity) {
        if let slug = activity.userInfo?["entry_slug"] as? String, !slug.isEmpty {
            appEnv.presentedEntry = .slug(slug)
        } else if let entryId = activity.userInfo?["entry_id"] as? String, !entryId.isEmpty {
            appEnv.presentedEntry = .id(entryId)
        }
    }
}

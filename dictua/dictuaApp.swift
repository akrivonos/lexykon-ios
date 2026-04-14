import SwiftUI

@main
struct dictuaApp: App {
    @StateObject private var appEnv = AppEnvironment.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appEnv)
                .environmentObject(appEnv.authViewModel)
                .environmentObject(appEnv.settingsViewModel)
                .environment(\.appEnvironment, appEnv)
        }
        .onOpenURL { url in
            Task { @MainActor in
                appEnv.handleDeepLink(url)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await appEnv.onForeground() }
                NotificationScheduler.shared.clearBadge()
            }
        }
        .onContinueUserActivity("com.dictua.viewEntry") { activity in
            if let slug = activity.userInfo?["entry_slug"] as? String, !slug.isEmpty {
                appEnv.presentedEntry = .slug(slug)
            } else if let entryId = activity.userInfo?["entry_id"] as? String, !entryId.isEmpty {
                appEnv.presentedEntry = .id(entryId)
            }
        }
    }
}

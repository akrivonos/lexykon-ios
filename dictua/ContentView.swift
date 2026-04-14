import SwiftUI
import DictCore

/// Main tab indices for iPhone `TabView` (must match tab order below).
enum MainTab: Int, CaseIterable, Hashable {
    case lookup = 0
    case tools = 1
    case collections = 2
    case settings = 3
}

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var settings: AppSettingsViewModel
    @EnvironmentObject var appEnv: AppEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection: MainTab? = .lookup

    private var isIPad: Bool {
        horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        VStack(spacing: 0) {
            if !appEnv.isNetworkReachable {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Offline — showing cached content where available")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Offline. Cached content may be shown.")
            }
            mainContent
        }
        .preferredColorScheme(settings.preferredColorScheme)
        .alert(String(localized: "Session expired"), isPresented: Binding(
            get: { auth.sessionExpiredAlert },
            set: { if !$0 { auth.acknowledgeSessionExpired() } }
        )) {
            Button(String(localized: "OK")) {
                auth.acknowledgeSessionExpired()
            }
        } message: {
            Text(String(localized: "You have been signed out. Please log in again."))
        }
        .onChange(of: appEnv.selectedMainTab) { _, tab in
            if isIPad { selectedSection = tab }
        }
        .onChange(of: selectedSection) { _, new in
            if let new, isIPad { appEnv.selectedMainTab = new }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if isIPad {
            NavigationSplitView {
                List(MainTab.allCases, id: \.self, selection: $selectedSection) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                }
                .navigationTitle("Dictua")
            } detail: {
                NavigationStack {
                    detailContent
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { appEnv.presentedEntry != nil },
                set: { if !$0 { appEnv.clearPresentedEntry() } }
            )) {
                if let spec = appEnv.presentedEntry {
                    NavigationStack {
                        EntryDetailView(specifier: spec)
                            .environmentObject(auth)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { appEnv.clearPresentedEntry() }
                                }
                            }
                    }
                }
            }
        } else {
            TabView(selection: $appEnv.selectedMainTab) {
                NavigationStack {
                    LookupView()
                }
                .tabItem { Label(MainTab.lookup.title, systemImage: MainTab.lookup.systemImage) }
                .tag(MainTab.lookup)
                NavigationStack {
                    ToolsHubView()
                }
                .tabItem { Label(MainTab.tools.title, systemImage: MainTab.tools.systemImage) }
                .tag(MainTab.tools)
                NavigationStack {
                    CollectionsView()
                }
                .tabItem { Label(MainTab.collections.title, systemImage: MainTab.collections.systemImage) }
                .tag(MainTab.collections)
                NavigationStack {
                    SettingsView()
                }
                .tabItem { Label(MainTab.settings.title, systemImage: MainTab.settings.systemImage) }
                .tag(MainTab.settings)
            }
            .fullScreenCover(isPresented: Binding(
                get: { appEnv.presentedEntry != nil },
                set: { if !$0 { appEnv.clearPresentedEntry() } }
            )) {
                if let spec = appEnv.presentedEntry {
                    NavigationStack {
                        EntryDetailView(specifier: spec)
                            .environmentObject(auth)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { appEnv.clearPresentedEntry() }
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection ?? .lookup {
        case .lookup: LookupView()
        case .tools: ToolsHubView()
        case .collections: CollectionsView()
        case .settings: SettingsView()
        }
    }
}

private extension MainTab {
    var title: String {
        switch self {
        case .lookup: return String(localized: "Lookup")
        case .tools: return String(localized: "Tools")
        case .collections: return String(localized: "Collections")
        case .settings: return String(localized: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .lookup: return "magnifyingglass"
        case .tools: return "text.badge.checkmark"
        case .collections: return "folder"
        case .settings: return "gearshape"
        }
    }
}

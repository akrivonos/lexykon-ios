import Foundation
import Network
import SwiftUI
import DictCore

/// Injected app-wide dependencies.
public final class AppEnvironment: ObservableObject {
    public static let shared = AppEnvironment()
    public let apiClient: DictAPIClient
    public let tokenStorage: TokenStorage
    public let tokenRefreshActor: TokenRefreshActor
    public let entryRepository: EntryRepository
    public let offlineDictionary: OfflineDictionaryService
    public let authService: AuthService
    public let authViewModel: AuthViewModel
    public let settingsViewModel: AppSettingsViewModel
    let collectionsViewModel: CollectionsViewModel

    /// Entry opened via Handoff, deep link, or full-screen cover.
    @Published public var presentedEntry: PresentedEntrySpecifier?
    @Published var selectedMainTab: MainTab = .lookup
    @Published public var pendingLookupQuery: String?
    @Published public var pendingResetPasswordToken: String?
    @Published public var pendingVerifyEmailToken: String?

    @Published public private(set) var isNetworkReachable: Bool = true

    private let baseURL: URL
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "ua.dictua.path")

    private init() {
        let baseURLString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://localhost:8000/api/v1"
        baseURL = URL(string: baseURLString)!
        tokenStorage = KeychainTokenStorage()
        tokenRefreshActor = TokenRefreshActor(baseURL: baseURL, tokenStorage: tokenStorage)
        apiClient = DictAPIClient(
            baseURL: baseURL,
            tokenStorage: tokenStorage,
            tokenRefreshActor: tokenRefreshActor,
            acceptLanguage: { UserDefaults.standard.string(forKey: "interface_lang") ?? "uk" },
            sourceLang: { UserDefaults.standard.string(forKey: "source_lang") ?? "ru" }
        )
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ua.dict.shared")?
            .appendingPathComponent("CachedEntry.sqlite")
        entryRepository = CoreDataEntryRepository(storeURL: storeURL)
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("morphology.sqlite")
        offlineDictionary = OfflineDictionaryService(fileURL: supportURL)
        authService = AuthService(apiClient: apiClient, tokenStorage: tokenStorage)
        authViewModel = AuthViewModel(apiClient: apiClient, tokenStorage: tokenStorage)
        settingsViewModel = AppSettingsViewModel()
        collectionsViewModel = CollectionsViewModel(apiClient: apiClient, tokenStorage: tokenStorage)

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isNetworkReachable = reachable
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    deinit {
        pathMonitor.cancel()
    }

    @MainActor
    public func handleDeepLink(_ url: URL) {
        guard let target = DeepLinkRouter.parse(url: url) else { return }
        switch target {
        case .entry(let slug):
            presentedEntry = .slug(slug)
        case .lookup(let query):
            selectedMainTab = .lookup
            pendingLookupQuery = query
        case .resetPassword(let token):
            selectedMainTab = .settings
            pendingResetPasswordToken = token
        case .verifyEmail(let token):
            selectedMainTab = .settings
            pendingVerifyEmailToken = token
        }
    }

    @MainActor
    public func clearPresentedEntry() {
        presentedEntry = nil
    }

    func onForeground() async {
        await authViewModel.refreshSessionIfNeeded()
    }
}

private enum AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment? = nil
}
extension EnvironmentValues {
    var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

import Foundation
import DictCore
import Combine

public final class AuthViewModel: ObservableObject {
    @Published public private(set) var isLoggedIn = false
    @Published public private(set) var user: UserProfile?
    @Published public var errorMessage: String?
    @Published public var isLoading = false
    @Published public var sessionExpiredAlert = false

    private let apiClient: DictAPIClient
    private let tokenStorage: TokenStorage
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    public init(apiClient: DictAPIClient, tokenStorage: TokenStorage) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
        self.authService = AuthService(apiClient: apiClient, tokenStorage: tokenStorage)
        if tokenStorage.getAccessToken() != nil {
            isLoggedIn = true
        }
        NotificationCenter.default.publisher(for: TokenRefreshActor.sessionExpiredNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isLoggedIn = false
                self.user = nil
                self.sessionExpiredAlert = true
            }
            .store(in: &cancellables)
    }

    public func acknowledgeSessionExpired() {
        sessionExpiredAlert = false
        try? tokenStorage.clearTokens()
    }

    public func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (profile, _, _) = try await authService.login(email: email, password: password)
            TranslationLangPreference.syncFromProfile(profile.translationLangs)
            await MainActor.run {
                user = profile
                isLoggedIn = true
            }
            await pushCurrentAppSettingsToServer()
        } catch let e as DictAPIError {
            await MainActor.run { errorMessage = e.message }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    public func register(email: String, password: String, displayName: String?, sourceLang: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (profile, _, _) = try await authService.register(email: email, password: password, displayName: displayName, sourceLang: sourceLang)
            TranslationLangPreference.syncFromProfile(profile.translationLangs)
            await MainActor.run {
                user = profile
                isLoggedIn = true
            }
            await pushCurrentAppSettingsToServer()
        } catch let e as DictAPIError {
            await MainActor.run { errorMessage = e.message }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    public func logout() async {
        try? await authService.logout()
        await MainActor.run {
            isLoggedIn = false
            user = nil
        }
    }

    public func refreshSessionIfNeeded() async {
        guard tokenStorage.getAccessToken() != nil else { return }
        do {
            let profile = try await authService.refreshProfile()
            await MainActor.run {
                user = profile
                isLoggedIn = true
            }
        } catch {
            await MainActor.run {
                isLoggedIn = false
                user = nil
            }
        }
    }

    public func forgotPassword(email: String) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.forgotPassword(email: email)
            return nil
        } catch let e as DictAPIError {
            return e.message
        } catch {
            return error.localizedDescription
        }
    }

    public func resetPassword(token: String, newPassword: String) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.resetPassword(token: token, newPassword: newPassword)
            return nil
        } catch let e as DictAPIError {
            return e.message
        } catch {
            return error.localizedDescription
        }
    }

    public func verifyEmail(token: String) async -> String? {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.verifyEmail(token: token)
            let profile = try await authService.refreshProfile()
            await MainActor.run { user = profile }
            return nil
        } catch let e as DictAPIError {
            return e.message
        } catch {
            return error.localizedDescription
        }
    }

    public func resendVerification() async -> String? {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.resendVerification()
            return nil
        } catch let e as DictAPIError {
            return e.message
        } catch {
            return error.localizedDescription
        }
    }

    public func fetchTelegramLink() async throws -> TelegramLinkTokenResponse {
        try await authService.fetchTelegramLink()
    }

    public func unlinkTelegram() async -> String? {
        isLoading = true
        defer { isLoading = false }
        do {
            let profile = try await authService.unlinkTelegram()
            await MainActor.run { user = profile }
            return nil
        } catch let e as DictAPIError {
            return e.message
        } catch {
            return error.localizedDescription
        }
    }

    /// Push interface language, source language, and theme (light/dark only) to `PATCH /users/me`.
    public func syncLocalSettingsToServer(interfaceLang: String, sourceLang: String, appearance: String) async {
        guard isLoggedIn else { return }
        let theme: String? = appearance == "light" ? "light" : (appearance == "dark" ? "dark" : nil)
        let body = UpdateProfileRequest(
            displayName: nil,
            interfaceLang: interfaceLang,
            sourceLang: sourceLang,
            theme: theme
        )
        do {
            let profile = try await authService.updateProfile(body)
            await MainActor.run { user = profile }
        } catch let e as DictAPIError {
            await MainActor.run { errorMessage = e.message }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func pushCurrentAppSettingsToServer() async {
        let il = UserDefaults.standard.string(forKey: "interface_lang") ?? "uk"
        let sl = UserDefaults.standard.string(forKey: "source_lang") ?? "ru"
        let ap = UserDefaults.standard.string(forKey: "appearance") ?? "system"
        await syncLocalSettingsToServer(interfaceLang: il, sourceLang: sl, appearance: ap)
    }

    public func deleteAccount(password: String, reason: String?) async -> String? {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.deleteAccount(password: password, reason: reason)
            try? await authService.logout()
            await MainActor.run {
                isLoggedIn = false
                user = nil
            }
            return nil
        } catch let e as DictAPIError {
            return e.message
        } catch {
            return error.localizedDescription
        }
    }
}

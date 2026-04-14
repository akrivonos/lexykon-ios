import Foundation
import DictCore

public final class AuthService {
    private let apiClient: DictAPIClient
    private let tokenStorage: TokenStorage

    public init(apiClient: DictAPIClient, tokenStorage: TokenStorage) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
    }

    public func login(email: String, password: String) async throws -> (UserProfile, String, String?) {
        struct LoginResponse: Decodable {
            let data: AuthResponseData
        }
        let body = LoginRequest(email: email, password: password)
        let response: AuthResponseData = try await apiClient.request(
            path: "auth/login",
            method: .post,
            body: body,
            requiresAuth: false
        )
        try tokenStorage.setTokens(access: response.accessToken, refresh: response.refreshToken)
        return (response.user, response.accessToken, response.refreshToken)
    }

    public func register(email: String, password: String, displayName: String?, sourceLang: String?) async throws -> (UserProfile, String, String?) {
        let body = RegisterRequest(email: email, password: password, displayName: displayName, sourceLang: sourceLang ?? "ru")
        let response: AuthResponseData = try await apiClient.request(
            path: "auth/register",
            method: .post,
            body: body,
            requiresAuth: false
        )
        try tokenStorage.setTokens(access: response.accessToken, refresh: response.refreshToken)
        return (response.user, response.accessToken, response.refreshToken)
    }

    public func logout() async throws {
        struct LogoutData: Decodable { let ok: Bool? }
        _ = try? await apiClient.request(path: "auth/logout", method: .post, requiresAuth: true) as LogoutData
        try? tokenStorage.clearTokens()
    }

    public func refreshProfile() async throws -> UserProfile {
        try await apiClient.request(path: "users/me", method: .get, requiresAuth: true)
    }

    public func updateProfile(_ body: UpdateProfileRequest) async throws -> UserProfile {
        try await apiClient.request(path: "users/me", method: .patch, body: body, requiresAuth: true)
    }

    public func deleteAccount(password: String, reason: String?) async throws {
        let body = DeleteAccountRequestBody(password: password, reason: reason)
        _ = try await apiClient.request(
            path: "users/me",
            method: .delete,
            body: body,
            requiresAuth: true
        ) as DeleteAccountResponse
    }

    public func forgotPassword(email: String) async throws {
        let body = ForgotPasswordRequest(email: email)
        struct Envelope: Decodable { struct D: Decodable { let ok: Bool? }; let data: D? }
        _ = try await apiClient.request(
            path: "auth/forgot-password",
            method: .post,
            body: body,
            requiresAuth: false
        ) as Envelope
    }

    public func resetPassword(token: String, newPassword: String) async throws {
        let body = ResetPasswordRequest(token: token, newPassword: newPassword)
        struct Envelope: Decodable { struct D: Decodable { let ok: Bool? }; let data: D? }
        _ = try await apiClient.request(
            path: "auth/reset-password",
            method: .post,
            body: body,
            requiresAuth: false
        ) as Envelope
    }

    public func verifyEmail(token: String) async throws {
        let body = VerifyEmailRequest(token: token)
        struct Envelope: Decodable { struct D: Decodable { let ok: Bool? }; let data: D? }
        _ = try await apiClient.request(
            path: "auth/verify-email",
            method: .post,
            body: body,
            requiresAuth: false
        ) as Envelope
    }

    public func resendVerification() async throws {
        struct Envelope: Decodable { struct D: Decodable { let ok: Bool? }; let data: D? }
        _ = try await apiClient.request(
            path: "auth/resend-verification",
            method: .post,
            requiresAuth: true
        ) as Envelope
    }

    public func fetchTelegramLink() async throws -> TelegramLinkTokenResponse {
        try await apiClient.request(path: "user/telegram/link-token", method: .post, requiresAuth: true)
    }

    public func unlinkTelegram() async throws -> UserProfile {
        try await apiClient.request(path: "user/telegram", method: .delete, requiresAuth: true)
    }
}

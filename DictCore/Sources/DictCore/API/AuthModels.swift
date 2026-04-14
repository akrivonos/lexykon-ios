import Foundation

/// Response data for POST /auth/login and POST /auth/register
public struct AuthResponseData: Codable {
    public let user: UserProfile
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String?
    public let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

public struct UserProfile: Codable {
    public let id: String
    public let email: String?
    public let displayName: String?
    public let role: String?
    public let interfaceLang: String?
    public let sourceLang: String?
    public let dialectPref: String?
    public let streakDays: Int?
    public let diagnosticsOptedIn: Bool?
    public let createdAt: String?
    public let emailVerified: Bool?
    public let telegramChatId: Int64?
    public let telegramLinkedAt: String?
    public let theme: String?
    public let subscriptionTier: String?
    public let translationLangs: [String]?

    enum CodingKeys: String, CodingKey {
        case id, email, role, theme
        case displayName = "display_name"
        case interfaceLang = "interface_lang"
        case sourceLang = "source_lang"
        case dialectPref = "dialect_pref"
        case streakDays = "streak_days"
        case diagnosticsOptedIn = "diagnostics_opted_in"
        case createdAt = "created_at"
        case emailVerified = "email_verified"
        case telegramChatId = "telegram_chat_id"
        case telegramLinkedAt = "telegram_linked_at"
        case subscriptionTier = "subscription_tier"
        case translationLangs = "translation_langs"
    }
}

public struct LoginRequest: Encodable {
    public let email: String
    public let password: String
}

public struct RegisterRequest: Encodable {
    public let email: String
    public let password: String
    public let displayName: String?
    public let sourceLang: String?

    enum CodingKeys: String, CodingKey {
        case email, password
        case displayName = "display_name"
        case sourceLang = "source_lang"
    }
}

public struct RefreshRequest: Encodable {
    public let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

public struct ForgotPasswordRequest: Encodable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct ResetPasswordRequest: Encodable {
    public let token: String
    public let newPassword: String

    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "new_password"
    }

    public init(token: String, newPassword: String) {
        self.token = token
        self.newPassword = newPassword
    }
}

public struct VerifyEmailRequest: Encodable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

public struct TelegramLinkTokenResponse: Decodable {
    public let token: String?
    public let deepLink: String?
    public let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case token
        case deepLink = "deep_link"
        case expiresIn = "expires_in"
    }
}

import Foundation

// MARK: - Guest flag (POST /contributions/guest)

public struct GuestContributionBody: Encodable {
    public let targetType: String
    public let targetId: String
    public let action: String
    public let payload: FlagErrorPayload
    public let guestEmail: String?
    public let captchaToken: String?

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetId = "target_id"
        case action, payload
        case guestEmail = "guest_email"
        case captchaToken = "captcha_token"
    }

    public init(targetType: String = "entry", targetId: String, action: String = "flag_error", payload: FlagErrorPayload, guestEmail: String? = nil, captchaToken: String? = nil) {
        self.targetType = targetType
        self.targetId = targetId
        self.action = action
        self.payload = payload
        self.guestEmail = guestEmail
        self.captchaToken = captchaToken
    }
}

public struct FlagErrorPayload: Encodable {
    public let description: String

    public init(description: String) {
        self.description = description
    }
}

/// Authenticated submission (`POST /contributions`, contributor+).
public struct ContributionSubmitBody: Encodable {
    public let targetType: String
    public let targetId: String
    public let action: String
    public let payload: FlagErrorPayload

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetId = "target_id"
        case action, payload
    }

    public init(targetType: String = "entry", targetId: String, action: String = "flag_error", payload: FlagErrorPayload) {
        self.targetType = targetType
        self.targetId = targetId
        self.action = action
        self.payload = payload
    }
}

// MARK: - Mine / stats

public struct ContributionsMineResponse: Codable {
    public let items: [ContributionListItem]
    public let total: Int
}

public struct ContributionListItem: Codable, Identifiable {
    public let id: String
    public let status: String?
    public let targetType: String?
    public let targetId: String?
    public let action: String?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, action
        case targetType = "target_type"
        case targetId = "target_id"
        case createdAt = "created_at"
    }
}

public struct ContributionStats: Codable {
    public let total: Int
    public let accepted: Int
    public let rejected: Int
    public let pending: Int
    public let withdrawn: Int
    public let acceptanceRate: Double
    public let rank: Int?

    enum CodingKeys: String, CodingKey {
        case total, accepted, rejected, pending, withdrawn, rank
        case acceptanceRate = "acceptance_rate"
    }
}

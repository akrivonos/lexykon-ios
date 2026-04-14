import Foundation

// MARK: - Discover feed & public stats

public struct DiscoverFeedPayload: Codable {
    public let items: [DiscoverEntrySummary]?
}

public struct DiscoverEntrySummary: Codable {
    public let entryId: String?
    public let headword: String?
    public let pos: String?
    public let tier: String?

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case headword, pos, tier
    }
}

public struct PublicDictionaryStats: Codable {
    public let totalEntries: Int?
    public let totalSenses: Int?
    public let totalWordForms: Int?
    public let totalContributors: Int?
    public let contributionsAccepted30d: Int?
    public let contributionsPending: Int?
    public let topContributors: [TopContributorRow]?

    enum CodingKeys: String, CodingKey {
        case totalEntries = "total_entries"
        case totalSenses = "total_senses"
        case totalWordForms = "total_word_forms"
        case totalContributors = "total_contributors"
        case contributionsAccepted30d = "contributions_accepted_30d"
        case contributionsPending = "contributions_pending"
        case topContributors = "top_contributors"
    }
}

public struct TopContributorRow: Codable {
    public let displayName: String?
    public let acceptedCount: Int?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case acceptedCount = "accepted_count"
    }
}

// MARK: - Profile update / account deletion

public struct UpdateProfileRequest: Encodable {
    public let displayName: String?
    public let interfaceLang: String?
    public let sourceLang: String?
    public let theme: String?
    public let translationLangs: [String]?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case interfaceLang = "interface_lang"
        case sourceLang = "source_lang"
        case theme
        case translationLangs = "translation_langs"
    }

    public init(displayName: String? = nil, interfaceLang: String? = nil, sourceLang: String? = nil, theme: String? = nil, translationLangs: [String]? = nil) {
        self.displayName = displayName
        self.interfaceLang = interfaceLang
        self.sourceLang = sourceLang
        self.theme = theme
        self.translationLangs = translationLangs
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(displayName, forKey: .displayName)
        try c.encodeIfPresent(interfaceLang, forKey: .interfaceLang)
        try c.encodeIfPresent(sourceLang, forKey: .sourceLang)
        try c.encodeIfPresent(theme, forKey: .theme)
        try c.encodeIfPresent(translationLangs, forKey: .translationLangs)
    }
}

public struct DeleteAccountRequestBody: Encodable {
    public let password: String
    public let reason: String?

    public init(password: String, reason: String? = nil) {
        self.password = password
        self.reason = reason
    }
}

public struct DeleteAccountResponse: Codable {
    public let ok: Bool?
    public let message: String?
}

// MARK: - Discover save (POST /discover/save)

public struct DiscoverSaveRequest: Encodable {
    public let entryId: String
    public let collectionId: String?

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case collectionId = "collection_id"
    }
}

public struct DiscoverSaveResponse: Codable {
    public let collectionId: String?
    public let entryId: String?

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case entryId = "entry_id"
    }
}

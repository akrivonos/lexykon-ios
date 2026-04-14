import Foundation

// MARK: - GET /translate

public struct TranslateSearchResponse: Codable {
    public let query: String
    public let sourceLang: String
    public let results: [TranslateResultGroup]

    enum CodingKeys: String, CodingKey {
        case query
        case sourceLang = "source_lang"
        case results
    }
}

public struct TranslateResultGroup: Codable, Identifiable {
    public let entryId: String?
    public let slug: String?
    public let ukrainianLemma: String?
    public let stressForms: [StressForm]?
    public let pos: String?
    public let tier: String?
    public let translations: [TranslateEquivRow]?

    public var id: String { entryId ?? slug ?? ukrainianLemma ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case slug, pos, tier, translations
        case entryId = "entry_id"
        case ukrainianLemma = "ukrainian_lemma"
        case stressForms = "stress_forms"
    }
}

public struct TranslateEquivRow: Codable {
    public let sourceWord: String?
    public let matchType: String?
    public let rank: Int?
    public let senseNumber: Int?
    public let definitionUk: String?
    public let sourceCode: String?

    enum CodingKeys: String, CodingKey {
        case rank
        case sourceWord = "source_word"
        case matchType = "match_type"
        case senseNumber = "sense_number"
        case definitionUk = "definition_uk"
        case sourceCode = "source_code"
    }
}

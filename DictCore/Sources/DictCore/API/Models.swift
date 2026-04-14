import Foundation

// MARK: - Shared types

public struct StressForm: Codable {
    public let stressedForm: String
    public let stressPattern: String?
    public let isPrimary: Bool?
    public let sourceCode: String?

    enum CodingKeys: String, CodingKey {
        case stressedForm = "stressed_form"
        case stressPattern = "stress_pattern"
        case isPrimary = "is_primary"
        case sourceCode = "source_code"
    }
}

public struct LexicalLabel: Codable {
    public let labelCode: String
    public let sourceLang: String?
    public let dialectRegion: String?
    public let sourceCode: String?
    public let reviewStatus: String?

    enum CodingKeys: String, CodingKey {
        case labelCode = "label_code"
        case sourceLang = "source_lang"
        case dialectRegion = "dialect_region"
        case sourceCode = "source_code"
        case reviewStatus = "review_status"
    }
}

// MARK: - Lookup

/// Response of GET /lookup
public struct LookupResponse: Codable {
    public let entry: LookupEntrySummary?
    public let query: String
    public let matchType: String
    public let fuzzySuggestions: [FuzzySuggestion]?
    public let reverseResults: [ReverseLookupResult]?
    /// Legacy name in older clients; prefer `alsoFound`.
    public let homographs: [Homograph]?
    /// Additional headword / word-form matches (`also_found` from API).
    public let alsoFound: [AlsoFoundSummary]?

    enum CodingKeys: String, CodingKey {
        case entry, query, matchType = "match_type"
        case fuzzySuggestions = "fuzzy_suggestions"
        case reverseResults = "reverse_results"
        case homographs
        case alsoFound = "also_found"
    }
}

public struct LookupEntrySummary: Codable {
    public let id: String?
    public let slug: String?
    public let lemmaId: String?
    public let tier: String?
    public let status: String?
    public let lemma: LemmaSummary?
    public let standardAlternative: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, tier, status, lemma
        case lemmaId = "lemma_id"
        case standardAlternative = "standard_alternative"
    }
}

public struct LemmaSummary: Codable {
    public let lemma: String?
    public let pos: String?
    public let stressForms: [StressForm]?
    public let labels: [LexicalLabel]?
    public let dialectRegion: String?

    enum CodingKeys: String, CodingKey {
        case lemma, pos, labels
        case stressForms = "stress_forms"
        case dialectRegion = "dialect_region"
    }

    /// Primary stressed form for display, falling back to lemma text.
    public var primaryStressed: String? {
        stressForms?.first(where: { $0.isPrimary == true })?.stressedForm
        ?? stressForms?.first?.stressedForm
    }

    public var isDialectal: Bool {
        labels?.contains(where: { $0.labelCode == "dialectal" }) ?? false
    }

    public var isArchaic: Bool {
        labels?.contains(where: { $0.labelCode == "archaic_lexical" || $0.labelCode == "archaic_orthographic" }) ?? false
    }
}

public struct FuzzySuggestion: Codable {
    public let entryId: String?
    public let slug: String?
    public let lemma: String?
    public let pos: String?
    public let stressForms: [StressForm]?
    public let similarity: Double?

    enum CodingKeys: String, CodingKey {
        case lemma, pos, similarity, slug
        case entryId = "entry_id"
        case stressForms = "stress_forms"
    }

    public var primaryStressed: String? {
        stressForms?.first(where: { $0.isPrimary == true })?.stressedForm
        ?? stressForms?.first?.stressedForm
    }
}

public struct ReverseLookupResult: Codable {
    public let lemmaId: String?
    public let entryId: String?
    public let slug: String?
    public let lemma: String?
    public let pos: String?
    public let stressForms: [StressForm]?
    public let translationContext: String?
    public let similarity: Double?

    enum CodingKeys: String, CodingKey {
        case lemma, pos, similarity, slug
        case lemmaId = "lemma_id"
        case entryId = "entry_id"
        case stressForms = "stress_forms"
        case translationContext = "translation_context"
    }

    public var primaryStressed: String? {
        stressForms?.first(where: { $0.isPrimary == true })?.stressedForm
        ?? stressForms?.first?.stressedForm
    }
}

/// Row from `also_found` in lookup response.
public struct AlsoFoundSummary: Codable, Identifiable {
    public let entryId: String?
    public let headword: String?
    public let pos: String?
    public let slug: String?
    public let contentTier: String?

    enum CodingKeys: String, CodingKey {
        case headword, pos, slug
        case entryId = "entry_id"
        case contentTier = "content_tier"
    }

    public var id: String { entryId ?? slug ?? headword ?? UUID().uuidString }

    public init(entryId: String?, headword: String?, pos: String?, slug: String?, contentTier: String?) {
        self.entryId = entryId
        self.headword = headword
        self.pos = pos
        self.slug = slug
        self.contentTier = contentTier
    }
}

public struct Homograph: Codable {
    public let lemmaId: String?
    public let lemma: String?
    public let pos: String?
    public let stressForms: [StressForm]?

    enum CodingKeys: String, CodingKey {
        case lemma, pos
        case lemmaId = "lemma_id"
        case stressForms = "stress_forms"
    }

    public var primaryStressed: String? {
        stressForms?.first(where: { $0.isPrimary == true })?.stressedForm
        ?? stressForms?.first?.stressedForm
    }
}

// MARK: - Autocomplete

/// Item from GET /lookup/autocomplete
public struct AutocompleteItem: Codable {
    public let lemmaId: String?
    public let lemma: String?
    public let headwordStressed: String?
    public let pos: String?
    public let stressForms: [StressForm]?
    public let frequencyRank: String?

    enum CodingKeys: String, CodingKey {
        case lemma, pos
        case lemmaId = "lemma_id"
        case headwordStressed = "headword_stressed"
        case stressForms = "stress_forms"
        case frequencyRank = "frequency_rank"
    }

    public var primaryStressed: String? {
        stressForms?.first(where: { $0.isPrimary == true })?.stressedForm
        ?? stressForms?.first?.stressedForm
    }
}

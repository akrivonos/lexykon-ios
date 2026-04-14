import Foundation

// MARK: - Headword

public struct Headword: Codable {
    public let id: String?
    public let headword: String?
    public let headwordStressed: String?
    public let isPrimary: Bool?
}

// MARK: - Sense Text (definition per language)

public struct SenseText: Codable {
    public let id: String?
    public let lang: String?
    public let definition: String?
}

// MARK: - Sense Equivalent (translation)

public struct SenseEquivalent: Codable {
    public let id: String?
    public let lang: String?
    public let equivalent: String?
    public let matchType: String?
    public let rank: Int?
}

// MARK: - Illustration (example sentence)

public struct Illustration: Codable {
    public let id: String?
    public let illustrationText: String?
    public let text: String?
    public let sourceType: String?
}

// MARK: - Sense Relation

public struct SenseRelation: Codable {
    public let relationType: String?
    public let targetHeadword: String?
    public let targetEntryId: String?
}

// MARK: - Sense

public struct Sense: Codable {
    public let id: String?
    public let senseNumber: Int?
    public let style: String?
    public let usage: [String]?
    public let government: String?
    public let context: String?
    public let region: String?
    public let senseTexts: [SenseText]?
    public let senseEquivalents: [SenseEquivalent]?
    public let illustrations: [Illustration]?
    public let senseRelations: [SenseRelation]?

    /// Primary Ukrainian definition for display.
    public var definitionUk: String? {
        senseTexts?.first(where: { $0.lang == "uk" })?.definition
    }

    /// Primary Russian definition for display.
    public var definitionRu: String? {
        senseTexts?.first(where: { $0.lang == "ru" })?.definition
    }
}

// MARK: - Word Form

public struct WordForm: Codable {
    public let form: String?
    public let gramCase: String?
    public let gramNumber: String?
    public let gramGender: String?
    public let gramPerson: String?
    public let gramTense: String?
    public let gramAspect: String?
    public let gramMood: String?
    public let gramDegree: String?

    /// Composite tag string for display, built from non-nil grammar fields.
    public var tags: String? {
        let parts = [gramCase, gramNumber, gramGender, gramPerson, gramTense, gramAspect, gramMood, gramDegree]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - Derivational Relation

public struct DerivationalRelation: Codable {
    public let relationType: String?
    public let targetHeadword: String?
    public let targetEntryId: String?
}

// MARK: - Anchor Entry

public struct AnchorEntry: Codable {
    public let headword: String?
    public let entryId: String?
    public let pos: String?
    public let slug: String?
}

// MARK: - Containing Phrase

public struct ContainingPhrase: Codable {
    public let headword: String?
    public let entryId: String?
    public let entryType: String?
    public let slug: String?
}

// MARK: - Etymology

public struct Etymology: Codable {
    public let etymologyType: String?
    public let sourceLanguage: String?
    public let sourceWord: String?
    public let notes: String?
}

// MARK: - Entry Detail

/// Full entry from GET /entries/{id} or /entries/by-slug/{slug}
public struct EntryDetail: Codable {
    public let id: String?
    public let slug: String?
    public let pos: String?
    public let tier: String?
    public let headword: String?
    public let lemma: LemmaInfo?
    public let headwords: [Headword]?
    public let grammar: [String: AnyCodable]?
    public let senses: [Sense]?
    public let wordForms: [WordForm]?
    public let derivationalRelations: [DerivationalRelation]?
    public let anchorEntries: [AnchorEntry]?
    public let containingPhrases: [ContainingPhrase]?
    public let entryEtymologies: [Etymology]?

    /// ISO8601 from API for cache invalidation.
    public let updatedAt: String?

    /// Primary stressed headword for display.
    public var primaryStressed: String? {
        headwords?.first(where: { $0.isPrimary == true })?.headwordStressed
        ?? headwords?.first?.headwordStressed
        ?? lemma?.primaryStressed
        ?? headword
    }
}

public struct LemmaInfo: Codable {
    public let lemma: String?
    public let pos: String?
    public let stressForms: [StressForm]?
    public let frequencyRank: String?
    public let topicCodes: [String]?
    public let labels: [LexicalLabel]?

    public var primaryStressed: String? {
        stressForms?.first(where: { $0.isPrimary == true })?.stressedForm
        ?? stressForms?.first?.stressedForm
    }
}

// MARK: - Legacy types (kept for backward compatibility)

/// Legacy relation type -- prefer SenseRelation / DerivationalRelation for new code.
public struct LexicalRelation: Codable {
    public let relationType: String?
    public let targetLemmaId: String?
    public let targetEntryId: String?
    public let targetLemma: String?
    /// Also accept `targetHeadword` from newer API shape.
    public let targetHeadword: String?

    public var displayTarget: String? {
        targetHeadword ?? targetLemma
    }
}

/// Type-erased Codable for JSONB-like fields
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v.map(\.value) }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v.mapValues(\.value) }
        else { value = NSNull() }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [Any]: try container.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]: try container.encode(v.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}

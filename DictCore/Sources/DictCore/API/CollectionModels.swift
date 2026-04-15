import Foundation

// MARK: - Collection list / detail responses

public struct CollectionListPayload: Codable {
    public let items: [CollectionSummary]
    public let total: Int
}

public struct CollectionSummary: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let type: String?
    public let topicCode: String?
    public let itemCount: Int?
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, type
        case topicCode = "topic_code"
        case itemCount = "item_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct CollectionDetail: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let type: String?
    public let topicCode: String?
    public let itemCount: Int?
    public let createdAt: String?
    public let updatedAt: String?
    public let items: [CollectionItem]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, type, items
        case topicCode = "topic_code"
        case itemCount = "item_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct CollectionItem: Codable, Identifiable {
    public let id: String
    public let itemType: String?
    public let itemId: String?
    public let entryId: String?
    public let primaryHeadword: String?
    public let userNote: String?
    public let displayOrder: Int?
    public let addedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemType = "item_type"
        case itemId = "item_id"
        case entryId = "entry_id"
        case primaryHeadword = "primary_headword"
        case userNote = "user_note"
        case displayOrder = "display_order"
        case addedAt = "added_at"
    }
}

// MARK: - Request bodies

public struct CreateCollectionRequest: Encodable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct AddCollectionItemRequest: Encodable {
    public let itemType: String
    public let itemId: String

    public init(itemType: String, itemId: String) {
        self.itemType = itemType
        self.itemId = itemId
    }
}

// MARK: - Generic OK response

public struct CollectionOkResponse: Codable {
    public let ok: Bool?
}

import Foundation

/// API error envelope from backend (4xx/5xx responses).
public struct DictAPIError: Error {
    public let code: String
    public let message: String
    public let details: [ErrorDetail]
    public let requestId: String?

    public struct ErrorDetail: Codable {
        public let field: String?
        public let code: String?
        public let message: String?
    }
}

extension DictAPIError {
    public static func from(data: Data) -> DictAPIError? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) else { return nil }
        return DictAPIError(
            code: envelope.error.code,
            message: envelope.error.message,
            details: envelope.error.details ?? [],
            requestId: envelope.error.requestId
        )
    }
}

struct APIErrorEnvelope: Codable {
    let error: APIErrorBody
}

struct APIErrorBody: Codable {
    let code: String
    let message: String
    let details: [DictAPIError.ErrorDetail]?
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case code, message, details
        case requestId = "request_id"
    }
}

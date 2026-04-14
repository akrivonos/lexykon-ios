import Foundation

/// Async request contract implemented by `DictAPIClient`. Use for test doubles and future DI.
public protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        body: Encodable?,
        requiresAuth: Bool
    ) async throws -> T
}

extension DictAPIClient: APIClientProtocol {}

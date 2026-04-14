import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

public protocol Requestable {
    associatedtype Response: Decodable
    var method: HTTPMethod { get }
    var path: String { get }
    var queryItems: [URLQueryItem] { get }
    var body: Encodable? { get }
    var requiresAuth: Bool { get }
}

extension Requestable {
    public var queryItems: [URLQueryItem] { [] }
    public var body: Encodable? { nil }
    public var requiresAuth: Bool { false }
}

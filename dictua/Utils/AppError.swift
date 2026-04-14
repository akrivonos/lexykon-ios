import Foundation
import DictCore

public enum AppError: Error {
    case notFound
    case unauthorized
    case network(Error)
    case serverError(String)
    case rateLimit
    case api(DictAPIError)

    public var message: String {
        switch self {
        case .notFound: return "Not found"
        case .unauthorized: return "Please log in"
        case .network: return "Network error"
        case .serverError(let m): return m
        case .rateLimit: return "Too many requests"
        case .api(let e): return e.message
        }
    }

    public static func from(_ error: Error) -> AppError {
        if let api = error as? DictAPIError {
            switch api.code {
            case "NOT_FOUND", "ENTRY_NOT_FOUND": return .notFound
            case "TOKEN_INVALID", "INVALID_CREDENTIALS": return .unauthorized
            case "RATE_LIMIT", "TOO_MANY_REQUESTS": return .rateLimit
            default: return .api(api)
            }
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return .network(error)
        }
        return .serverError(error.localizedDescription)
    }
}

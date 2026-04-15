import Foundation
import Logging

/// Async URLSession-based API client with snake_case → camelCase decoding and error envelope parsing.
public actor DictAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStorage: TokenStorage
    private let tokenRefreshActor: TokenRefreshActor
    private let acceptLanguage: () -> String
    private let sourceLang: () -> String
    private let logger: Logger

    // NOTE: decoder does NOT use `.convertFromSnakeCase`. That strategy conflicts
    // with explicit CodingKeys: Swift applies the strategy to JSON keys BEFORE
    // matching them against CodingKey raw values, so snake_case raw values like
    // `"match_type"` never match converted JSON keys like `"matchType"`. All
    // response models in this module use explicit CodingKeys with snake_case raw
    // values instead.
    //
    // Encoder DOES use `.convertToSnakeCase` because it's safe: if a request type
    // has no explicit CodingKeys, property names are converted camel → snake;
    // if it has CodingKeys, the raw values are used as-is.
    private let decoder: JSONDecoder = JSONDecoder()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    public init(
        baseURL: URL,
        tokenStorage: TokenStorage,
        tokenRefreshActor: TokenRefreshActor,
        acceptLanguage: @escaping () -> String = { "uk" },
        sourceLang: @escaping () -> String = { "ru" },
        timeoutIntervalForRequest: TimeInterval = 15,
        logger: Logger = Logger(label: "lexykon.api")
    ) {
        self.baseURL = baseURL
        self.tokenStorage = tokenStorage
        self.tokenRefreshActor = tokenRefreshActor
        self.acceptLanguage = acceptLanguage
        self.sourceLang = sourceLang
        self.logger = logger
        var config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutIntervalForRequest
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.urlCache = URLCache(
            memoryCapacity: 8 * 1_024 * 1_024,
            diskCapacity: 50 * 1_024 * 1_024,
            diskPath: "lexykon_api_cache"
        )
        self.session = URLSession(configuration: config)
    }

    /// Perform a request; on 401 with requiresAuth, refresh token and retry once. Retries once on 429 after `Retry-After`.
    public func perform<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        try await performInternal(request, responseType: responseType, retryCount: 0)
    }

    private func performInternal<T: Decodable>(_ request: URLRequest, responseType: T.Type, retryCount: Int) async throws -> T {
        var req = addHeaders(to: request)
        if request.value(forHTTPHeaderField: "Authorization") == nil,
           let token = tokenStorage.getAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: req)
        let http = response as? HTTPURLResponse

        if http?.statusCode == 429, retryCount < 1 {
            let delay = retryAfterDelay(from: http)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await performInternal(request, responseType: responseType, retryCount: retryCount + 1)
        }

        if http?.statusCode == 401, request.value(forHTTPHeaderField: "Authorization") != nil {
            let refreshed = await tokenRefreshActor.refreshIfNeeded()
            if refreshed {
                var retryReq = addHeaders(to: request)
                if let token = tokenStorage.getAccessToken() {
                    retryReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResponse) = try await session.data(for: retryReq)
                let retryHttp = retryResponse as? HTTPURLResponse
                if let code = retryHttp?.statusCode, (200...299).contains(code) {
                    return try decodeSuccess(data: retryData, as: T.self)
                }
                if retryHttp?.statusCode == 401 {
                    throw DictAPIError(code: "TOKEN_INVALID", message: "Session expired", details: [], requestId: nil)
                }
                throw DictAPIError.from(data: retryData) ?? DictAPIError(code: "UNKNOWN", message: String(data: retryData, encoding: .utf8) ?? "", details: [], requestId: nil)
            }
        }

        if let code = http?.statusCode, (200...299).contains(code) {
            return try decodeSuccess(data: data, as: T.self)
        }

        if let apiError = DictAPIError.from(data: data) {
            throw apiError
        }
        throw DictAPIError(code: "UNKNOWN", message: String(data: data, encoding: .utf8) ?? "Request failed", details: [], requestId: nil)
    }

    /// Parses `Retry-After` as seconds (integer) or HTTP-date; defaults to 1s.
    private func retryAfterDelay(from response: HTTPURLResponse?) -> TimeInterval {
        guard let raw = response?.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return 1 }
        if let secs = TimeInterval(raw), secs >= 0 { return min(secs, 60) }
        let formatter = HTTPDateFormatter.shared
        if let date = formatter.date(from: raw) {
            let d = date.timeIntervalSinceNow
            return d > 0 ? min(d, 60) : 1
        }
        return 1
    }

    /// Build and perform from path, method, query, body.
    public func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        var comp = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            comp.queryItems = queryItems
        }
        guard let url = comp.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        if let b = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(AnyEncodable(value: b))
        }
        if requiresAuth, let token = tokenStorage.getAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if shouldSendReturnRefreshTokenHeader(path: path, method: method) {
            req.setValue("1", forHTTPHeaderField: "X-Return-Refresh-Token")
        }
        return try await perform(req, responseType: T.self)
    }

    private func shouldSendReturnRefreshTokenHeader(path: String, method: HTTPMethod) -> Bool {
        guard method == .post else { return false }
        return path == "auth/login" || path == "auth/register" || path == "auth/refresh"
    }

    private func addHeaders(to request: URLRequest) -> URLRequest {
        var r = request
        r.setValue(acceptLanguage(), forHTTPHeaderField: "Accept-Language")
        r.setValue(sourceLang(), forHTTPHeaderField: "X-Source-Lang")
        r.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        return r
    }

    private func decodeSuccess<T: Decodable>(data: Data, as type: T.Type) throws -> T {
        do {
            let wrapper = try decoder.decode(DataWrapper<T>.self, from: data)
            return wrapper.data
        } catch {
            // Some endpoints return { "data": ... } or bare array
            if let direct = try? decoder.decode(T.self, from: data) {
                return direct
            }
            throw error
        }
    }
}

private struct DataWrapper<T: Decodable>: Decodable {
    let data: T
}

private enum HTTPDateFormatter {
    static let shared: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

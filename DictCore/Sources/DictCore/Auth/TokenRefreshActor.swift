import Foundation
import Logging

/// Coalesces 401 handling: one refresh at a time, notifies on session expired.
public actor TokenRefreshActor {
    public static let sessionExpiredNotification = Notification.Name("DictCoreSessionExpired")

    private let baseURL: URL
    private let tokenStorage: TokenStorage
    private let acceptLanguage: () -> String
    private let logger: Logger
    private var refreshTask: Task<Bool, Error>?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    public init(
        baseURL: URL,
        tokenStorage: TokenStorage,
        acceptLanguage: @escaping () -> String = { "uk" },
        logger: Logger = Logger(label: "lexykon.auth.refresh")
    ) {
        self.baseURL = baseURL
        self.tokenStorage = tokenStorage
        self.acceptLanguage = acceptLanguage
        self.logger = logger
    }

    /// Call when a 401 is received. Returns true if refresh succeeded and caller should retry.
    public func refreshIfNeeded() async -> Bool {
        if let existing = refreshTask {
            do {
                return try await existing.value
            } catch {
                return false
            }
        }
        let task = Task<Bool, Error> {
            defer { refreshTask = nil }
            return try await doRefresh()
        }
        refreshTask = task
        do {
            return try await task.value
        } catch {
            return false
        }
    }

    private func doRefresh() async throws -> Bool {
        guard let refreshToken = tokenStorage.getRefreshToken(), !refreshToken.isEmpty else {
            notifyExpired()
            return false
        }
        var url = baseURL.appendingPathComponent("auth/refresh")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(acceptLanguage(), forHTTPHeaderField: "Accept-Language")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        req.setValue("1", forHTTPHeaderField: "X-Return-Refresh-Token")
        req.httpBody = try encoder.encode(RefreshRequest(refreshToken: refreshToken))

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: req)
        let http = response as? HTTPURLResponse

        if let code = http?.statusCode, (200...299).contains(code) {
            struct RefreshResponse: Decodable {
                let data: AuthResponseData
            }
            let decoded = try decoder.decode(RefreshResponse.self, from: data)
            try tokenStorage.setTokens(access: decoded.data.accessToken, refresh: decoded.data.refreshToken ?? refreshToken)
            logger.info("Token refresh succeeded")
            return true
        }

        try? tokenStorage.clearTokens()
        notifyExpired()
        if let apiError = DictAPIError.from(data: data) {
            logger.warning("Token refresh failed: \(apiError.code)")
            throw apiError
        }
        throw DictAPIError(code: "TOKEN_INVALID", message: "Session expired", details: [], requestId: nil)
    }

    private func notifyExpired() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.sessionExpiredNotification, object: nil)
        }
    }
}

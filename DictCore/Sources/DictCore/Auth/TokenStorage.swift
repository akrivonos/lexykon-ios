import Foundation

/// Storage for JWT tokens; shared via App Group for extensions.
public protocol TokenStorage: Sendable {
    func getAccessToken() -> String?
    func getRefreshToken() -> String?
    func setTokens(access: String, refresh: String?) throws
    func clearTokens() throws
}

/// Keychain-backed token storage with App Group support.
public final class KeychainTokenStorage: TokenStorage, @unchecked Sendable {
    private let serviceName: String
    private let accessGroup: String?
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"

    public init(serviceName: String = "ua.dict.auth", accessGroup: String? = "group.ua.dict.shared") {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    public func getAccessToken() -> String? {
        get(key: accessTokenKey)
    }

    public func getRefreshToken() -> String? {
        get(key: refreshTokenKey)
    }

    public func setTokens(access: String, refresh: String?) throws {
        try set(key: accessTokenKey, value: access)
        if let r = refresh {
            try set(key: refreshTokenKey, value: r)
        }
    }

    public func clearTokens() throws {
        try delete(key: accessTokenKey)
        try delete(key: refreshTokenKey)
    }

    private func get(key: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func set(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try delete(key: key)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.addFailed(status)
        }
    }

    private func delete(key: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        SecItemDelete(query as CFDictionary)
        // Ignore errSecItemNotFound
    }

    public enum KeychainError: Error {
        case addFailed(OSStatus)
    }
}

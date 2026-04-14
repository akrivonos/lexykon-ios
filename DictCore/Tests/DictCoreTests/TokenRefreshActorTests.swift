import XCTest
@testable import DictCore

final class TokenRefreshActorTests: XCTestCase {

    func testRefreshIfNeededReturnsFalseWhenNoRefreshToken() async {
        let storage = MockTokenStorage(accessToken: nil, refreshToken: nil)
        let baseURL = URL(string: "https://api.example.com/api/v1")!
        let actor = TokenRefreshActor(baseURL: baseURL, tokenStorage: storage)
        let result = await actor.refreshIfNeeded()
        XCTAssertFalse(result)
    }

    func testRefreshIfNeededReturnsFalseWhenRefreshTokenEmpty() async {
        let storage = MockTokenStorage(accessToken: "old", refreshToken: "")
        let baseURL = URL(string: "https://api.example.com/api/v1")!
        let actor = TokenRefreshActor(baseURL: baseURL, tokenStorage: storage)
        let result = await actor.refreshIfNeeded()
        XCTAssertFalse(result)
    }
}

private final class MockTokenStorage: TokenStorage, @unchecked Sendable {
    var accessToken: String?
    var refreshToken: String?

    init(accessToken: String?, refreshToken: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func getAccessToken() -> String? { accessToken }
    func getRefreshToken() -> String? { refreshToken }
    func setTokens(access: String, refresh: String?) throws { accessToken = access; refreshToken = refresh ?? refreshToken }
    func clearTokens() throws { accessToken = nil; refreshToken = nil }
}

import XCTest
@testable import DictCore

final class TokenStorageTests: XCTestCase {

    func testKeychainTokenStorageSetAndGet() throws {
        let storage = KeychainTokenStorage(serviceName: "test.ua.dict.auth", accessGroup: nil)
        try? storage.clearTokens()
        try storage.setTokens(access: "access123", refresh: "refresh456")
        XCTAssertEqual(storage.getAccessToken(), "access123")
        XCTAssertEqual(storage.getRefreshToken(), "refresh456")
        try storage.clearTokens()
        XCTAssertNil(storage.getAccessToken())
        XCTAssertNil(storage.getRefreshToken())
    }
}

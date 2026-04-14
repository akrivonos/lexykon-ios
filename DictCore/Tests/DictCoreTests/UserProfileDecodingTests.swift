import XCTest
@testable import DictCore

final class UserProfileDecodingTests: XCTestCase {

    func testDecodesEmailVerifiedAndTelegram() throws {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "email": "u@example.com",
          "email_verified": true,
          "telegram_chat_id": 12345,
          "telegram_linked_at": "2024-01-01T00:00:00+00:00",
          "theme": "dark"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let u = try decoder.decode(UserProfile.self, from: Data(json.utf8))
        XCTAssertEqual(u.id, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(u.emailVerified, true)
        XCTAssertEqual(u.telegramChatId, 12345)
        XCTAssertEqual(u.theme, "dark")
    }
}

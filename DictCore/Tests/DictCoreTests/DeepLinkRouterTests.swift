import XCTest
@testable import DictCore

final class DeepLinkRouterTests: XCTestCase {

    func testParseEntryByHost() {
        let u = URL(string: "lexykon://entry/hello-world")!
        XCTAssertEqual(DeepLinkRouter.parse(url: u), .entry(slug: "hello-world"))
    }

    func testParseLookupQuery() {
        var comp = URLComponents()
        comp.scheme = "lexykon"
        comp.host = "lookup"
        comp.queryItems = [URLQueryItem(name: "q", value: "книга")]
        let u = comp.url!
        XCTAssertEqual(DeepLinkRouter.parse(url: u), .lookup(query: "книга"))
    }

    func testParseResetPassword() {
        let u = URL(string: "lexykon://reset-password?token=abc123")!
        XCTAssertEqual(DeepLinkRouter.parse(url: u), .resetPassword(token: "abc123"))
    }

    func testParseHttpsEntry() {
        let u = URL(string: "https://dict.ua/entry/some-slug")!
        XCTAssertEqual(DeepLinkRouter.parse(url: u), .entry(slug: "some-slug"))
    }
}

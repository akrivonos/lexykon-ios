import XCTest
@testable import DictCore

final class OfflineDictionaryServiceTests: XCTestCase {

    func testIsDownloadedFalseWhenFileMissing() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID().uuidString).sqlite")
        let service = OfflineDictionaryService(fileURL: url)
        XCTAssertFalse(service.isDownloaded)
    }

    func testLookupLemmaReturnsEmptyWhenNotDownloaded() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID().uuidString).sqlite")
        let service = OfflineDictionaryService(fileURL: url)
        let results = service.lookupLemma(form: "тест")
        XCTAssertTrue(results.isEmpty)
    }
}

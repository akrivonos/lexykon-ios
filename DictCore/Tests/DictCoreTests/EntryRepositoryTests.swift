import XCTest
@testable import DictCore

final class EntryRepositoryTests: XCTestCase {

    func testCoreDataEntryRepositoryInit() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let repo = CoreDataEntryRepository(storeURL: url)
        XCTAssertNotNil(repo)
    }

    func testRemoveAllEntries() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString).sqlite")
        let repo = CoreDataEntryRepository(storeURL: url)
        try await repo.removeAllEntries()
    }
}

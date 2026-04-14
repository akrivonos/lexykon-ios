import Foundation

/// Abstraction for cached entry storage. Current implementation uses Core Data for all supported iOS versions (iOS 16+); SwiftData was deferred.
public protocol EntryRepository: Sendable {
    func fetchEntry(id: String) async throws -> EntryDetail?
    func saveEntry(_ entry: EntryDetail, isFavorited: Bool) async throws
    func recordAccess(entryId: String) async throws
    /// Deletes all cached entries (e.g. from Settings).
    func removeAllEntries() async throws
}

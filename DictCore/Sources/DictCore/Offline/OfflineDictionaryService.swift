import Foundation
import SQLite
import Logging

/// Result of offline morphology lookup (form → lemma).
public struct OfflineLemma: Sendable {
    public let lemmaId: String
    public let lemma: String
    public let pos: String?
}

/// SQLite-backed offline morphology; read-only. File is bundled or downloaded to Application Support.
public final class OfflineDictionaryService: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "lexykon.offline.dict")
    private let logger = Logger(label: "lexykon.offline")
    private var connection: Connection?
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Returns true if the SQLite file exists and can be opened.
    public var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Download morphology.sqlite from the given URL to Application Support. Calls progress(0) at start and progress(1) at end. No-op if already downloaded.
    public func downloadIfNeeded(from sourceURL: URL, progress: @escaping (Double) -> Void) async throws {
        guard !isDownloaded else {
            progress(1.0)
            return
        }
        progress(0)
        let session = URLSession.shared
        let (tempURL, _) = try await session.download(from: sourceURL)
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: fileURL)
        progress(1.0)
    }

    /// Look up inflected form; returns matching lemmas (lemma_id, lemma, pos). Empty if file missing or no match.
    public func lookupLemma(form: String) -> [OfflineLemma] {
        guard isDownloaded else { return [] }
        return queue.sync {
            guard let conn = connection ?? try? Connection(fileURL.path, readonly: true) else { return [] }
            if connection == nil { connection = conn }
            return Self.query(conn: conn, form: form.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Schema: table `word_forms` with columns form, lemma_id (text). Lemma/pos from same row if present.
    private static func query(conn: Connection, form: String) -> [OfflineLemma] {
        let wf = Table("word_forms")
        let formCol = Expression<String>("form")
        let lemmaIdCol = Expression<String>("lemma_id")
        do {
            var results: [OfflineLemma] = []
            for row in try conn.prepare(wf.filter(formCol == form).limit(20)) {
                let lemmaId = row[lemmaIdCol]
                let lemma = (try? row.get(Expression<String?>("lemma"))) ?? ""
                let pos: String? = try? row.get(Expression<String?>("pos"))
                results.append(OfflineLemma(lemmaId: String(lemmaId), lemma: lemma.isEmpty ? "" : lemma, pos: pos))
            }
            return results
        } catch {
            return []
        }
    }
}

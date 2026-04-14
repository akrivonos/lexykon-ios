import Foundation
import DictCore

public final class EntryDetailViewModel: ObservableObject {
    @Published public private(set) var entry: EntryDetail?
    @Published public private(set) var state: LoadingState<EntryDetail> = .idle
    @Published public var savedState: Bool = false

    private let entryId: String?
    private let slug: String?
    private let apiClient: DictAPIClient
    private let entryRepository: EntryRepository

    /// Load by UUID id (legacy / Handoff) or by lexical slug.
    public init(entryId: String? = nil, slug: String? = nil, apiClient: DictAPIClient, entryRepository: EntryRepository) {
        precondition(entryId != nil || slug != nil, "entryId or slug required")
        self.entryId = entryId
        self.slug = slug
        self.apiClient = apiClient
        self.entryRepository = entryRepository
    }

    public var canonicalEntryId: String? {
        entry?.id ?? entryId
    }

    public var canonicalSlug: String? {
        entry?.slug ?? slug
    }

    public func load() async {
        state = .loading
        if let slug, entryId == nil {
            await loadFreshBySlug(slug)
            return
        }
        guard let id = entryId else {
            await MainActor.run { state = .failed(URLError(.badURL)) }
            return
        }
        await loadWithCache(id: id)
    }

    private func loadFreshBySlug(_ slug: String) async {
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        do {
            let fetched: EntryDetail = try await apiClient.request(
                path: "entries/by-slug/\(enc)",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "include_ai_explanation", value: "true"),
                    URLQueryItem(name: "source_lang", value: "ru"),
                ]
            )
            if let eid = fetched.id, !eid.isEmpty {
                try? await entryRepository.saveEntry(fetched, isFavorited: false)
                try? await entryRepository.recordAccess(entryId: eid)
            }
            await MainActor.run {
                entry = fetched
                state = .loaded(fetched)
            }
        } catch {
            await MainActor.run { state = .failed(error) }
        }
    }

    private func loadWithCache(id: String) async {
        if let cached = try? await entryRepository.fetchEntry(id: id) {
            await MainActor.run {
                entry = cached
                state = .loaded(cached)
            }
            try? await entryRepository.recordAccess(entryId: id)
        }

        do {
            let fetched: EntryDetail = try await apiClient.request(
                path: "entries/\(id)",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "include_ai_explanation", value: "true"),
                    URLQueryItem(name: "source_lang", value: "ru"),
                ]
            )
            let shouldSave = entry == nil || shouldReplaceCache(cached: entry, fetched: fetched)
            if shouldSave {
                try? await entryRepository.saveEntry(fetched, isFavorited: false)
                await MainActor.run {
                    entry = fetched
                    state = .loaded(fetched)
                }
            }
            try? await entryRepository.recordAccess(entryId: id)
        } catch {
            await MainActor.run {
                if entry == nil {
                    state = .failed(error)
                }
            }
        }
    }

    private func shouldReplaceCache(cached: EntryDetail?, fetched: EntryDetail) -> Bool {
        guard let cached else { return true }
        guard let cu = cached.updatedAt, let fu = fetched.updatedAt, !cu.isEmpty, !fu.isEmpty else {
            return true
        }
        return cu != fu
    }
}

import Foundation
import DictCore
import Combine

public final class LookupViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var autocompleteResults: [AutocompleteItem] = []
    @Published public var lookupState: LoadingState<LookupResponse> = .idle
    @Published public var recentSearches: [String] = []

    /// Accumulated paged rows (offset pagination on `/lookup`).
    @Published public private(set) var extendedReverseResults: [ReverseLookupResult] = []
    @Published public private(set) var extendedFuzzySuggestions: [FuzzySuggestion] = []
    @Published public private(set) var extendedAlsoFound: [AlsoFoundSummary] = []
    @Published public private(set) var hasMoreResults = false
    @Published public private(set) var isLoadingMore = false

    private let apiClient: DictAPIClient
    private var autocompleteTask: Task<Void, Never>?
    private let debounceMs = 150
    private let maxRecent = 20
    private let recentKey = "lexykon.recent_searches"
    private let pageSize = 20
    private var nextOffset = 0
    private var activeQuery = ""

    public init(apiClient: DictAPIClient) {
        self.apiClient = apiClient
        recentSearches = (UserDefaults.standard.stringArray(forKey: recentKey)) ?? []
    }

    public func triggerAutocomplete() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 1 else {
            autocompleteResults = []
            return
        }
        autocompleteTask?.cancel()
        autocompleteTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
            guard !Task.isCancelled else { return }
            do {
                let results: [AutocompleteItem] = try await apiClient.request(
                    path: "lookup/autocomplete",
                    method: .get,
                    queryItems: [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "10")]
                )
                await MainActor.run { autocompleteResults = results }
            } catch {
                await MainActor.run { autocompleteResults = [] }
            }
        }
    }

    public func performLookup() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            lookupState = .idle
            resetPagination()
            return
        }
        addRecent(query)
        activeQuery = query
        nextOffset = 0
        resetPagination()
        lookupState = .loading
        Task {
            await fetchLookupPage(offset: 0, replace: true)
        }
    }

    public func loadMore() {
        guard case .loaded = lookupState, hasMoreResults, !isLoadingMore else { return }
        isLoadingMore = true
        let off = nextOffset
        Task {
            await fetchLookupPage(offset: off, replace: false)
            await MainActor.run { isLoadingMore = false }
        }
    }

    public func applyFuzzySuggestion(lemma: String) {
        searchText = lemma
        performLookup()
    }

    private func resetPagination() {
        extendedReverseResults = []
        extendedFuzzySuggestions = []
        extendedAlsoFound = []
        hasMoreResults = false
    }

    private func fetchLookupPage(offset: Int, replace: Bool) async {
        do {
            let response: LookupResponse = try await apiClient.request(
                path: "lookup",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "q", value: activeQuery),
                    URLQueryItem(name: "lang", value: "uk"),
                    URLQueryItem(name: "limit", value: "\(pageSize)"),
                    URLQueryItem(name: "offset", value: "\(offset)"),
                ]
            )
            await MainActor.run {
                if replace {
                    lookupState = .loaded(response)
                    extendedReverseResults = response.reverseResults ?? []
                    extendedFuzzySuggestions = response.fuzzySuggestions ?? []
                    extendedAlsoFound = response.alsoFound ?? response.homographs?.map(AlsoFoundSummary.fromHomograph) ?? []
                } else {
                    mergeAppend(response)
                }
                nextOffset = offset + pageSize
                hasMoreResults = Self.pageIndicatesMore(response, limit: pageSize)
            }
        } catch {
            await MainActor.run {
                if replace {
                    lookupState = .failed(error)
                }
            }
        }
    }

    private func mergeAppend(_ response: LookupResponse) {
        if let r = response.reverseResults {
            let existing = Set(extendedReverseResults.compactMap(\.entryId))
            for x in r where x.entryId.map({ !existing.contains($0) }) ?? true {
                extendedReverseResults.append(x)
            }
        }
        if let f = response.fuzzySuggestions {
            for x in f {
                let k = (x.entryId ?? "") + (x.lemma ?? "")
                if !extendedFuzzySuggestions.contains(where: { ($0.entryId ?? "") + ($0.lemma ?? "") == k }) {
                    extendedFuzzySuggestions.append(x)
                }
            }
        }
        if let a = response.alsoFound {
            let existing = Set(extendedAlsoFound.map(\.id))
            for x in a where !existing.contains(x.id) {
                extendedAlsoFound.append(x)
            }
        } else if let h = response.homographs {
            for x in h {
                let conv = AlsoFoundSummary.fromHomograph(x)
                if !extendedAlsoFound.contains(where: { $0.id == conv.id }) {
                    extendedAlsoFound.append(conv)
                }
            }
        }
    }

    private static func pageIndicatesMore(_ response: LookupResponse, limit: Int) -> Bool {
        let rev = response.reverseResults?.count ?? 0
        let fuzzy = response.fuzzySuggestions?.count ?? 0
        let also = response.alsoFound?.count ?? response.homographs?.count ?? 0
        return rev >= limit || fuzzy >= limit || also >= limit
    }

    private func addRecent(_ query: String) {
        var list = recentSearches
        list.removeAll { $0 == query }
        list.insert(query, at: 0)
        list = Array(list.prefix(maxRecent))
        recentSearches = list
        UserDefaults.standard.set(list, forKey: recentKey)
    }
}

private extension AlsoFoundSummary {
    static func fromHomograph(_ h: Homograph) -> AlsoFoundSummary {
        AlsoFoundSummary(
            entryId: h.lemmaId,
            headword: h.lemma,
            pos: h.pos,
            slug: nil,
            contentTier: nil
        )
    }
}

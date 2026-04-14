import Foundation
import DictCore

public final class TranslateViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var sourceLang = "ru"
    @Published public var autocompleteSuggestions: [String] = []
    @Published public var state: LoadingState<TranslateSearchResponse> = .idle
    @Published public private(set) var accumulatedResults: [TranslateResultGroup] = []
    @Published public private(set) var hasMore = false
    @Published public private(set) var isLoadingMore = false

    public static let sourceLanguages = ["ru", "en", "de", "pl"]

    private let apiClient: DictAPIClient
    private var autocompleteTask: Task<Void, Never>?
    private let debounceMs = 150
    private let pageSize = 20
    private var nextOffset = 0
    private var activeQuery = ""

    public init(apiClient: DictAPIClient) {
        self.apiClient = apiClient
    }

    public func triggerAutocomplete() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 1 else {
            autocompleteSuggestions = []
            return
        }
        autocompleteTask?.cancel()
        autocompleteTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
            guard !Task.isCancelled else { return }
            do {
                let words: [String] = try await apiClient.request(
                    path: "translate/autocomplete",
                    method: .get,
                    queryItems: [
                        URLQueryItem(name: "q", value: q),
                        URLQueryItem(name: "source_lang", value: sourceLang),
                    ]
                )
                await MainActor.run { autocompleteSuggestions = words }
            } catch {
                await MainActor.run { autocompleteSuggestions = [] }
            }
        }
    }

    public func search() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            state = .idle
            accumulatedResults = []
            hasMore = false
            return
        }
        activeQuery = q
        nextOffset = 0
        state = .loading
        accumulatedResults = []
        Task {
            await fetchPage(offset: 0, replace: true)
        }
    }

    public func loadMore() {
        guard case .loaded = state, hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        let off = nextOffset
        Task {
            await fetchPage(offset: off, replace: false)
            await MainActor.run { isLoadingMore = false }
        }
    }

    private func fetchPage(offset: Int, replace: Bool) async {
        do {
            let response: TranslateSearchResponse = try await apiClient.request(
                path: "translate",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "q", value: activeQuery),
                    URLQueryItem(name: "source_lang", value: sourceLang),
                    URLQueryItem(name: "limit", value: "\(pageSize)"),
                    URLQueryItem(name: "offset", value: "\(offset)"),
                ]
            )
            await MainActor.run {
                if replace {
                    state = .loaded(response)
                    accumulatedResults = response.results
                } else {
                    let existing = Set(accumulatedResults.map(\.id))
                    for g in response.results where !existing.contains(g.id) {
                        accumulatedResults.append(g)
                    }
                }
                nextOffset = offset + pageSize
                hasMore = response.results.count >= pageSize
            }
        } catch {
            await MainActor.run {
                if replace {
                    state = .failed(error)
                }
            }
        }
    }
}

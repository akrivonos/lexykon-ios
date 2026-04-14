import SwiftUI
import DictCore

struct DiscoverView: View {
    @StateObject private var viewModel: DiscoverViewModel

    init() {
        _viewModel = StateObject(wrappedValue: DiscoverViewModel(apiClient: AppEnvironment.shared.apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let items):
                if items.isEmpty {
                    Text("No entries to show.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            if let eid = item.entryId, !eid.isEmpty {
                                NavigationLink(destination: EntryDetailView(specifier: .id(eid))) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.headword ?? eid)
                                            .font(.headline)
                                        HStack {
                                            if let pos = item.pos { Text(pos).font(.caption) }
                                            if let tier = item.tier {
                                                Text(tier)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            case .failed(let err):
                ErrorView(message: err.localizedDescription) {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle("Discover")
        .task { await viewModel.load() }
    }
}

@MainActor
final class DiscoverViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded([DiscoverEntrySummary])
        case failed(Error)
    }

    @Published private(set) var state: State = .idle
    private let apiClient: DictAPIClient

    init(apiClient: DictAPIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let payload: DiscoverFeedPayload = try await apiClient.request(
                path: "discover",
                method: .get,
                queryItems: [URLQueryItem(name: "limit", value: "30")],
                requiresAuth: false
            )
            state = .loaded(payload.items ?? [])
        } catch {
            state = .failed(error)
        }
    }
}

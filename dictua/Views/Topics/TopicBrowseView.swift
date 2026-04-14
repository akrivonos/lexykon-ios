import SwiftUI
import DictCore

struct TopicBrowseView: View {
    let topic: String
    @StateObject private var viewModel: TopicBrowseViewModel

    init(topic: String) {
        self.topic = topic
        _viewModel = StateObject(wrappedValue: TopicBrowseViewModel(apiClient: AppEnvironment.shared.apiClient, topic: topic))
    }

    var body: some View {
        List {
            ForEach(viewModel.entries, id: \.id) { entry in
                if let id = entry.id {
                    NavigationLink(destination: EntryDetailView(entryId: id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.headword ?? "")
                                    .font(.headline)
                                if let pos = entry.pos {
                                    Text(pos).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let def = entry.definition, !def.isEmpty {
                                Text(def)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(topic)
        .task {
            await viewModel.load()
        }
    }
}

struct TopicEntrySummary: Codable {
    let id: String?
    let headword: String?
    let pos: String?
    let entryType: String?
    let contentTier: String?
    let definition: String?
}

public final class TopicBrowseViewModel: ObservableObject {
    @Published public var entries: [TopicEntrySummary] = []
    @Published public var isLoading = false

    private let apiClient: DictAPIClient
    private let topic: String

    public init(apiClient: DictAPIClient, topic: String) {
        self.apiClient = apiClient
        self.topic = topic
    }

    public func load() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        do {
            struct R: Decodable {
                let data: [TopicEntrySummary]
            }
            let r: R = try await apiClient.request(
                path: "browse/topics/\(topic)",
                method: .get,
                queryItems: [URLQueryItem(name: "limit", value: "50"), URLQueryItem(name: "offset", value: "0")]
            )
            await MainActor.run { entries = r.data }
        } catch {
            await MainActor.run { entries = [] }
        }
    }
}

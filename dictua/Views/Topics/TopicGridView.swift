import SwiftUI
import DictCore

struct TopicGridView: View {
    @StateObject private var viewModel: TopicGridViewModel

    init() {
        _viewModel = StateObject(wrappedValue: TopicGridViewModel(apiClient: AppEnvironment.shared.apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let topics):
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                        ForEach(topics, id: \.topic) { topic in
                            NavigationLink(destination: TopicBrowseView(topic: topic.topic ?? "")) {
                                VStack(alignment: .leading) {
                                    Text(topic.labelUk ?? topic.topic ?? "")
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text("\(topic.entryCount ?? 0) entries")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.load()
                }
            case .failed(let err):
                ErrorView(message: err.localizedDescription) {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle("Topics")
        .task {
            await viewModel.load()
        }
    }
}

struct TopicItem: Codable {
    let topic: String?
    let labelUk: String?
    let entryCount: Int?

    enum CodingKeys: String, CodingKey {
        case topic
        case labelUk = "label_uk"
        case entryCount = "entry_count"
    }
}

public final class TopicGridViewModel: ObservableObject {
    @Published var state: LoadingState<[TopicItem]> = .idle

    private let apiClient: DictAPIClient

    public init(apiClient: DictAPIClient) {
        self.apiClient = apiClient
    }

    public func load() async {
        await MainActor.run { state = .loading }
        do {
            struct R: Decodable {
                let data: [TopicItem]
            }
            let r: R = try await apiClient.request(path: "browse/topics", method: .get)
            await MainActor.run { state = .loaded(r.data) }
        } catch {
            await MainActor.run { state = .failed(error) }
        }
    }
}

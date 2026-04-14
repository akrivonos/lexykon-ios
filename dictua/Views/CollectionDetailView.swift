import SwiftUI
import DictCore

struct CollectionDetailView: View {
    let collectionId: String
    let collectionName: String

    @EnvironmentObject private var appEnv: AppEnvironment
    @StateObject private var viewModel: CollectionsViewModel

    init(collectionId: String, collectionName: String) {
        self.collectionId = collectionId
        self.collectionName = collectionName
        let app = AppEnvironment.shared
        _viewModel = StateObject(wrappedValue: CollectionsViewModel(
            apiClient: app.apiClient,
            tokenStorage: app.tokenStorage
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.selectedCollection == nil {
                ProgressView()
                    .accessibilityLabel(String(localized: "Loading collection"))
            } else if let detail = viewModel.selectedCollection {
                if let items = detail.items, !items.isEmpty {
                    itemsList(items)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(String(localized: "This collection is empty"))
                            .font(.headline)
                        Text(String(localized: "Save entries from the lookup tab"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundStyle(Color.red)
                    Button(String(localized: "Retry")) {
                        Task { await viewModel.loadDetail(id: collectionId) }
                    }
                }
            }
        }
        .navigationTitle(collectionName)
        .task {
            await viewModel.loadDetail(id: collectionId)
        }
    }

    private func itemsList(_ items: [CollectionItem]) -> some View {
        List {
            if let desc = viewModel.selectedCollection?.description, !desc.isEmpty {
                Section {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(items) { item in
                    Button {
                        if let entryId = item.entryId {
                            appEnv.presentedEntry = .id(entryId)
                        } else if let itemId = item.itemId {
                            appEnv.presentedEntry = .id(itemId)
                        }
                    } label: {
                        HStack {
                            Text(item.primaryHeadword ?? item.itemId ?? "—")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { indexSet in
                    let toDelete = indexSet.map { items[$0] }
                    Task {
                        for item in toDelete {
                            await viewModel.removeItem(collectionId: collectionId, itemId: item.id)
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadDetail(id: collectionId)
        }
    }
}

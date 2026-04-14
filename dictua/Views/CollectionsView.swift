import SwiftUI
import DictCore

struct CollectionsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var appEnv: AppEnvironment
    @StateObject private var viewModel: CollectionsViewModel

    @State private var showCreateAlert = false
    @State private var newCollectionName = ""

    init() {
        let app = AppEnvironment.shared
        _viewModel = StateObject(wrappedValue: CollectionsViewModel(
            apiClient: app.apiClient,
            tokenStorage: app.tokenStorage
        ))
    }

    var body: some View {
        Group {
            if !auth.isLoggedIn {
                notLoggedInView
            } else if viewModel.isLoading && viewModel.collections.isEmpty {
                ProgressView()
                    .accessibilityLabel(String(localized: "Loading collections"))
            } else if viewModel.collections.isEmpty {
                emptyStateView
            } else {
                collectionsList
            }
        }
        .navigationTitle(String(localized: "Collections"))
        .toolbar {
            if auth.isLoggedIn {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newCollectionName = ""
                        showCreateAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Create collection"))
                }
            }
        }
        .alert(String(localized: "New collection"), isPresented: $showCreateAlert) {
            TextField(String(localized: "Collection name"), text: $newCollectionName)
            Button(String(localized: "Create")) {
                let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await viewModel.createCollection(name: name) }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .task {
            if auth.isLoggedIn {
                await viewModel.loadCollections()
            }
        }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            if loggedIn {
                Task { await viewModel.loadCollections() }
            } else {
                viewModel.collections = []
            }
        }
    }

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "Sign in to manage collections"))
                .font(.headline)
            Button(String(localized: "Sign in")) {
                appEnv.selectedMainTab = .settings
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "No collections yet"))
                .font(.headline)
            Text(String(localized: "Create a collection to save entries"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(String(localized: "Create collection")) {
                newCollectionName = ""
                showCreateAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collectionsList: some View {
        List {
            ForEach(viewModel.collections) { collection in
                NavigationLink {
                    CollectionDetailView(collectionId: collection.id, collectionName: collection.name)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name)
                                .font(.body)
                            if let desc = collection.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("\(collection.itemCount ?? 0)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                let ids = indexSet.map { viewModel.collections[$0].id }
                Task {
                    for id in ids {
                        await viewModel.deleteCollection(id: id)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadCollections()
        }
    }
}

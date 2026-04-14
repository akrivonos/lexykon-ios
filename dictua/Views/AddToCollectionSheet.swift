import SwiftUI
import DictCore

struct AddToCollectionSheet: View {
    let entryId: String
    @Binding var isPresented: Bool

    @StateObject private var viewModel: CollectionsViewModel
    @State private var showCreateAlert = false
    @State private var newCollectionName = ""
    @State private var savedToCollection: String?

    init(entryId: String, isPresented: Binding<Bool>) {
        self.entryId = entryId
        self._isPresented = isPresented
        let app = AppEnvironment.shared
        _viewModel = StateObject(wrappedValue: CollectionsViewModel(
            apiClient: app.apiClient,
            tokenStorage: app.tokenStorage
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("Save to collection"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { cancelToolbar }
                .alert("New collection", isPresented: $showCreateAlert, actions: { createAlertActions })
                .task { await viewModel.loadCollections() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.collections.isEmpty {
            ProgressView()
                .accessibilityLabel(Text("Loading collections"))
        } else if let saved = savedToCollection {
            savedConfirmation(saved)
        } else {
            collectionsList
        }
    }

    private func savedConfirmation(_ saved: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Saved to \(saved)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isPresented = false
            }
        }
    }

    private var collectionsList: some View {
        List {
            Button {
                newCollectionName = ""
                showCreateAlert = true
            } label: {
                Label("Create new collection", systemImage: "plus.circle")
            }
            ForEach(viewModel.collections) { collection in
                collectionRow(collection)
            }
        }
    }

    private func collectionRow(_ collection: CollectionSummary) -> some View {
        Button {
            Task { await addToCollection(collection) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let count = collection.itemCount {
                        Text("\(count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(.accentColor)
            }
        }
    }

    @ToolbarContentBuilder
    private var cancelToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                isPresented = false
            }
        }
    }

    @ViewBuilder
    private var createAlertActions: some View {
        TextField("Collection name", text: $newCollectionName)
        Button("Create & save") {
            let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            Task {
                if let created = await viewModel.createCollection(name: name) {
                    let success = await viewModel.addItem(collectionId: created.id, entryId: entryId)
                    if success {
                        savedToCollection = created.name
                    }
                }
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    private func addToCollection(_ collection: CollectionSummary) async {
        let success = await viewModel.addItem(collectionId: collection.id, entryId: entryId)
        if success {
            savedToCollection = collection.name
        }
    }
}

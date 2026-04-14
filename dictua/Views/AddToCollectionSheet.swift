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
            Group {
                if viewModel.isLoading && viewModel.collections.isEmpty {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Loading collections"))
                } else if let saved = savedToCollection {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text(String(localized: "Saved to \(saved)"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isPresented = false
                        }
                    }
                } else {
                    List {
                        Button {
                            newCollectionName = ""
                            showCreateAlert = true
                        } label: {
                            Label(String(localized: "Create new collection"), systemImage: "plus.circle")
                        }

                        ForEach(viewModel.collections) { collection in
                            Button {
                                Task { await addToCollection(collection) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(collection.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        if let count = collection.itemCount {
                                            Text(String(localized: "\(count) items"))
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
                    }
                }
            }
            .navigationTitle(String(localized: "Save to collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        isPresented = false
                    }
                }
            }
            .alert(String(localized: "New collection"), isPresented: $showCreateAlert) {
                TextField(String(localized: "Collection name"), text: $newCollectionName)
                Button(String(localized: "Create & save")) {
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
                Button(String(localized: "Cancel"), role: .cancel) {}
            }
            .task {
                await viewModel.loadCollections()
            }
        }
    }

    private func addToCollection(_ collection: CollectionSummary) async {
        let success = await viewModel.addItem(collectionId: collection.id, entryId: entryId)
        if success {
            savedToCollection = collection.name
        }
    }
}

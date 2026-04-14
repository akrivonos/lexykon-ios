import SwiftUI
import DictCore

struct LookupView: View {
    @EnvironmentObject var appEnv: AppEnvironment
    @StateObject private var viewModel: LookupViewModel
    @State private var hasSubmitted = false

    init() {
        _viewModel = StateObject(wrappedValue: LookupViewModel(apiClient: AppEnvironment.shared.apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if hasSubmitted {
                switch viewModel.lookupState {
                case .idle:
                    EmptyView()
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(String(localized: "Loading"))
                case .loaded:
                    LookupResultsView(viewModel: viewModel)
                case .failed(let error):
                    ErrorView(message: error.localizedDescription) {
                        viewModel.performLookup()
                    }
                }
            } else {
                autocompleteOrRecent
            }
        }
        .navigationTitle(String(localized: "Lookup"))
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.triggerAutocomplete()
        }
        .onAppear {
            applyPendingLookupIfNeeded()
        }
        .onChange(of: appEnv.pendingLookupQuery) { _, _ in
            applyPendingLookupIfNeeded()
        }
    }

    private func applyPendingLookupIfNeeded() {
        guard let q = appEnv.pendingLookupQuery, !q.isEmpty else { return }
        viewModel.searchText = q
        hasSubmitted = true
        viewModel.performLookup()
        appEnv.pendingLookupQuery = nil
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .accessibilityHidden(true)
            TextField(String(localized: "Search word…"), text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .onSubmit {
                    hasSubmitted = true
                    viewModel.performLookup()
                }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var autocompleteOrRecent: some View {
        if !viewModel.searchText.isEmpty && !viewModel.autocompleteResults.isEmpty {
            List(viewModel.autocompleteResults, id: \.lemmaId) { item in
                Button {
                    viewModel.searchText = item.lemma ?? ""
                    hasSubmitted = true
                    viewModel.performLookup()
                } label: {
                    HStack {
                        Text(autocompleteDisplay(item))
                            .font(.body)
                        if let pos = item.pos {
                            Text(pos)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityHint(String(localized: "Search for this word"))
            }
        } else if viewModel.searchText.isEmpty && !viewModel.recentSearches.isEmpty {
            List {
                Section(String(localized: "Recent")) {
                    ForEach(viewModel.recentSearches, id: \.self) { query in
                        Button {
                            viewModel.searchText = query
                            hasSubmitted = true
                            viewModel.performLookup()
                        } label: {
                            Text(query)
                        }
                    }
                }
            }
        } else {
            Spacer()
        }
    }

    private func autocompleteDisplay(_ item: AutocompleteItem) -> String {
        if let s = item.headwordStressed, !s.isEmpty { return s }
        if let s = item.primaryStressed, !s.isEmpty { return s }
        return item.lemma ?? ""
    }
}

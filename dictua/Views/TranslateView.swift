import SwiftUI
import DictCore

struct TranslateView: View {
    @StateObject private var viewModel: TranslateViewModel
    @State private var hasSearched = false

    init() {
        _viewModel = StateObject(wrappedValue: TranslateViewModel(apiClient: AppEnvironment.shared.apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Source language"), selection: $viewModel.sourceLang) {
                ForEach(TranslateViewModel.sourceLanguages, id: \.self) { code in
                    Text(code.uppercased()).tag(code)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityLabel(String(localized: "Source language"))

            HStack {
                Image(systemName: "character.book.closed")
                    .accessibilityHidden(true)
                TextField(String(localized: "Word to translate…"), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .onSubmit {
                        hasSearched = true
                        viewModel.search()
                    }
                    .onChange(of: viewModel.searchText) { _, _ in
                        viewModel.triggerAutocomplete()
                    }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)

            if !hasSearched, viewModel.searchText.isEmpty == false, !viewModel.autocompleteSuggestions.isEmpty {
                List(viewModel.autocompleteSuggestions, id: \.self) { word in
                    Button {
                        viewModel.searchText = word
                        hasSearched = true
                        viewModel.search()
                    } label: {
                        Text(word)
                    }
                }
            } else {
                resultsList
            }
        }
        .navigationTitle(String(localized: "Translate"))
    }

    @ViewBuilder
    private var resultsList: some View {
        switch viewModel.state {
        case .idle:
            Spacer()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(String(localized: "Loading"))
        case .loaded:
            List {
                ForEach(viewModel.accumulatedResults) { group in
                    NavigationLink(destination: entryDestination(for: group)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.ukrainianLemma ?? "")
                                .font(.headline)
                            if let pos = group.pos {
                                Text(pos).font(.caption).foregroundStyle(.secondary)
                            }
                            if let first = group.translations?.first?.sourceWord {
                                Text(first).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                if viewModel.hasMore {
                    Button {
                        viewModel.loadMore()
                    } label: {
                        if viewModel.isLoadingMore {
                            ProgressView()
                        } else {
                            Text(String(localized: "Load more"))
                        }
                    }
                }
            }
        case .failed(let error):
            ErrorView(message: error.localizedDescription) {
                viewModel.search()
            }
        }
    }

    @ViewBuilder
    private func entryDestination(for group: TranslateResultGroup) -> some View {
        if let slug = group.slug, !slug.isEmpty {
            EntryDetailView(specifier: .slug(slug))
        } else if let id = group.entryId, !id.isEmpty {
            EntryDetailView(specifier: .id(id))
        } else {
            Text(String(localized: "Entry not available"))
        }
    }
}

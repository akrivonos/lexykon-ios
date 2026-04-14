import SwiftUI
import DictCore

struct LookupResultsView: View {
    @ObservedObject var viewModel: LookupViewModel

    var body: some View {
        List {
            if case .loaded(let response) = viewModel.lookupState {
                if let entry = response.entry {
                    Section {
                        entryRow(entry)
                    }
                }
                if !viewModel.extendedAlsoFound.isEmpty {
                    Section(String(localized: "Also found")) {
                        ForEach(viewModel.extendedAlsoFound) { row in
                            alsoFoundRow(row)
                        }
                    }
                }
                if !viewModel.extendedReverseResults.isEmpty {
                    Section(String(localized: "Russian")) {
                        ForEach(Array(viewModel.extendedReverseResults.enumerated()), id: \.offset) { _, r in
                            reverseRow(r)
                        }
                    }
                }
                if !viewModel.extendedFuzzySuggestions.isEmpty {
                    Section(String(localized: "Suggestions")) {
                        ForEach(Array(viewModel.extendedFuzzySuggestions.enumerated()), id: \.offset) { _, f in
                            Button {
                                if let lemma = f.lemma {
                                    viewModel.applyFuzzySuggestion(lemma: lemma)
                                }
                            } label: {
                                HStack {
                                    Text(f.primaryStressed ?? f.lemma ?? "")
                                        .foregroundStyle(.primary)
                                    if let pos = f.pos {
                                        Text(pos)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityHint(String(localized: "Search for this suggestion"))
                        }
                    }
                }
                if viewModel.hasMoreResults {
                    Section {
                        Button {
                            viewModel.loadMore()
                        } label: {
                            if viewModel.isLoadingMore {
                                ProgressView()
                            } else {
                                Text(String(localized: "Load more"))
                            }
                        }
                        .disabled(viewModel.isLoadingMore)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: LookupEntrySummary) -> some View {
        if (entry.slug != nil && !(entry.slug ?? "").isEmpty) || (entry.id != nil && !(entry.id ?? "").isEmpty) {
            NavigationLink(destination: destination(forEntryId: entry.id, slug: entry.slug)) {
                ResultRow(entry: entry)
            }
        } else {
            ResultRow(entry: entry)
        }
    }

    @ViewBuilder
    private func alsoFoundRow(_ row: AlsoFoundSummary) -> some View {
        if (row.slug != nil && !(row.slug ?? "").isEmpty) || (row.entryId != nil && !(row.entryId ?? "").isEmpty) {
            NavigationLink(destination: destination(forEntryId: row.entryId, slug: row.slug)) {
                VStack(alignment: .leading) {
                    Text(row.headword ?? "")
                        .font(.headline)
                    if let pos = row.pos {
                        Text(pos).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text(row.headword ?? "—")
        }
    }

    @ViewBuilder
    private func reverseRow(_ r: ReverseLookupResult) -> some View {
        if (r.slug != nil && !(r.slug ?? "").isEmpty) || (r.entryId != nil && !(r.entryId ?? "").isEmpty) {
            NavigationLink(destination: destination(forEntryId: r.entryId, slug: r.slug)) {
                VStack(alignment: .leading) {
                    Text(r.primaryStressed ?? r.lemma ?? "")
                    if let pos = r.pos {
                        Text(pos).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text(r.primaryStressed ?? r.lemma ?? "—")
        }
    }

    @ViewBuilder
    private func destination(forEntryId id: String?, slug: String?) -> some View {
        if let slug, !slug.isEmpty {
            EntryDetailView(specifier: .slug(slug))
        } else if let id, !id.isEmpty {
            EntryDetailView(specifier: .id(id))
        } else {
            EmptyView()
        }
    }
}

private struct ResultRow: View {
    let entry: LookupEntrySummary
    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.lemma?.primaryStressed ?? entry.lemma?.lemma ?? "")
                .font(.headline)
            if let pos = entry.lemma?.pos {
                Text(pos).font(.caption).foregroundStyle(.secondary)
            }
            if let tier = entry.tier {
                Text(tier).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

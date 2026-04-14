import AVFoundation
import SwiftUI
import DictCore

struct EntryDetailView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var appEnv: AppEnvironment
    let specifier: PresentedEntrySpecifier
    @StateObject private var viewModel: EntryDetailViewModel
    @State private var showFlagSheet = false
    @State private var showCollectionSheet = false
    @State private var flagDescription = ""
    @State private var flagGuestEmail = ""
    @State private var flagMessage: String?
    @State private var flagError: String?
    @State private var flagSubmitting = false
    @State private var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    init(specifier: PresentedEntrySpecifier) {
        self.specifier = specifier
        let app = AppEnvironment.shared
        switch specifier {
        case .id(let id):
            _viewModel = StateObject(wrappedValue: EntryDetailViewModel(
                entryId: id,
                apiClient: app.apiClient,
                entryRepository: app.entryRepository
            ))
        case .slug(let slug):
            _viewModel = StateObject(wrappedValue: EntryDetailViewModel(
                slug: slug,
                apiClient: app.apiClient,
                entryRepository: app.entryRepository
            ))
        }
    }

    /// Backward-compatible initializer (UUID).
    init(entryId: String) {
        self.init(specifier: .id(entryId))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .accessibilityLabel(String(localized: "Loading entry"))
            case .loaded(let entry):
                entryContent(entry)
            case .failed(let error):
                ErrorView(message: error.localizedDescription) {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle(viewModel.entry?.headword ?? viewModel.entry?.lemma?.lemma ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        if auth.isLoggedIn {
                            showCollectionSheet = true
                        } else {
                            AppEnvironment.shared.selectedMainTab = .settings
                            AppEnvironment.shared.clearPresentedEntry()
                        }
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel(String(localized: "Save to collection"))

                    Button {
                        showFlagSheet = true
                    } label: {
                        Image(systemName: "flag")
                    }
                    .accessibilityLabel(String(localized: "Report an error"))
                }
            }
        }
        .userActivity("com.dictua.viewEntry", isActive: viewModel.entry != nil) { activity in
            activity.userInfo = [
                "entry_id": viewModel.canonicalEntryId ?? "",
                "entry_slug": viewModel.canonicalSlug ?? "",
            ]
            activity.title = viewModel.entry?.headword ?? viewModel.entry?.lemma?.lemma
            let path = viewModel.canonicalSlug ?? viewModel.canonicalEntryId ?? ""
            activity.webpageURL = URL(string: "https://dict.ua/entry/\(path)")
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = false
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showFlagSheet) {
            NavigationStack {
                Form {
                    Section(String(localized: "Describe the issue")) {
                        TextField(String(localized: "What is wrong?"), text: $flagDescription, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    if !useContributorFlagPath {
                        Section(String(localized: "Contact")) {
                            TextField(String(localized: "Your email"), text: $flagGuestEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                    }
                    if let flagMessage {
                        Section {
                            Text(flagMessage).foregroundStyle(.green)
                        }
                    }
                    if let flagError {
                        Section {
                            Text(flagError).foregroundStyle(.red).font(.caption)
                        }
                    }
                    Section {
                        Button {
                            Task { await submitFlag() }
                        } label: {
                            if flagSubmitting {
                                ProgressView()
                            } else {
                                Text(String(localized: "Submit report"))
                            }
                        }
                        .disabled(flagSubmitting || flagDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!useContributorFlagPath && flagGuestEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    }
                }
                .navigationTitle(String(localized: "Report error"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) {
                            showFlagSheet = false
                            clearFlagUI()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCollectionSheet) {
            if let entryId = viewModel.canonicalEntryId {
                AddToCollectionSheet(entryId: entryId, isPresented: $showCollectionSheet)
            }
        }
    }

    private var useContributorFlagPath: Bool {
        guard auth.isLoggedIn, let r = auth.user?.role?.lowercased() else { return false }
        return ["contributor", "editor", "admin"].contains(r)
    }

    private func submitFlag() async {
        guard let targetId = viewModel.canonicalEntryId, !targetId.isEmpty else { return }
        flagSubmitting = true
        flagError = nil
        flagMessage = nil
        defer { flagSubmitting = false }
        let desc = flagDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = flagGuestEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await ContributionsService.submitErrorFlag(
                apiClient: AppEnvironment.shared.apiClient,
                targetId: targetId,
                description: desc,
                guestEmail: email.isEmpty ? nil : email,
                useAuthenticatedContributorPath: useContributorFlagPath
            )
            flagMessage = String(localized: "Thank you — we received your report.")
        } catch let e as DictAPIError {
            flagError = e.message
        } catch {
            flagError = error.localizedDescription
        }
    }

    private func clearFlagUI() {
        flagDescription = ""
        flagGuestEmail = ""
        flagMessage = nil
        flagError = nil
    }

    private func entryContent(_ entry: EntryDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(entry)
                if let senses = entry.senses, !senses.isEmpty {
                    ForEach(Array(senses.enumerated()), id: \.offset) { idx, sense in
                        SenseCardView(sense: sense, number: idx + 1, showNumber: senses.count > 1)
                    }
                }
                if let wordForms = entry.wordForms, !wordForms.isEmpty {
                    ParadigmView(wordForms: wordForms)
                }
                if let relations = entry.derivationalRelations, !relations.isEmpty {
                    DerivationalRelationsView(relations: relations)
                }
                if let anchors = entry.anchorEntries, !anchors.isEmpty {
                    AnchorEntriesView(entries: anchors)
                }
                if let phrases = entry.containingPhrases, !phrases.isEmpty {
                    ContainingPhrasesView(phrases: phrases)
                }
                if let etymologies = entry.entryEtymologies, !etymologies.isEmpty {
                    EtymologySectionView(etymologies: etymologies)
                }
            }
            .padding()
        }
    }

    private func pronounce(_ text: String) {
        let clean = text.replacingOccurrences(of: "\u{0301}", with: "")
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "uk-UA")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }

    private func header(_ entry: EntryDetail) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 8) {
                Text(entry.primaryStressed ?? entry.headword ?? entry.lemma?.lemma ?? "")
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                Button {
                    pronounce(entry.primaryStressed ?? entry.headword ?? entry.lemma?.lemma ?? "")
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Вимова")
            }
            if let pos = entry.pos ?? entry.lemma?.pos {
                Text(pos).font(.subheadline).foregroundStyle(.secondary)
            }
            GrammarBadgesView(grammar: entry.grammar)
                .padding(.vertical, 2)
            if let tags = entry.lemma?.topicCodes, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            NavigationLink(destination: TopicBrowseView(topic: tag)) {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Topic \(tag)"))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sense Card

struct SenseCardView: View {
    @EnvironmentObject private var appEnv: AppEnvironment
    let sense: Sense
    var number: Int = 1
    var showNumber: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showNumber {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            // Style / context badges
            if let style = sense.style, style != "neutral" {
                Text(style)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }

            // Definition from senseTexts
            if let def = sense.definitionUk {
                Text(def).font(.body)
            }

            // Translations from senseEquivalents
            if let equivalents = sense.senseEquivalents, !equivalents.isEmpty {
                let preferredLangs = TranslationLangPreference.get()
                let filtered = equivalents.filter { eq in
                    guard let lang = eq.lang else { return true }
                    return preferredLangs.contains(lang)
                }
                if !filtered.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { _, eq in
                            HStack(spacing: 6) {
                                if let lang = eq.lang {
                                    Text(lang.uppercased())
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                }
                                Text(eq.equivalent ?? "")
                                    .font(.subheadline.weight(.medium))
                                if let matchType = eq.matchType, matchType != "exact" {
                                    Text("(\(matchType))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Examples from illustrations
            if let illustrations = sense.illustrations, !illustrations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Examples"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    ForEach(Array(illustrations.enumerated()), id: \.offset) { _, ill in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ill.illustrationText ?? ill.text ?? "")
                                .font(.body)
                                .italic()
                            if let source = ill.sourceType, !source.isEmpty {
                                Text("— \(source)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(width: 3),
                            alignment: .leading
                        )
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                }
            }

            // Sense relations (synonyms, antonyms, etc.)
            if let relations = sense.senseRelations, !relations.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(relations.enumerated()), id: \.offset) { _, rel in
                        if let headword = rel.targetHeadword {
                            HStack(spacing: 4) {
                                Text(rel.relationType ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Button {
                                    if let id = rel.targetEntryId {
                                        appEnv.presentedEntry = .id(id)
                                    } else {
                                        appEnv.presentedEntry = .slug(headword)
                                    }
                                } label: {
                                    Text(headword)
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Paradigm

struct ParadigmView: View {
    let wordForms: [WordForm]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ], spacing: 8) {
                ForEach(Array(wordForms.enumerated()), id: \.offset) { _, wf in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wf.form ?? "\u{2014}")
                            .font(.subheadline)
                        if let tags = wf.tags, !tags.isEmpty {
                            Text(tags)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
            .padding(.top, 4)
        } label: {
            Text(String(localized: "Paradigm"))
                .font(.headline)
        }
    }
}

// MARK: - Derivational Relations

private struct DerivationalRelationsView: View {
    @EnvironmentObject private var appEnv: AppEnvironment
    let relations: [DerivationalRelation]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Related words"))
                .font(.headline)
            ForEach(Array(relations.enumerated()), id: \.offset) { _, rel in
                if let headword = rel.targetHeadword {
                    HStack(spacing: 4) {
                        if let type = rel.relationType {
                            Text(type)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            if let id = rel.targetEntryId {
                                appEnv.presentedEntry = .id(id)
                            } else {
                                appEnv.presentedEntry = .slug(headword)
                            }
                        } label: {
                            Text(headword)
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Anchor Entries ("See also")

private struct AnchorEntriesView: View {
    @EnvironmentObject private var appEnv: AppEnvironment
    let entries: [AnchorEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Див. також"))
                .font(.headline)
            ForEach(Array(entries.enumerated()), id: \.offset) { _, anchor in
                if let headword = anchor.headword {
                    HStack(spacing: 4) {
                        Button {
                            if let id = anchor.entryId {
                                appEnv.presentedEntry = .id(id)
                            } else if let slug = anchor.slug {
                                appEnv.presentedEntry = .slug(slug)
                            } else {
                                appEnv.presentedEntry = .slug(headword)
                            }
                        } label: {
                            Text(headword)
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        if let pos = anchor.pos {
                            Text(pos)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Containing Phrases

private struct ContainingPhrasesView: View {
    @EnvironmentObject private var appEnv: AppEnvironment
    let phrases: [ContainingPhrase]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Фразеологізми"))
                .font(.headline)
            ForEach(Array(phrases.enumerated()), id: \.offset) { _, phrase in
                if let headword = phrase.headword {
                    Button {
                        if let id = phrase.entryId {
                            appEnv.presentedEntry = .id(id)
                        } else if let slug = phrase.slug {
                            appEnv.presentedEntry = .slug(slug)
                        } else {
                            appEnv.presentedEntry = .slug(headword)
                        }
                    } label: {
                        Text(headword)
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Etymology

private struct EtymologySectionView: View {
    let etymologies: [Etymology]

    var body: some View {
        DisclosureGroup {
            ForEach(Array(etymologies.enumerated()), id: \.offset) { _, ety in
                VStack(alignment: .leading, spacing: 4) {
                    if let type = ety.etymologyType {
                        Text(type)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        if let lang = ety.sourceLanguage {
                            Text(lang)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let word = ety.sourceWord {
                            Text(word)
                                .font(.subheadline)
                                .italic()
                        }
                    }
                    if let notes = ety.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        } label: {
            Text(String(localized: "Etymology"))
                .font(.headline)
        }
    }
}

// MARK: - AI Explanation (kept for potential future use)

struct AIExplanationView: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(String(localized: "AI-generated explanation"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text).font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

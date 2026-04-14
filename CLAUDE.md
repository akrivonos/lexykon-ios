# iOS App — Lexykon

## Overview
Ukrainian dictionary app (Swift, SwiftUI, SPM). Xcode project with local DictCore package.
Bundle ID: `ua.dict.ios`. App name: "Lexykon". Deployment target: iOS 16.0+.

## Architecture
```
dictua.xcodeproj      — Main Xcode project
DictCore/             — Local Swift Package (SPM)
  Sources/DictCore/
    API/              — Data models (EntryModels, CollectionModels, TranslateModels, etc.)
    Networking/       — DictAPIClient (actor), APIClientProtocol, Requestable
    Auth/             — TokenStorage (Keychain), TokenRefreshActor
    Persistence/      — CoreDataEntryRepository (offline cache)
    Offline/          — OfflineDictionaryService (SQLite morphology)
    Utils/            — DeepLinkRouter, Errors
  Tests/              — 7 test files
dictua/               — Main app target
  dictuaApp.swift     — @main entry, deep links, foreground sync
  AppEnvironment.swift — Singleton DI container (apiClient, tokenStorage, viewModels)
  ContentView.swift   — 4-tab navigation (Lookup, Tools, Collections, Settings)
  Services/           — AuthService, NotificationScheduler
  ViewModels/         — Auth, Lookup, EntryDetail, Translate, AppSettings, Collections
  Views/
    Auth/             — Login, Register, ForgotPassword, ResetPassword, VerifyEmailBanner
    Tools/            — ToolsHubView (Translate, Topics, Discover), DiscoverView
    Topics/           — TopicGridView, TopicBrowseView
    EntryDetailView   — Full entry with senses, word forms, relations, TTS, save-to-collection
    LookupView        — Search + autocomplete
    LookupResultsView — Paged results
    TranslateView     — Reverse lookup by source language
    CollectionsView   — Collection list + create
    CollectionDetailView — Items in collection
    AddToCollectionSheet — Save entry to collection
    SettingsView      — Language, source lang, appearance
```

## Key decisions
- Auth is optional — app starts on Lookup, login prompted only for collections/contributions
- 4 tabs: Lookup, Tools, Collections, Settings (iPhone TabView, iPad NavigationSplitView)
- DictAPIClient is an actor with automatic 401 token refresh and 429 retry
- JSON decoding uses .convertFromSnakeCase globally — no manual CodingKeys needed
- Entry presented via fullScreenCover using `appEnv.presentedEntry = .slug(s)` or `.id(id)`
- Cross-references are clickable Buttons that set `appEnv.presentedEntry`
- TTS via AVSpeechSynthesizer with uk-UA voice at 0.85x rate
- Error report email is required (submit disabled when empty)
- Illustrations styled with gray background cards, italic text, source attribution

## API wiring
- Base URL: `https://lexykon.org/api/v1` (from Info.plist key API_BASE_URL)
- Entry detail returns: `senseTexts`, `senseEquivalents`, `illustrations` (auto-mapped from snake_case)
- `pos` at entry top-level, `headwords[]` array with `headwordStressed`/`isPrimary`
- `wordForms[]` with granular grammar fields (gramCase, gramNumber, etc.)
- `derivationalRelations`, `anchorEntries`, `containingPhrases`, `entryEtymologies`
- Topic browse returns `{id, headword, pos, definition}` — mapped to TopicEntrySummary
- Collections API: /api/v1/collections (list, create, delete, add/remove items)

## Build
- Requires macOS with Xcode 15+
- DictCore resolves automatically as local SPM package
- CI: `.github/workflows/ios-ci.yml` runs `swift test` on DictCore
- Firebase distribution: `.github/workflows/ios-firebase.yml` (manual trigger, needs Apple signing secrets)
- Signing: Automatic, needs Apple Developer Account for distribution

## Removed features (archived on web too)
- Tutor/SRS, Saved items, Surzhyk Bridge, Proofread, Phraseology, Interference
- Extensions (share, action, widgets) — removed for MVP
- BackgroundSyncService, WordOfDayBufferService, SpotlightIndexer

## Legacy
- Previous full codebase at `client/ios-legacy/` — reference only

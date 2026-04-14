# Dictua iOS

Native iOS app for the Dictua Ukrainian dictionary. Implements **Sprints 15–17**: Core Dictionary MVP, Tools & Tutor, and Extensions & Release.

## Scope (Sprints 15–17)

- **Sprint 15:** Lookup, entry detail, auth, saved items, settings, offline morphology, Core Spotlight.
- **Sprint 16:** Surzhyk bridge, proofreading, phraseology explorer, topic browsing, interference browser, SRS/tutor dashboard, background sync, local notifications.
- **Sprint 17:** Share Extension, Action Extension, WidgetKit (Word of Day, SRS Due, Quick Search), iPad `NavigationSplitView`, Handoff.

## Requirements

- Xcode 15+ (Swift 5.9)
- iOS 16.0+ deployment target
- Backend API running at `http://localhost:8000` (or set `API_BASE_URL` in Info.plist)

## Structure

- **dictua/** — Main app (SwiftUI): lookup, entry detail, auth, saved items, settings.
- **DictCore/** — Local Swift package: `DictAPIClient`, `TokenStorage`, `TokenRefreshActor`, models, `EntryRepository` (Core Data), `OfflineDictionaryService`, `SpotlightIndexer`.

## Build

1. Open `dictua.xcodeproj` in Xcode (from the `client/ios` directory).
2. Select the **dictua** scheme and a simulator or device.
3. Build (⌘B). The **DictCore** package resolves automatically (local path `DictCore`).

## App Group

The app uses App Group `group.ua.dict.shared` for Keychain and Core Data so extensions (Sprint 17) can share data. Ensure the App Group capability is enabled for the dictua target and that the identifier matches.

## Configuration

- **API base URL:** Set in `dictua/Info.plist` (`API_BASE_URL`) or use default `http://localhost:8000/api/v1`.

## Tests

- **DictCoreTests:** Unit tests for API client decoding, token storage, entry repository, Spotlight constants. Run from Xcode (⌘U) or `swift test` in `ios/DictCore`.
- **CI:** Run all tests before TestFlight upload; gate the release on passing unit and (when added) integration/UI tests.

## Sprint 15 scope (initial MVP)

- Lookup with 150ms debounced autocomplete, recent history.
- Entry detail: senses, translations, examples, paradigm, relations, AI explanation (lazy).
- Auth: login, register, JWT in Keychain, token refresh.
- Saved items: list, save/unsave, lists from API.
- Settings: interface language (uk, ru, pl, en, de), source language, appearance, offline dictionary status.
- Offline: morphology SQLite (download-on-demand), entry cache (1,000 entries, Core Data).
- Core Spotlight: last 500 viewed entries.
- Polish: haptics, `AppError`, `ErrorView`, String Catalog (5 locales).

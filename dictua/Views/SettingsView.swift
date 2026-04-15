import SwiftUI
import UIKit
import DictCore

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var settings: AppSettingsViewModel
    @EnvironmentObject var appEnv: AppEnvironment
    @State private var showAuthSheet = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var offlineDownloadError: String?
    @State private var telegramError: String?
    @State private var publicStats: PublicDictionaryStats?
    @State private var statsLoadError: String?
    @State private var deletePassword = ""
    @State private var deleteAccountConfirm = false
    @State private var deleteAccountError: String?
    @State private var showLanguageRestartAlert = false

    private var offlineDictionary: OfflineDictionaryService? { appEnv.offlineDictionary }
    private var offlineDownloadURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "OFFLINE_DICTIONARY_URL") as? String, let u = URL(string: s) else { return nil }
        return u
    }

    var body: some View {
        Form {
            if auth.isLoggedIn, auth.user?.emailVerified == false {
                Section {
                    VerifyEmailBannerView()
                }
            }
            Section("Interface language") {
                Picker("Language", selection: $settings.interfaceLang) {
                    ForEach(AppSettingsViewModel.interfaceLanguages, id: \.self) { code in
                        Text(localeName(code)).tag(code)
                    }
                }
            }
            Section("Source language") {
                Picker("Source language", selection: $settings.sourceLang) {
                    ForEach(AppSettingsViewModel.sourceLanguages, id: \.self) { code in
                        Text(code.uppercased()).tag(code)
                    }
                }
            }
            Section("Translation languages") {
                Text("Shown in dictionary entries (max 5)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TranslationLangPickerView()
            }
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
            Section(String(localized: "Dictionary")) {
                if let s = publicStats {
                    LabeledContent(String(localized: "Entries"), value: "\(s.totalEntries ?? 0)")
                    LabeledContent(String(localized: "Senses"), value: "\(s.totalSenses ?? 0)")
                    LabeledContent(String(localized: "Contributors"), value: "\(s.totalContributors ?? 0)")
                    if let top = s.topContributors, !top.isEmpty {
                        Text(String(localized: "Top contributors"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(top.prefix(5).enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.displayName ?? "—")
                                Spacer()
                                Text("\(row.acceptedCount ?? 0)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                } else if let statsLoadError {
                    Text(statsLoadError).font(.caption).foregroundStyle(Color.red)
                } else {
                    Text(String(localized: "Loading…"))
                        .foregroundStyle(.secondary)
                }
                Button(String(localized: "Refresh stats")) {
                    Task { await loadPublicStats() }
                }
            }
            Section("Offline dictionary") {
                if let offline = offlineDictionary {
                    if offline.isDownloaded {
                        Text("Downloaded")
                            .foregroundStyle(.secondary)
                    } else if isDownloading {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Downloading…")
                                .foregroundStyle(.secondary)
                            ProgressView(value: downloadProgress)
                        }
                    } else if let err = offlineDownloadError {
                        Text(err)
                            .foregroundStyle(Color.red)
                            .font(.caption)
                    } else {
                        Text("Not downloaded")
                            .foregroundStyle(.secondary)
                    }
                    if !offline.isDownloaded, !isDownloading, offlineDownloadURL != nil {
                        Button("Download offline dictionary") {
                            startOfflineDownload()
                        }
                    } else if offlineDownloadURL == nil, !offline.isDownloaded {
                        Text("Download URL not configured")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Section("Diagnostics") {
                Toggle("Share diagnostics", isOn: $settings.diagnosticsOptedIn)
            }
            if auth.isLoggedIn {
                Section(String(localized: "Account")) {
                    if auth.user?.telegramChatId != nil {
                        Text(String(localized: "Telegram linked"))
                            .foregroundStyle(.secondary)
                        Button(String(localized: "Unlink Telegram")) {
                            Task {
                                telegramError = await auth.unlinkTelegram()
                                await auth.refreshSessionIfNeeded()
                            }
                        }
                    } else {
                        Button(String(localized: "Link Telegram")) {
                            Task { await openTelegramDeepLink() }
                        }
                    }
                    if let telegramError {
                        Text(telegramError).font(.caption).foregroundStyle(Color.red)
                    }
                }
                Section(String(localized: "Danger zone")) {
                    SecureField(String(localized: "Password"), text: $deletePassword)
                        .textContentType(.password)
                    if let deleteAccountError {
                        Text(deleteAccountError).font(.caption).foregroundStyle(Color.red)
                    }
                    Button(String(localized: "Delete account"), role: .destructive) {
                        deleteAccountConfirm = true
                    }
                    .disabled(deletePassword.isEmpty)
                }
                Section {
                    Button("Log out", role: .destructive) {
                        Task { await auth.logout() }
                    }
                }
            } else {
                Section {
                    Button("Log in") {
                        showAuthSheet = true
                    }
                }
            }
            Section(String(localized: "Cache")) {
                Button(String(localized: "Clear downloaded entry cache"), role: .destructive) {
                    Task {
                        try? await appEnv.entryRepository.removeAllEntries()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showAuthSheet) {
            AuthLandingView()
                .environmentObject(auth)
                .environmentObject(settings)
                .environmentObject(appEnv)
        }
        .sheet(isPresented: Binding(
            get: { appEnv.pendingResetPasswordToken != nil },
            set: { if !$0 { appEnv.pendingResetPasswordToken = nil } }
        )) {
            NavigationStack {
                if let t = appEnv.pendingResetPasswordToken {
                    ResetPasswordView(initialToken: t)
                        .environmentObject(auth)
                        .environmentObject(appEnv)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "Close")) {
                                    appEnv.pendingResetPasswordToken = nil
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { appEnv.pendingVerifyEmailToken != nil },
            set: { if !$0 { appEnv.pendingVerifyEmailToken = nil } }
        )) {
            NavigationStack {
                if let t = appEnv.pendingVerifyEmailToken {
                    VerifyEmailFromTokenView(token: t)
                        .environmentObject(auth)
                        .environmentObject(appEnv)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "Close")) {
                                    appEnv.pendingVerifyEmailToken = nil
                                }
                            }
                        }
                }
            }
        }
        .onChange(of: auth.isLoggedIn) { _, new in
            if new { showAuthSheet = false }
        }
        .task {
            await auth.refreshSessionIfNeeded()
            await loadPublicStats()
        }
        .onChange(of: settings.interfaceLang) { _, new in
            // Write AppleLanguages so iOS picks up the new locale for `String(localized:)`
            // at the next app launch (SwiftUI does not hot-swap the bundle locale).
            UserDefaults.standard.set([new], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            showLanguageRestartAlert = true
            Task { await auth.syncLocalSettingsToServer(interfaceLang: new, sourceLang: settings.sourceLang, appearance: settings.appearance) }
        }
        .onChange(of: settings.sourceLang) { _, new in
            Task { await auth.syncLocalSettingsToServer(interfaceLang: settings.interfaceLang, sourceLang: new, appearance: settings.appearance) }
        }
        .onChange(of: settings.appearance) { _, new in
            Task { await auth.syncLocalSettingsToServer(interfaceLang: settings.interfaceLang, sourceLang: settings.sourceLang, appearance: new) }
        }
        .alert(String(localized: "Delete account?"), isPresented: $deleteAccountConfirm) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Delete"), role: .destructive) {
                Task {
                    deleteAccountError = nil
                    if let err = await auth.deleteAccount(password: deletePassword, reason: nil) {
                        deleteAccountError = err
                    }
                    deletePassword = ""
                }
            }
        } message: {
            Text(String(localized: "Your account will be scheduled for deletion. You have 30 days to recover by logging in."))
        }
        .alert(String(localized: "Language updated"), isPresented: $showLanguageRestartAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Please close and reopen the app to apply the new interface language."))
        }
    }

    private func loadPublicStats() async {
        statsLoadError = nil
        do {
            let s: PublicDictionaryStats = try await appEnv.apiClient.request(path: "stats/public", method: .get, requiresAuth: false)
            await MainActor.run { publicStats = s }
        } catch {
            await MainActor.run {
                publicStats = nil
                statsLoadError = error.localizedDescription
            }
        }
    }

    private func openTelegramDeepLink() async {
        telegramError = nil
        do {
            let link = try await auth.fetchTelegramLink()
            guard let s = link.deepLink, let url = URL(string: s) else {
                await MainActor.run { telegramError = String(localized: "Could not build Telegram link.") }
                return
            }
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        } catch let e as DictAPIError {
            await MainActor.run { telegramError = e.message }
        } catch {
            await MainActor.run { telegramError = error.localizedDescription }
        }
    }

    private func startOfflineDownload() {
        guard let url = offlineDownloadURL, let offline = offlineDictionary else { return }
        isDownloading = true
        offlineDownloadError = nil
        downloadProgress = 0
        Task {
            do {
                try await offline.downloadIfNeeded(from: url) { p in
                    Task { @MainActor in downloadProgress = p }
                }
            } catch {
                await MainActor.run {
                    offlineDownloadError = error.localizedDescription
                }
            }
            await MainActor.run { isDownloading = false }
        }
    }

    private func localeName(_ code: String) -> String {
        switch code {
        case "uk": return "Українська"
        case "ru": return "Русский"
        case "pl": return "Polski"
        case "en": return "English"
        case "de": return "Deutsch"
        default: return code
        }
    }
}

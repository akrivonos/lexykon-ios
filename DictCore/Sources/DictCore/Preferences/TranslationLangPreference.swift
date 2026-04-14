import Foundation

/// Manages preferred translation languages for filtering sense equivalents.
///
/// Priority: profile server value → UserDefaults → device locale → "en".
/// Max 5 languages. Available: ru, en, de, pl.
public enum TranslationLangPreference {
    public static let available = ["ru", "en", "de", "pl"]
    private static let key = "lexykon_translation_langs"
    private static let maxCount = 5

    public static func get() -> [String] {
        if let stored = UserDefaults.standard.stringArray(forKey: key),
           !stored.isEmpty {
            return Array(stored.filter { available.contains($0) }.prefix(maxCount))
        }
        return [detectDefault()]
    }

    public static func set(_ langs: [String]) {
        let valid = Array(langs.filter { available.contains($0) }.prefix(maxCount))
        UserDefaults.standard.set(valid, forKey: key)
    }

    /// Sync from server profile on login / profile load.
    public static func syncFromProfile(_ profileLangs: [String]?) {
        if let langs = profileLangs, !langs.isEmpty {
            set(langs)
        }
    }

    private static func detectDefault() -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return (available.contains(locale) && locale != "uk") ? locale : "en"
    }
}

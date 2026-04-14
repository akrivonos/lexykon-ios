import Foundation
import SwiftUI

public final class AppSettingsViewModel: ObservableObject {
    @AppStorage("interface_lang") public var interfaceLang = "uk"
    @AppStorage("source_lang") public var sourceLang = "ru"
    @AppStorage("appearance") public var appearance = "system"
    @AppStorage("diagnostics_opted_in") public var diagnosticsOptedIn = false

    public static let interfaceLanguages = ["uk", "ru", "pl", "en", "de"]
    public static let sourceLanguages = ["ru", "pl", "de", "en"]
    public static let appearances = ["system", "light", "dark"]

    /// Resolved color scheme for `.preferredColorScheme`; `nil` follows system.
    public var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

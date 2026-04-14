import Foundation

/// Detects responses that usually mean the route is not mounted (v2 production without legacy modules).
public enum LegacyAPIAvailability {
    public static func isUnavailableEndpoint(_ error: Error) -> Bool {
        if let e = error as? DictAPIError {
            if e.code == "NOT_FOUND" || e.code == "ENTRY_NOT_FOUND" { return true }
            let m = e.message
            if m.localizedCaseInsensitiveContains("not found") { return true }
        }
        return false
    }
}

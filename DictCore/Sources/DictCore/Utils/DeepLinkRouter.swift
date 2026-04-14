import Foundation

/// Parsed deep link targets for `lexykon://` and compatible https paths.
public enum DeepLinkTarget: Equatable {
    case entry(slug: String)
    case lookup(query: String)
    case resetPassword(token: String)
    case verifyEmail(token: String)
}

public enum DeepLinkRouter {
    /// Schemes we handle (custom + universal link host paths).
    public static func parse(url: URL) -> DeepLinkTarget? {
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "lexykon" || scheme == "dictua" {
            return parseLexykonURL(url)
        }
        if scheme == "https" || scheme == "http" {
            return parseUniversalURL(url)
        }
        return nil
    }

    private static func parseLexykonURL(_ url: URL) -> DeepLinkTarget? {
        let host = (url.host ?? "").lowercased()
        let pathTrim = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathSegments = pathTrim.isEmpty ? [] : pathTrim.split(separator: "/").map(String.init)
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if host == "entry" {
            let slug = pathSegments.joined(separator: "/")
            guard !slug.isEmpty else { return nil }
            return .entry(slug: slug)
        }
        if host == "lookup" {
            if let q = comps?.queryItems?.first(where: { $0.name == "q" })?.value, !q.isEmpty {
                return .lookup(query: q)
            }
            return nil
        }
        if host == "reset-password" {
            let token = tokenFromQuery(url) ?? ""
            guard !token.isEmpty else { return nil }
            return .resetPassword(token: token)
        }
        if host == "verify-email" {
            let token = tokenFromQuery(url) ?? ""
            guard !token.isEmpty else { return nil }
            return .verifyEmail(token: token)
        }

        guard !pathSegments.isEmpty else { return nil }
        switch pathSegments[0].lowercased() {
        case "entry":
            guard pathSegments.count >= 2 else { return nil }
            return .entry(slug: pathSegments.dropFirst().joined(separator: "/"))
        case "lookup":
            if let q = comps?.queryItems?.first(where: { $0.name == "q" })?.value, !q.isEmpty {
                return .lookup(query: q)
            }
            return nil
        case "reset-password":
            let token = tokenFromQuery(url) ?? ""
            guard !token.isEmpty else { return nil }
            return .resetPassword(token: token)
        case "verify-email":
            let token = tokenFromQuery(url) ?? ""
            guard !token.isEmpty else { return nil }
            return .verifyEmail(token: token)
        default:
            return nil
        }
    }

    private static func parseUniversalURL(_ url: URL) -> DeepLinkTarget? {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let segments = path.split(separator: "/").map(String.init)
        guard segments.count >= 2 else { return nil }
        if segments[0].lowercased() == "entry" {
            let slug = segments.dropFirst().joined(separator: "/")
            return slug.isEmpty ? nil : .entry(slug: slug)
        }
        if segments[0].lowercased() == "reset-password" {
            let token = tokenFromQuery(url) ?? ""
            return token.isEmpty ? nil : .resetPassword(token: token)
        }
        if segments[0].lowercased() == "verify-email" {
            let token = tokenFromQuery(url) ?? ""
            return token.isEmpty ? nil : .verifyEmail(token: token)
        }
        return nil
    }

    private static func tokenFromQuery(_ url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "token" })?
            .value
    }
}

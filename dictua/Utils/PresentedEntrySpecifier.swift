import Foundation

/// How to open an entry from Handoff, deep links, or navigation.
public enum PresentedEntrySpecifier: Equatable, Hashable {
    case id(String)
    case slug(String)
}

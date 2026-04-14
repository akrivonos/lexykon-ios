import SwiftUI
import DictCore

/// Renders grammar features from lemmas.grammar JSONB as styled badges.
///
/// Displays: [чол. рід] [неістота] [недок.] [зворотне] etc.
struct GrammarBadgesView: View {
    let grammar: [String: AnyCodable]?

    private static let genderLabels: [String: String] = [
        "masculine": "чол. рід", "feminine": "жін. рід", "neuter": "сер. рід"
    ]
    private static let animacyLabels: [String: String] = [
        "animate": "істота", "inanimate": "неістота"
    ]
    private static let aspectLabels: [String: String] = [
        "imperfective": "недок.", "perfective": "док."
    ]
    private static let numberLabels: [String: String] = [
        "plural_only": "тільки мн.", "singular_only": "тільки одн."
    ]
    private static let degreeLabels: [String: String] = [
        "comparative": "вищ. ст.", "superlative": "найвищ. ст."
    ]
    private static let subtypeLabels: [String: String] = [
        "geo": "геогр.", "surname": "прізвище", "first_name": "ім'я", "patronymic": "по батькові"
    ]

    var body: some View {
        let badges = buildBadges()
        if badges.isEmpty { EmptyView() }
        else {
            FlowLayout(spacing: 4) {
                ForEach(badges, id: \.label) { badge in
                    Text(badge.label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badge.color.opacity(0.12))
                        .foregroundColor(badge.color)
                        .cornerRadius(4)
                        .accessibilityLabel(String(localized: "Grammar feature: \(badge.label)"))
                }
            }
        }
    }

    private func str(_ key: String) -> String? {
        (grammar?[key]?.value as? String)
    }
    private func bool(_ key: String) -> Bool {
        (grammar?[key]?.value as? Bool) ?? false
    }

    private func buildBadges() -> [(label: String, color: Color)] {
        guard let grammar = grammar, !grammar.isEmpty else { return [] }
        var badges: [(String, Color)] = []

        if let g = str("gender"), let label = Self.genderLabels[g] {
            badges.append((label, .blue))
        }
        if let a = str("animacy"), let label = Self.animacyLabels[a] {
            badges.append((label, .green))
        }
        if let a = str("aspect"), let label = Self.aspectLabels[a] {
            badges.append((label, .purple))
        }
        if bool("reflexive") {
            badges.append(("зворотне", .purple))
        }
        if let n = str("number"), let label = Self.numberLabels[n] {
            badges.append((label, .orange))
        }
        if let d = str("degree"), let label = Self.degreeLabels[d] {
            badges.append((label, .gray))
        }
        if bool("participle") {
            badges.append(("дієприкм.", .gray))
        }
        if str("voice") == "passive" {
            badges.append(("пасивне", .gray))
        }
        if bool("proper") {
            let sub = str("subtype").flatMap { Self.subtypeLabels[$0] }
            let label = sub != nil ? "власна назва (\(sub!))" : "власна назва"
            badges.append((label, .pink))
        }
        if bool("indeclinable") {
            badges.append(("невідм.", .gray))
        }
        if bool("orthography_2019") {
            badges.append(("правопис 2019", .gray))
        }

        return badges
    }
}

/// Simple horizontal flow layout for badges (iOS 16+ compatible).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

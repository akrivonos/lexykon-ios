import SwiftUI
import DictCore

/// Toggle buttons for selecting preferred translation languages (max 5).
struct TranslationLangPickerView: View {
    @State private var selected: [String] = TranslationLangPreference.get()

    private let options: [(code: String, label: String)] = [
        ("ru", "Русский"),
        ("en", "English"),
        ("de", "Deutsch"),
        ("pl", "Polski"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.code) { opt in
                let isOn = selected.contains(opt.code)
                Button {
                    toggle(opt.code)
                } label: {
                    Text(opt.label)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isOn ? Color.accentColor : Color(.systemGray6))
                        .foregroundColor(isOn ? .white : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ code: String) {
        if selected.contains(code) {
            guard selected.count > 1 else { return } // Must keep at least 1
            selected.removeAll { $0 == code }
        } else {
            guard selected.count < 5 else { return }
            selected.append(code)
        }
        TranslationLangPreference.set(selected)
        // Sync to server if logged in
        Task {
            try? await AppEnvironment.shared.authService.updateProfile(
                UpdateProfileRequest(translationLangs: selected)
            )
        }
    }
}

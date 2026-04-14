import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var settings: AppSettingsViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                TextField("Display name (optional)", text: $displayName)
                if let msg = auth.errorMessage {
                    Text(msg).foregroundStyle(.red).font(.caption)
                }
                Button("Register") {
                    Task {
                        await auth.register(email: email, password: password, displayName: displayName.isEmpty ? nil : displayName, sourceLang: settings.sourceLang)
                        if auth.isLoggedIn { onDismiss() }
                    }
                }
                .disabled(auth.isLoading)
            }
            .navigationTitle("Register")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                if let msg = auth.errorMessage {
                    Text(msg).foregroundStyle(.red).font(.caption)
                }
                Button("Log in") {
                    Task {
                        await auth.login(email: email, password: password)
                        if auth.isLoggedIn { onDismiss() }
                    }
                }
                .disabled(auth.isLoading)
                NavigationLink(String(localized: "Forgot password?")) {
                    ForgotPasswordView()
                }
                .font(.footnote)
            }
            .navigationTitle("Log in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}

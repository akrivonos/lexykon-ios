import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var infoMessage: String?
    @State private var localError: String?

    var body: some View {
        Form {
            Text(String(localized: "Enter your account email. We will send a reset link."))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(String(localized: "Email"), text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            if let localError {
                Text(localError).foregroundStyle(.red).font(.caption)
            }
            if let infoMessage {
                Text(infoMessage).foregroundStyle(.green).font(.caption)
            }
            Button(String(localized: "Send reset link")) {
                Task {
                    localError = nil
                    infoMessage = nil
                    let err = await auth.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                    if let err {
                        localError = err
                    } else {
                        infoMessage = String(localized: "If an account exists, you will receive an email shortly.")
                    }
                }
            }
            .disabled(auth.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle(String(localized: "Forgot password"))
    }
}

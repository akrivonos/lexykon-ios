import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var appEnv: AppEnvironment
    let initialToken: String
    @State private var token: String
    @State private var password = ""
    @State private var password2 = ""
    @State private var error: String?
    @State private var success = false

    init(initialToken: String) {
        self.initialToken = initialToken
        _token = State(initialValue: initialToken)
    }

    var body: some View {
        Form {
            Section(String(localized: "Reset token")) {
                TextField(String(localized: "Token from email"), text: $token)
                    .autocapitalization(.none)
            }
            Section(String(localized: "New password")) {
                SecureField(String(localized: "Password"), text: $password)
                SecureField(String(localized: "Confirm password"), text: $password2)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if success {
                Text(String(localized: "Password updated. You can log in."))
                    .foregroundStyle(.green)
            }
            Button(String(localized: "Set password")) {
                Task {
                    error = nil
                    guard password.count >= 8 else {
                        error = String(localized: "Password must be at least 8 characters.")
                        return
                    }
                    guard password == password2 else {
                        error = String(localized: "Passwords do not match.")
                        return
                    }
                    let err = await auth.resetPassword(token: token.trimmingCharacters(in: .whitespacesAndNewlines), newPassword: password)
                    if let err {
                        error = err
                    } else {
                        success = true
                        appEnv.pendingResetPasswordToken = nil
                    }
                }
            }
            .disabled(auth.isLoading)
        }
        .navigationTitle(String(localized: "Reset password"))
    }
}

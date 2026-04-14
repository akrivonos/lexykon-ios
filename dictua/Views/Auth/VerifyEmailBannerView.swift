import SwiftUI

struct VerifyEmailBannerView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Please verify your email address."))
                .font(.subheadline)
                .fontWeight(.semibold)
            Button(String(localized: "Resend verification email")) {
                Task {
                    error = nil
                    message = nil
                    let err = await auth.resendVerification()
                    if let err {
                        error = err
                    } else {
                        message = String(localized: "Check your inbox.")
                    }
                }
            }
            .disabled(auth.isLoading)
            if let message {
                Text(message).font(.caption).foregroundStyle(Color.green)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(Color.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
    }
}

struct VerifyEmailFromTokenView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var appEnv: AppEnvironment
    let token: String
    @State private var error: String?
    @State private var done = false

    var body: some View {
        Form {
            if done {
                Text(String(localized: "Email verified successfully."))
                    .foregroundStyle(Color.green)
            } else if let error {
                Text(error).foregroundStyle(Color.red)
            } else {
                ProgressView()
                    .onAppear {
                        Task {
                            let err = await auth.verifyEmail(token: token)
                            if let err {
                                error = err
                            } else {
                                done = true
                                appEnv.pendingVerifyEmailToken = nil
                            }
                        }
                    }
            }
        }
        .navigationTitle(String(localized: "Verify email"))
    }
}

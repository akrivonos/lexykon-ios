import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Dictua")
                    .font(.largeTitle)
                Text("Ukrainian Dictionary")
                    .foregroundStyle(.secondary)
                Button("Log in") {
                    showLogin = true
                }
                .buttonStyle(.borderedProminent)
                Button("Register") {
                    showRegister = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .sheet(isPresented: $showLogin) {
                LoginView(onDismiss: { showLogin = false })
            }
            .sheet(isPresented: $showRegister) {
                RegisterView(onDismiss: { showRegister = false })
            }
        }
    }
}

import SwiftUI
import AuthenticationServices

struct GuestProfileView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var showDevLogin = false
    @State private var devEmail = "oawu.tw@gmail.com"

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo + App 名稱
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)

                Text("Life")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("記錄你的生活")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 按鈕區
            VStack(spacing: 12) {
                if authManager.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task {
                                await authManager.handleAppleSignIn(authorization: authorization)
                            }
                        case .failure(let error):
                            if (error as? ASAuthorizationError)?.code != .canceled {
                                authManager.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)

                    #if LOCAL
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDevLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "hammer.fill")
                            Text("開發者登入")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AID.btnDevLogin)
                    #endif
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .alert("登入失敗", isPresented: .init(
            get: { authManager.errorMessage != nil },
            set: { if !$0 { authManager.errorMessage = nil } }
        )) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(authManager.errorMessage ?? "")
        }
        #if LOCAL
        .alert("開發者登入", isPresented: $showDevLogin) {
            TextField("Email", text: $devEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button("登入") {
                Task {
                    await authManager.devLogin(email: devEmail)
                }
            }
            Button("取消", role: .cancel) {
                devEmail = ""
            }
        } message: {
            Text("輸入 Email 模擬登入")
        }
        #endif
    }
}

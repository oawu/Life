import Foundation
import UIKit
import AuthenticationServices

struct UserInfo: Codable {
    let id: Int
    let email: String
    var name: String
    let avatar: String?
    let status: String
    var carrierNumber: String?
}

struct AuthResponse: Decodable {
    let token: String
    let user: UserInfo
}

struct MeResponse: Decodable {
    let user: UserInfo
}

enum AuthState: Equatable {
    case launching
    case guest
    case authenticated
}

@Observable
final class AuthManager {
    var authState: AuthState = .launching
    var currentUser: UserInfo?
    var isLoading = false
    var errorMessage: String?
    var avatarImage: UIImage?
    var carrierNumber: String = ""

    var isAuthenticated: Bool { authState == .authenticated }
    var isGuest: Bool { authState == .guest }

    init() {
        checkExistingToken()
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = "無法取得 Apple 憑證"
            return
        }

        // 組合 fullName
        var fullName: String?
        if let givenName = credential.fullName?.givenName,
           let familyName = credential.fullName?.familyName {
            fullName = familyName + givenName
        } else if let givenName = credential.fullName?.givenName {
            fullName = givenName
        } else if let familyName = credential.fullName?.familyName {
            fullName = familyName
        }

        await authenticate(identityToken: identityToken, fullName: fullName, isDev: false)
    }

    // MARK: - Dev Login

    func devLogin(email: String) async {
        await authenticate(identityToken: email, fullName: nil, isDev: true)
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainService.shared.deleteToken()
        authState = .guest
        currentUser = nil
        avatarImage = nil
        carrierNumber = ""
    }

    // MARK: - Update

    func updateName(_ name: String) {
        currentUser?.name = name
        Task {
            try? await APIClient.shared.put(
                path: "/api/auth/me",
                body: ["name": name],
                responseType: MeResponse.self
            )
        }
    }

    func updateCarrierNumber(_ number: String) {
        carrierNumber = number
        currentUser?.carrierNumber = number
        Task {
            try? await APIClient.shared.put(
                path: "/api/auth/me",
                body: ["carrierNumber": number],
                responseType: MeResponse.self
            )
        }
    }

    // MARK: - Private

    private func checkExistingToken() {
        guard KeychainService.shared.getToken() != nil else {
            authState = .guest
            return
        }

        Task {
            do {
                let response = try await APIClient.shared.get(
                    path: "/api/auth/me",
                    responseType: MeResponse.self
                )
                await MainActor.run {
                    self.currentUser = response.user
                    self.carrierNumber = response.user.carrierNumber ?? ""
                    self.authState = .authenticated
                }
            } catch {
                // token 無效，清除
                KeychainService.shared.deleteToken()
                await MainActor.run {
                    self.authState = .guest
                }
            }
        }
    }

    private func authenticate(identityToken: String, fullName: String?, isDev: Bool) async {
        isLoading = true
        errorMessage = nil

        do {
            var body: [String: Any] = ["identityToken": identityToken]

            if let fullName = fullName {
                body["fullName"] = fullName
            }

            if isDev {
                body["isDev"] = true
            }

            let response = try await APIClient.shared.post(
                path: "/api/auth/apple/callback",
                body: body,
                responseType: AuthResponse.self
            )

            _ = KeychainService.shared.saveToken(response.token)

            await MainActor.run {
                self.currentUser = response.user
                self.authState = .authenticated
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }
}

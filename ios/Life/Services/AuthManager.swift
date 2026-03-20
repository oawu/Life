import Foundation
import AuthenticationServices

struct UserInfo: Codable {
  let id: Int
  let email: String
  let name: String
  let avatar: String?
  let status: String
}

struct AuthResponse: Decodable {
  let token: String
  let user: UserInfo
}

struct MeResponse: Decodable {
  let user: UserInfo
}

@Observable
final class AuthManager {
  var isAuthenticated = false
  var currentUser: UserInfo?
  var isLoading = false
  var errorMessage: String?

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
    isAuthenticated = false
    currentUser = nil
  }

  // MARK: - Private

  private func checkExistingToken() {
    guard KeychainService.shared.getToken() != nil else {
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
          self.isAuthenticated = true
        }
      } catch {
        // token 無效，清除
        KeychainService.shared.deleteToken()
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
        self.isAuthenticated = true
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

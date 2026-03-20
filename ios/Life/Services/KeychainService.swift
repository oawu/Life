import Foundation
import Security

final class KeychainService {
  static let shared = KeychainService()

  private let tokenKey = "tw.iwi.life.auth.token"

  private init() {}

  func saveToken(_ token: String) -> Bool {
    guard let data = token.data(using: .utf8) else {
      return false
    }

    // 先刪除舊的
    deleteToken()

    let query: [String: Any] = [
      kSecClass as String:       kSecClassGenericPassword,
      kSecAttrAccount as String: tokenKey,
      kSecValueData as String:   data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  func getToken() -> String? {
    let query: [String: Any] = [
      kSecClass as String:            kSecClassGenericPassword,
      kSecAttrAccount as String:      tokenKey,
      kSecReturnData as String:       true,
      kSecMatchLimit as String:       kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let token = String(data: data, encoding: .utf8) else {
      return nil
    }

    return token
  }

  @discardableResult
  func deleteToken() -> Bool {
    let query: [String: Any] = [
      kSecClass as String:       kSecClassGenericPassword,
      kSecAttrAccount as String: tokenKey,
    ]

    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }
}

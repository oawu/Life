import Foundation

enum Environment {
  static var apiBaseURL: String {
    #if LOCAL
    return "http://localhost:7200"
    #elseif BETA
    return "https://beta.iwi.tw"
    #else
    return "https://iwi.tw"
    #endif
  }

  static var isLocal: Bool {
    #if LOCAL
    return true
    #else
    return false
    #endif
  }

  static var isBeta: Bool {
    #if BETA
    return true
    #else
    return false
    #endif
  }

  static var isProd: Bool {
    #if PROD
    return true
    #else
    return false
    #endif
  }
}

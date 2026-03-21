import Foundation

enum AppEnvironment {
    static var apiBaseURL: String {
        #if LOCAL
        return "http://local-api-life.iwi.tw"
        #elseif BETA
        return "https://beta-api-life.iwi.tw"
        #else
        return "https://api-life.iwi.tw"
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

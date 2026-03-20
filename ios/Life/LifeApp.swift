import SwiftUI

@main
struct LifeApp: App {
  @State private var authManager = AuthManager()

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          HomeView(authManager: authManager)
        } else {
          LoginView(authManager: authManager)
        }
      }
    }
  }
}

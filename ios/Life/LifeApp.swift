import SwiftUI

@main
struct LifeApp: App {
    @State private var authManager = AuthManager()
    @State private var expenseStore = ExpenseStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    HomeView(authManager: authManager, expenseStore: expenseStore)
                } else {
                    LoginView(authManager: authManager)
                }
            }
        }
    }
}

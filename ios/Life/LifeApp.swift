import SwiftUI

@main
struct LifeApp: App {
    @State private var authManager = AuthManager()
    @State private var expenseStore = ExpenseStore()
    @State private var phoneSessionManager: PhoneSessionManager?

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    HomeView(authManager: authManager, expenseStore: expenseStore)
                } else {
                    LoginView(authManager: authManager)
                }
            }
            .onAppear {
                if phoneSessionManager == nil {
                    phoneSessionManager = PhoneSessionManager(expenseStore: expenseStore)
                }
            }
            .onChange(of: expenseStore.ledgers) {
                phoneSessionManager?.syncLedgersToWatch()
            }
        }
    }
}

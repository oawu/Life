import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @Bindable var expenseStore: ExpenseStore

    var body: some View {
        TabView {
            NavigationStack {
                AddExpenseView(store: expenseStore)
            }
            .tabItem {
                Label("記帳", systemImage: "yensign.circle.fill")
            }
            .accessibilityIdentifier(AID.tabExpense)

            NavigationStack {
                if authManager.isAuthenticated {
                    ProfileView()
                } else {
                    GuestProfileView()
                }
            }
            .tabItem {
                Label("個人", systemImage: "person.fill")
            }
            .accessibilityIdentifier(AID.tabProfile)
        }
    }
}

#Preview {
    HomeView(expenseStore: ExpenseStore.preview())
        .environment(AuthManager())
}

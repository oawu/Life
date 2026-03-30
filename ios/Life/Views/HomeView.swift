import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @Bindable var expenseStore: ExpenseStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AddExpenseView(store: expenseStore)
            }
            .tag(0)
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
            .tag(1)
            .tabItem {
                Label("個人", systemImage: "person.fill")
            }
            .accessibilityIdentifier(AID.tabProfile)
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                selectedTab = 0
            }
        }
    }
}

#Preview {
    HomeView(expenseStore: ExpenseStore.preview())
        .environment(AuthManager())
}

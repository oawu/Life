import SwiftUI

struct HomeView: View {
  var authManager: AuthManager
  @Bindable var expenseStore: ExpenseStore

  var body: some View {
    TabView {
      NavigationStack {
        AddExpenseView(store: expenseStore)
      }
      .tabItem {
        Label("記帳", systemImage: "yensign.circle.fill")
      }

      NavigationStack {
        ProfileView(authManager: authManager)
      }
      .tabItem {
        Label("個人", systemImage: "person.fill")
      }
    }
  }
}

#Preview {
  HomeView(authManager: AuthManager(), expenseStore: ExpenseStore())
}

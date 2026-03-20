import SwiftUI

struct HomeView: View {
  var authManager: AuthManager
  @Bindable var expenseStore: ExpenseStore

  var body: some View {
    TabView {
      NavigationStack {
        ExpenseListView(store: expenseStore)
      }
      .tabItem {
        Label("開銷", systemImage: "yensign.circle.fill")
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

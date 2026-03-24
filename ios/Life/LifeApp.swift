import SwiftUI
import SwiftData

@main
struct LifeApp: App {
    @State private var authManager = AuthManager()
    @State private var dataManager: DataManager
    @State private var expenseStore: ExpenseStore
    @State private var phoneSessionManager: PhoneSessionManager?

    init() {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, migrationPlan: LifeMigrationPlan.self, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let manager = DataManager(modelContainer: container)
        _dataManager = State(initialValue: manager)
        _expenseStore = State(initialValue: ExpenseStore(dataManager: manager))
    }

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

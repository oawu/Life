import SwiftUI
import SwiftData

@main
struct LifeApp: App {
    @State private var authManager: AuthManager
    @State private var networkMonitor: NetworkMonitor
    @State private var dataManager: DataManager
    @State private var expenseStore: ExpenseStore
    @State private var phoneSessionManager: PhoneSessionManager?
    @Environment(\.scenePhase) private var scenePhase

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
        let auth = AuthManager()
        let network = NetworkMonitor()
        _authManager = State(initialValue: auth)
        _networkMonitor = State(initialValue: network)
        _dataManager = State(initialValue: manager)
        _expenseStore = State(initialValue: ExpenseStore(dataManager: manager, authManager: auth, networkMonitor: network))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.authState {
                case .launching:
                    LaunchView()
                case .guest, .authenticated:
                    HomeView(expenseStore: expenseStore)
                }
            }
            .environment(authManager)
            .environment(networkMonitor)
            .onChange(of: authManager.authState) { oldState, newState in
                handleAuthStateChange(from: oldState, to: newState)
            }
            .onChange(of: networkMonitor.isOnline) {
                phoneSessionManager?.isOnline = networkMonitor.isOnline
                phoneSessionManager?.syncLedgersToWatch()
                // 網路恢復時同步離線開銷 + 重整快取
                if networkMonitor.isOnline && authManager.isAuthenticated {
                    Task {
                        await expenseStore.syncOfflineExpenses()
                        await expenseStore.refreshState()
                    }
                }
            }
            .onAppear {
                if phoneSessionManager == nil {
                    phoneSessionManager = PhoneSessionManager(expenseStore: expenseStore)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && authManager.isAuthenticated {
                    Task {
                        await expenseStore.syncOfflineExpenses()
                        await expenseStore.refreshState()
                    }
                }
            }
            .onChange(of: expenseStore.ledgers) {
                phoneSessionManager?.syncLedgersToWatch()
            }
        }
    }

    // MARK: - Private

    private func handleAuthStateChange(from oldState: AuthState, to newState: AuthState) {
        switch (oldState, newState) {
        case (.authenticated, .guest):
            // 登出：清除快取
            dataManager.clearAllCache()
            expenseStore.reload()
            expenseStore.currentLedgerId = expenseStore.ledgers.first?.id ?? ""
            phoneSessionManager?.isLoggedIn = false
            phoneSessionManager?.syncLedgersToWatch()

        case (.guest, .authenticated), (.launching, .authenticated):
            // 登入：上傳 guest 開銷 + 建立快取
            phoneSessionManager?.isLoggedIn = true
            let guestExpenses = dataManager.fetchGuestExpenses()
            Task {
                await expenseStore.initAfterLogin(guestExpenses: guestExpenses)
                phoneSessionManager?.syncLedgersToWatch()
            }

        default:
            break
        }
    }
}

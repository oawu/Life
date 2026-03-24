import SwiftUI
import SwiftData

@main
struct LifeApp: App {
    @State private var authManager = AuthManager()
    @State private var networkMonitor = NetworkMonitor()
    @State private var dataManager: DataManager
    @State private var expenseStore: ExpenseStore
    @State private var syncEngine: SyncEngine?
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
        _dataManager = State(initialValue: manager)
        _expenseStore = State(initialValue: ExpenseStore(dataManager: manager))
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
                // 網路恢復時自動同步
                if networkMonitor.isOnline && authManager.isAuthenticated {
                    Task {
                        await syncEngine?.fullSync()
                        expenseStore.reload()
                    }
                }
            }
            .onAppear {
                if phoneSessionManager == nil {
                    phoneSessionManager = PhoneSessionManager(expenseStore: expenseStore)
                }
                if syncEngine == nil {
                    syncEngine = SyncEngine(dataManager: dataManager, networkMonitor: networkMonitor)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && authManager.isAuthenticated {
                    Task {
                        await syncEngine?.fullSync()
                        expenseStore.reload()
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
            // 登出：重設資料
            syncEngine?.lastSyncAt = nil
            dataManager.resetToDefaults()
            expenseStore.reload()
            expenseStore.currentLedgerId = expenseStore.ledgers.first?.id ?? ""
            phoneSessionManager?.isLoggedIn = false
            phoneSessionManager?.syncLedgersToWatch()

        case (.guest, .authenticated):
            // 登入：同步本地資料到 Server
            phoneSessionManager?.isLoggedIn = true
            Task {
                await syncEngine?.fullSync()
                expenseStore.reload()
                phoneSessionManager?.syncLedgersToWatch()
            }

        default:
            break
        }
    }
}

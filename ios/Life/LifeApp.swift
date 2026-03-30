import SwiftUI
import SwiftData

@main
struct LifeApp: App {
    @State private var authManager: AuthManager
    @State private var networkMonitor: NetworkMonitor
    @State private var dataManager: DataManager
    @State private var expenseStore: ExpenseStore
    @State private var phoneSessionManager: PhoneSessionManager?
    @State private var pendingGuestExpenses: [GuestExpense] = []
    @State private var showSyncAlert = false
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

        #if DEBUG
        if CommandLine.arguments.contains("--reset-local-data") {
            manager.clearAllGuestData()
            manager.clearAllCache()
        }
        #endif

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
                print("[LifeApp] authState changed: \(oldState) → \(newState)")
                handleAuthStateChange(from: oldState, to: newState)
            }
            .onChange(of: networkMonitor.isOnline) {
                print("[LifeApp] network changed: isOnline=\(networkMonitor.isOnline)")
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
                    print("[LifeApp] scenePhase: active, triggering sync + refresh")
                    Task {
                        await expenseStore.syncOfflineExpenses()
                        await expenseStore.refreshState()
                    }
                }
            }
            .onChange(of: expenseStore.ledgers) {
                phoneSessionManager?.syncLedgersToWatch()
            }
            .alert("同步資料", isPresented: $showSyncAlert) {
                Button("捨棄") {
                    pendingGuestExpenses = []
                    Task {
                        await expenseStore.initAfterLogin(guestExpenses: [])
                        phoneSessionManager?.syncLedgersToWatch()
                    }
                }
                Button("上傳") {
                    let expenses = pendingGuestExpenses
                    pendingGuestExpenses = []
                    Task {
                        await expenseStore.initAfterLogin(guestExpenses: expenses)
                        phoneSessionManager?.syncLedgersToWatch()
                    }
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("你有 \(pendingGuestExpenses.count) 筆記帳紀錄尚未同步，要上傳到雲端嗎？")
            }
            #if DEBUG
            .overlay {
                DebugOverlayView()
                    .environment(authManager)
                    .environment(networkMonitor)
            }
            #endif
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
            print("[LifeApp] initAfterLogin started, guestExpenses=\(guestExpenses.count)")

            if guestExpenses.isEmpty {
                Task {
                    await expenseStore.initAfterLogin(guestExpenses: [])
                    phoneSessionManager?.syncLedgersToWatch()
                }
            } else {
                pendingGuestExpenses = guestExpenses
                showSyncAlert = true
            }

        default:
            break
        }
    }
}

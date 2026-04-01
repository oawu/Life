import SwiftUI

@main
struct LifeWatchApp: App {
    @State private var store = WatchExpenseStore()
    @State private var locationService = WatchLocationService()
    @State private var sessionManager: WatchSessionManager?

    var body: some Scene {
        WindowGroup {
            Group {
                if store.token != nil {
                    WatchAddExpenseView(
                        store: store,
                        locationService: locationService
                    )
                } else {
                    WatchLoginRequiredView()
                }
            }
            .onAppear {
                if sessionManager == nil {
                    sessionManager = WatchSessionManager(store: store)
                }
            }
            .task {
                if store.token != nil {
                    locationService.requestLocation()
                    await store.flushPendingExpenses()
                    await store.fetchLedgers()
                }
            }
            .onChange(of: store.token) { _, newToken in
                if newToken != nil {
                    locationService.requestLocation()
                    Task {
                        await store.flushPendingExpenses()
                        await store.fetchLedgers()
                    }
                }
            }
        }
    }
}

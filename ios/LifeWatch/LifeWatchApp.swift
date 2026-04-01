import SwiftUI

@main
struct LifeWatchApp: App {
    @State private var store = WatchExpenseStore()
    @State private var locationService = WatchLocationService()
    @State private var sessionManager: WatchSessionManager?

    var body: some Scene {
        WindowGroup {
            WatchAddExpenseView(
                store: store,
                locationService: locationService,
                sessionManager: sessionManager
            )
            .onAppear {
                locationService.requestLocation()
                if sessionManager == nil {
                    sessionManager = WatchSessionManager(store: store)
                }
            }
        }
    }
}

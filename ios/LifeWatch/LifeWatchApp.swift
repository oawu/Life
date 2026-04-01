import SwiftUI

@main
struct LifeWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = WatchExpenseStore()
    @State private var locationService = WatchLocationService()
    @State private var sessionManager: WatchSessionManager?
    @State private var isReady = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if store.token != nil {
                    WatchAddExpenseView(
                        store: store,
                        locationService: locationService
                    )
                } else if isReady {
                    WatchLoginRequiredView()
                }

                if !isReady {
                    WatchLaunchView()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.4), value: isReady)
            .onAppear {
                if sessionManager == nil {
                    sessionManager = WatchSessionManager(store: store)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isReady = true
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, store.token != nil {
                    Task {
                        await store.flushPendingExpenses()
                        await store.fetchLedgers()
                    }
                }
            }
        }
    }
}

struct WatchLaunchView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.pink)
                Text("Life")
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }
}

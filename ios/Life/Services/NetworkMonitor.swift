import Network
import Observation

@Observable
final class NetworkMonitor {
    #if DEBUG
    /// 強制模擬離線（NWPathMonitor 報告無網路）
    var forceOffline: Bool = false
    #endif

    var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let realOnline = path.status == .satisfied
                #if DEBUG
                self.isOnline = self.forceOffline ? false : realOnline
                #else
                self.isOnline = realOnline
                #endif
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

import Network
import Observation

@Observable
final class NetworkMonitor {
    #if DEBUG
    /// 強制模擬離線（NWPathMonitor 報告無網路）
    var forceOffline: Bool = false
    #endif

    var isOnline: Bool = true

    #if DEBUG
    /// 上次 NWPathMonitor 回報的真實網路狀態
    private(set) var realOnline: Bool = true
    #endif

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let pathOnline = path.status == .satisfied
                #if DEBUG
                self.realOnline = pathOnline
                self.isOnline = self.forceOffline ? false : pathOnline
                #else
                self.isOnline = pathOnline
                #endif
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

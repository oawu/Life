import SwiftUI
import WatchKit

struct WatchLedgerPickerView: View {
    let ledgers: [Ledger]
    var isOnline: Bool = true
    var isReachable: Bool = false
    var hasSynced: Bool = false
    var isLoggedIn: Bool = false
    var pendingCount: Int = 0
    let selectedId: String
    let onSelect: (Ledger) -> Void

    var body: some View {
        List {
            ForEach(ledgers) { ledger in
                Button {
                    WKInterfaceDevice.current().play(.click)
                    onSelect(ledger)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ledger.name)
                            if ledger.type == .group {
                                Text("\(ledger.members.count) 人")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selectedId == ledger.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            if pendingCount > 0 {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                    Text("待同步 \(pendingCount) 筆")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
                .listRowBackground(Color.clear)
            }

            if !isOnline {
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("離線中")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
            }

            #if DEBUG
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    debugRow("iPhone", isReachable ? "connected" : "disconnected", isReachable ? .green : .red)
                    debugRow("Synced", hasSynced ? "yes" : "no", hasSynced ? .green : .orange)
                    debugRow("Login", isLoggedIn ? "yes" : "no", isLoggedIn ? .green : .secondary)
                    debugRow("Ledgers", "\(ledgers.count)", .secondary)
                    debugRow("Pending", "\(pendingCount)", pendingCount > 0 ? .orange : .secondary)
                }
            } header: {
                Text("Debug")
            }
            #endif
        }
        .navigationTitle("帳本")
    }

    #if DEBUG
    private func debugRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
    }
    #endif
}

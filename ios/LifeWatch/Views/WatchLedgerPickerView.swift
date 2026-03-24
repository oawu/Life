import SwiftUI
import WatchKit

struct WatchLedgerPickerView: View {
    let ledgers: [Ledger]
    var isOnline: Bool = true
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
        }
        .navigationTitle("帳本")
    }
}

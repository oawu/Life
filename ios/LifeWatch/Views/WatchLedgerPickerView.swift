import SwiftUI
import WatchKit

struct WatchLedgerPickerView: View {
    let ledgers: [Ledger]
    let selectedId: String
    let onSelect: (Ledger) -> Void

    var body: some View {
        List(ledgers) { ledger in
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
        .navigationTitle("帳本")
    }
}

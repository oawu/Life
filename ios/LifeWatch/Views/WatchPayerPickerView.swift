import SwiftUI
import WatchKit

struct WatchPayerPickerView: View {
    let members: [LedgerMember]
    @Binding var selected: LedgerMember?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(members) { member in
            Button {
                WKInterfaceDevice.current().play(.click)
                selected = member
                dismiss()
            } label: {
                HStack {
                    Text(member.name)
                    Spacer()
                    if selected?.id == member.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("付款人")
    }
}

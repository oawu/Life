import SwiftUI

struct LedgerSwitcher: View {
    let ledgers: [Ledger]
    @Binding var selectedId: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ledgers) { ledger in
                    let isSelected = ledger.id == selectedId

                    Button {
                        guard ledger.id != selectedId else {
                            return
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedId = ledger.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: ledger.icon)
                                .font(.system(size: 12))

                            Text(ledger.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

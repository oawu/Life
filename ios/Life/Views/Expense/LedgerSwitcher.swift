import SwiftUI

struct LedgerSwitcher: View {
    let ledgers: [Ledger]
    @Binding var selectedId: String
    var onSettingsTapped: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
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
                            Text(ledger.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
            }

            if let onSettingsTapped {
                Divider()
                    .frame(height: 20)
                    .padding(.leading, 4)

                Button {
                    onSettingsTapped()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
        }
    }
}

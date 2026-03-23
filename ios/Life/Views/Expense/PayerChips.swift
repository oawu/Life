import SwiftUI

struct PayerChips: View {
    let members: [LedgerMember]
    @Binding var selected: LedgerMember?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("付款人")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(members) { member in
                        let isSelected = member.id == selected?.id

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selected = member
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))

                                Text(member.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.blue.opacity(0.12) : Color(.tertiarySystemFill))
                            .foregroundStyle(isSelected ? .blue : .primary)
                            .overlay {
                                if isSelected {
                                    Capsule()
                                        .strokeBorder(Color.blue, lineWidth: 1.5)
                                }
                            }
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

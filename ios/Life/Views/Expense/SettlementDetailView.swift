import SwiftUI

struct SettlementDetailView: View {
    let record: SettlementRecord

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd (E) a h:mm"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()

    private func formatted(_ amount: Double) -> String {
        Int(amount.rounded(.up)).formatted()
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("結算時間")
                    Spacer()
                    Text(Self.dateFormatter.string(from: record.date))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                HStack {
                    Text("操作者")
                    Spacer()
                    Text(record.settledBy.name)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            Section {
                if record.transfers.isEmpty {
                    Text("無轉帳明細")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(record.transfers) { transfer in
                        HStack(spacing: 10) {
                            Text(transfer.from.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)

                            Text(transfer.to.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(record.currencySymbol)\(formatted(transfer.amount))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Text("轉帳明細")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("結算紀錄")
        .navigationBarTitleDisplayMode(.inline)
    }
}

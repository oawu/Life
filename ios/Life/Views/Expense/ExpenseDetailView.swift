import SwiftUI
import MapKit

struct ExpenseDetailView: View {
    @Bindable var store: ExpenseStore
    let expenseId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    private var ledger: Ledger? {
        store.ledgers.first { $0.expenses.contains { $0.id == expenseId } }
    }

    private var expense: Expense? {
        ledger?.expenses.first { $0.id == expenseId }
    }

    private var currencySymbol: String {
        ledger?.currency.symbol ?? "$"
    }

    private var isGroup: Bool {
        ledger?.type == .group
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd (E) a h:mm"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()

    var body: some View {
        Group {
            if let expense {
                List {
                    amountSection(expense)
                    detailSection(expense)

                    if expense.latitude != nil && expense.longitude != nil {
                        locationSection(expense)
                    }

                    deleteSection
                }
                .listStyle(.insetGrouped)
                .sheet(isPresented: $showEditSheet) {
                    if let ledger {
                        ExpenseEditView(expense: expense, ledger: ledger, store: store)
                    }
                }
            }
        }
        .navigationTitle("開銷詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編輯") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showEditSheet = true
                }
            }
        }
        .confirmationDialog("確定要刪除此開銷嗎？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                store.deleteExpense(id: expenseId)
                dismiss()
            }
        }
    }

    // MARK: - Amount Section

    private func amountSection(_ expense: Expense) -> some View {
        Section {
            VStack(spacing: 12) {
                Text("\(currencySymbol)\(Int(expense.amount.rounded(.up)).formatted())")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(expense.category.color.opacity(0.15))
                            .frame(width: 28, height: 28)

                        Image(systemName: expense.category.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(expense.category.color)
                    }

                    Text(expense.category.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Detail Section

    private func detailSection(_ expense: Expense) -> some View {
        Section {
            HStack {
                Text("時間")
                Spacer()
                Text(Self.dateFormatter.string(from: expense.date))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            if !expense.memo.isEmpty {
                HStack {
                    Text("備註")
                    Spacer()
                    Text(expense.memo)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            if isGroup, let payer = expense.paidBy {
                HStack {
                    Text("付款人")
                    Spacer()
                    Text(payer.name)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Location Section

    private func locationSection(_ expense: Expense) -> some View {
        Section {
            if let latitude = expense.latitude, let longitude = expense.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let placemark = MKPlacemark(coordinate: coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = expense.address ?? expense.category.name
                    mapItem.openInMaps()
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))) {
                            Marker(expense.category.name, coordinate: coordinate)
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .allowsHitTesting(false)

                        if let address = expense.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "map")
                                .font(.caption)
                            Text("在 Apple 地圖中開啟")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("位置")
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showDeleteConfirmation = true
            } label: {
                Text("刪除開銷")
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

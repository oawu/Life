import SwiftUI
import Charts

struct ExpenseChartView: View {
    @Bindable var store: ExpenseStore

    @State private var periodType: PeriodType = .month
    @State private var selectedDate = Date()

    private enum PeriodType: String, CaseIterable {
        case month = "月"
        case year = "年"
    }

    // MARK: - Data

    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        return store.expenses.filter { expense in
            switch periodType {
            case .month:
                return calendar.isDate(expense.date, equalTo: selectedDate, toGranularity: .month)
            case .year:
                return calendar.isDate(expense.date, equalTo: selectedDate, toGranularity: .year)
            }
        }
    }

    private struct CategorySlice: Identifiable {
        let id: String
        let category: ExpenseCategory
        let amount: Double
        let percentage: Double
    }

    private var categoryData: [CategorySlice] {
        let total = totalAmount
        if total == 0 {
            return []
        }

        var amountByCategory: [(category: ExpenseCategory, amount: Double)] = []
        var seen: [String: Int] = [:]

        for expense in filteredExpenses {
            if let index = seen[expense.category.id] {
                amountByCategory[index].amount += expense.amount
            } else {
                seen[expense.category.id] = amountByCategory.count
                amountByCategory.append((category: expense.category, amount: expense.amount))
            }
        }

        return amountByCategory
            .sorted { $0.amount > $1.amount }
            .map { item in
                CategorySlice(
                    id: item.category.id,
                    category: item.category,
                    amount: item.amount,
                    percentage: item.amount / total * 100
                )
            }
    }

    private var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private var currencySymbol: String {
        store.currentCurrency.symbol
    }

    private func formatted(_ amount: Double) -> String {
        Int(amount.rounded(.up)).formatted()
    }

    // MARK: - Period Navigation

    private var periodLabel: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        switch periodType {
        case .month:
            let month = calendar.component(.month, from: selectedDate)
            return "\(year)年\(month)月"
        case .year:
            return "\(year)年"
        }
    }

    private func shiftPeriod(by value: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component = periodType == .month ? .month : .year
        if let newDate = calendar.date(byAdding: component, value: value, to: selectedDate) {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedDate = newDate
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if filteredExpenses.isEmpty {
                emptyState
            } else {
                chartContent
            }
        }
        .animation(.easeInOut(duration: 0.25), value: periodType)
        .animation(.easeInOut(duration: 0.25), value: selectedDate)
        .navigationTitle("開銷統計")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: periodType) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Subviews

    private var periodNavigator: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shiftPeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }

                Spacer()

                Text(periodLabel)
                    .font(.headline)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shiftPeriod(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
            }

            Picker("期間", selection: $periodType) {
                ForEach(PeriodType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var chartContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                periodNavigator

                donutChart
                    .frame(height: 220)
                    .padding(.horizontal)

                categoryBreakdown
                    .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }

    private var donutChart: some View {
        Chart(categoryData) { slice in
            SectorMark(
                angle: .value("金額", slice.amount),
                innerRadius: .ratio(0.618),
                angularInset: 1
            )
            .foregroundStyle(slice.category.color)
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 4) {
                Text("總計")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(currencySymbol)\(formatted(totalAmount))")
                    .font(.title2.bold())
                    .monospacedDigit()
            }
        }
    }

    private var categoryBreakdown: some View {
        let maxAmount = categoryData.first?.amount ?? 1

        return VStack(spacing: 16) {
            ForEach(categoryData) { slice in
                HStack(spacing: 12) {
                    // 分類圖示
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(slice.category.color.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: slice.category.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(slice.category.color)
                    }

                    // 名稱 + 進度條 + 百分比
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(slice.category.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(currencySymbol)\(formatted(slice.amount))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(slice.category.color)
                                    .frame(width: geometry.size.width * slice.amount / maxAmount, height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text(String(format: "%.1f%%", slice.percentage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            periodNavigator

            Spacer()

            // 無資料環形圖
            Chart {
                SectorMark(
                    angle: .value("空", 1),
                    innerRadius: .ratio(0.618)
                )
                .foregroundStyle(Color(.systemGray5))
            }
            .chartLegend(.hidden)
            .frame(height: 200)
            .padding(.horizontal, 60)
            .overlay {
                Text("尚無開銷")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

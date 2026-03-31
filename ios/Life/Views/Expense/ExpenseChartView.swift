import SwiftUI
import Charts

struct ExpenseChartView: View {
    @Bindable var store: ExpenseStore

    @State private var periodType: PeriodType = .month
    @State private var showChart = true
    @State private var scrollOpacity: Double = 0

    private enum PeriodType: String, CaseIterable {
        case month = "月"
        case year = "年"
    }

    private var headerOpacity: Double {
        if #available(iOS 18, *) {
            return scrollOpacity
        }
        return 1
    }

    private var currencySymbol: String {
        store.currentCurrency.symbol
    }

    private func formatted(_ amount: Double) -> String {
        Int(amount.rounded(.up)).formatted()
    }

    // MARK: - Data

    private struct CategorySlice: Identifiable {
        let id: String
        let category: ExpenseCategory
        let amount: Double
        let percentage: Double
    }

    private struct PeriodSection: Identifiable {
        let id: String
        let label: String
        let totalAmount: Double
        let slices: [CategorySlice]
    }

    private var sections: [PeriodSection] {
        let calendar = Calendar.current
        let expenses = store.expenses

        if expenses.isEmpty {
            return []
        }

        // 依期間分組
        let grouped = Dictionary(grouping: expenses) { expense -> String in
            let year = calendar.component(.year, from: expense.date)
            switch periodType {
            case .month:
                let month = calendar.component(.month, from: expense.date)
                return String(format: "%04d-%02d", year, month)
            case .year:
                return String(format: "%04d", year)
            }
        }

        return grouped.keys.sorted(by: >).map { key in
            let periodExpenses = grouped[key]!
            let total = periodExpenses.reduce(0) { $0 + $1.amount }

            // 分類聚合
            var amountByCategory: [(category: ExpenseCategory, amount: Double)] = []
            var seen: [String: Int] = [:]

            for expense in periodExpenses {
                if let index = seen[expense.category.id] {
                    amountByCategory[index].amount += expense.amount
                } else {
                    seen[expense.category.id] = amountByCategory.count
                    amountByCategory.append((category: expense.category, amount: expense.amount))
                }
            }

            let slices = amountByCategory
                .sorted { $0.amount > $1.amount }
                .map { item in
                    CategorySlice(
                        id: "\(key)-\(item.category.id)",
                        category: item.category,
                        amount: item.amount,
                        percentage: item.amount / total * 100
                    )
                }

            // 標籤
            let label: String
            switch periodType {
            case .month:
                let parts = key.split(separator: "-")
                let year = String(parts[0])
                let month = Int(parts[1]) ?? 0
                label = "\(year)年\(month)月"
            case .year:
                label = "\(key)年"
            }

            return PeriodSection(id: key, label: label, totalAmount: total, slices: slices)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if store.expenses.isEmpty {
                emptyState
            } else {
                chartList
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { headerBar }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("開銷統計")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showChart.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 11))
                        Text("圖表")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(showChart ? .white : .secondary)
                    .background {
                        Capsule()
                            .fill(showChart ? Color.accentColor : Color.clear)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(showChart ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    }
                }
            }
        }
        .onChange(of: periodType) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var headerBar: some View {
        VStack(spacing: 0) {
            Picker("期間", selection: $periodType) {
                ForEach(PeriodType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .padding(.vertical, 8)

            Divider()
                .opacity(headerOpacity)
        }
        .background {
            Rectangle()
                .fill(.bar)
                .opacity(headerOpacity)
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Subviews

    private var chartList: some View {
        List {
            ForEach(sections) { section in
                sectionView(section)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await store.refreshState()
        }
        .scrollHeaderOpacity($scrollOpacity)
    }

    @ViewBuilder
    private func sectionView(_ section: PeriodSection) -> some View {
        let maxAmount = section.slices.first?.amount ?? 1

        Section {
            if showChart {
                donutChart(slices: section.slices, total: section.totalAmount)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
            }

            ForEach(section.slices) { slice in
                categoryRow(slice: slice, maxAmount: maxAmount)
            }
        } header: {
            Text(section.label)
        }
    }

    private func donutChart(slices: [CategorySlice], total: Double) -> some View {
        Chart(slices) { slice in
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
                Text("\(currencySymbol)\(formatted(total))")
                    .font(.title2.bold())
                    .monospacedDigit()
            }
        }
    }

    private func categoryRow(slice: CategorySlice, maxAmount: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(slice.category.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: slice.category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(slice.category.color)
            }

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
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer()
                    .frame(height: 200)

                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)

                Text("尚無開銷紀錄")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await store.refreshState()
        }
    }
}

// MARK: - Scroll Header Opacity

private extension View {
    @ViewBuilder
    func scrollHeaderOpacity(_ opacity: Binding<Double>) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: Double.self) { geo in
                let offset = geo.contentOffset.y + geo.contentInsets.top
                return min(max(offset / 40, 0), 1)
            } action: { _, newValue in
                opacity.wrappedValue = newValue
            }
        } else {
            self
        }
    }
}

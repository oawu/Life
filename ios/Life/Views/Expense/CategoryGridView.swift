import SwiftUI

struct CategoryGridView: View {
  let categories: [ExpenseCategory]
  @Binding var selected: ExpenseCategory?
  var onSettingsTapped: () -> Void = {}

  @State private var currentPage: Int? = 0

  private let columnsPerPage = 4
  private let rowsPerPage = 2
  private var itemsPerPage: Int { columnsPerPage * rowsPerPage }
  private var pageCount: Int { (categories.count + itemsPerPage - 1) / itemsPerPage }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("分類")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Spacer()

        Button("設定") {
          onSettingsTapped()
        }
          .font(.subheadline)
      }
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 0) {
          ForEach(0..<pageCount, id: \.self) { pageIndex in
            categoryGrid(for: pageIndex)
              .containerRelativeFrame(.horizontal)
          }
        }
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $currentPage)
      .padding(.top, 10)

      if pageCount > 1 {
        HStack(spacing: 6) {
          ForEach(0..<pageCount, id: \.self) { index in
            Circle()
              .fill(index == (currentPage ?? 0) ? Color(.secondaryLabel) : Color(.quaternaryLabel))
              .frame(width: 7, height: 7)
          }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
      }
    }
  }

  @ViewBuilder
  private func categoryGrid(for pageIndex: Int) -> some View {
    let start = pageIndex * itemsPerPage
    let end = min(start + itemsPerPage, categories.count)
    let pageCategories = Array(categories[start..<end])

    let placeholderCount = itemsPerPage - pageCategories.count

    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columnsPerPage),
      spacing: 8
    ) {
      ForEach(pageCategories) { category in
        CategoryCell(category: category, isSelected: selected?.id == category.id)
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
              selected = category
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
          }
      }

      ForEach(0..<placeholderCount, id: \.self) { _ in
        VStack(spacing: 0) {
          Image(systemName: "questionmark")
            .font(.system(size: 20))
            .foregroundStyle(Color(.quaternaryLabel))
            .frame(width: 44, height: 44)

          Text(" ").font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(Color(.quaternaryLabel))
        )
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 2)
  }
}

// MARK: - Category Cell

private struct CategoryCell: View {
  let category: ExpenseCategory
  let isSelected: Bool

  var body: some View {
    VStack(spacing: 0) {
      Image(systemName: category.icon)
        .font(.system(size: 24))
        .foregroundStyle(category.color)
        .frame(width: 44, height: 44)

      Text(category.name)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.secondarySystemGroupedBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
    )
  }
}

#Preview {
  CategoryGridView(
    categories: ExpenseCategory.defaults,
    selected: .constant(ExpenseCategory.defaults[1])
  )
}

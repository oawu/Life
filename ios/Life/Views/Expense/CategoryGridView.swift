import SwiftUI

struct CategoryGridView: View {
  let categories: [ExpenseCategory]
  @Binding var selected: ExpenseCategory?

  private let columnsPerPage = 4
  private let rowsPerPage = 2
  private var itemsPerPage: Int { columnsPerPage * rowsPerPage }

  private var pages: [[ExpenseCategory]] {
    stride(from: 0, to: categories.count, by: itemsPerPage).map {
      Array(categories[$0..<min($0 + itemsPerPage, categories.count)])
    }
  }

  var body: some View {
    VStack(spacing: 8) {
      TabView {
        ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columnsPerPage),
            spacing: 8
          ) {
            ForEach(page) { category in
              CategoryCell(category: category, isSelected: selected?.id == category.id)
                .onTapGesture {
                  withAnimation(.easeInOut(duration: 0.15)) {
                    selected = category
                  }
                  UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
          }
          .padding(.horizontal, 16)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .always))
      .frame(height: 200)
    }
  }
}

// MARK: - Category Cell

private struct CategoryCell: View {
  let category: ExpenseCategory
  let isSelected: Bool

  var body: some View {
    VStack(spacing: 6) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(category.color.opacity(0.15))
          .frame(width: 44, height: 44)

        Image(systemName: category.icon)
          .font(.system(size: 20))
          .foregroundStyle(category.color)
      }

      Text(category.name)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.secondarySystemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
    )
  }
}

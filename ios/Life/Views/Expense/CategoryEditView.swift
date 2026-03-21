import SwiftUI

struct CategoryEditView: View {
  enum Mode {
    case add
    case edit(ExpenseCategory)
  }

  let mode: Mode
  let onSave: (ExpenseCategory) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var name: String = ""
  @State private var selectedIcon: String = "fork.knife"
  @State private var selectedColor: Color = .blue

  private static let colorOptions: [(Color, String)] = [
    (.red, "red"), (.orange, "orange"), (.yellow, "yellow"),
    (.green, "green"), (.mint, "mint"), (.teal, "teal"),
    (.cyan, "cyan"), (.blue, "blue"), (.indigo, "indigo"),
    (.purple, "purple"), (.pink, "pink"), (.brown, "brown"),
    (.gray, "gray"),
  ]

  private var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private var categoryId: String {
    switch mode {
    case .add:
      return UUID().uuidString
    case .edit(let category):
      return category.id
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        nameSection
        previewSection
        iconSection
        colorSection
      }
      .navigationTitle(mode.isAdd ? "新增分類" : "編輯分類")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") {
            let category = ExpenseCategory(
              id: categoryId,
              name: name.trimmingCharacters(in: .whitespaces),
              icon: selectedIcon,
              color: selectedColor
            )
            onSave(category)
            dismiss()
          }
          .disabled(!canSave)
        }
      }
      .onAppear {
        if case .edit(let category) = mode {
          name = category.name
          selectedIcon = category.icon
          selectedColor = category.color
        }
      }
    }
  }

  // MARK: - Sections

  private var nameSection: some View {
    Section("名稱") {
      TextField("分類名稱", text: $name)
    }
  }

  private var previewSection: some View {
    Section("預覽") {
      HStack(spacing: 12) {
        Image(systemName: selectedIcon)
          .font(.system(size: 24))
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(selectedColor, in: RoundedRectangle(cornerRadius: 10))

        Text(name.isEmpty ? "分類名稱" : name)
          .foregroundStyle(name.isEmpty ? .secondary : .primary)
      }
      .padding(.vertical, 4)
    }
  }

  private var iconSection: some View {
    Section("圖示") {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
        ForEach(CategoryIcon.all, id: \.self) { icon in
          Image(systemName: icon)
            .font(.system(size: 20))
            .frame(width: 44, height: 44)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(selectedIcon == icon ? selectedColor.opacity(0.15) : Color(.tertiarySystemFill))
            )
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(selectedIcon == icon ? selectedColor : .clear, lineWidth: 2)
            )
            .onTapGesture {
              selectedIcon = icon
            }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var colorSection: some View {
    Section("顏色") {
      HStack(spacing: 0) {
        ForEach(Self.colorOptions, id: \.1) { color, _ in
          Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(
              Circle()
                .stroke(Color(.systemBackground), lineWidth: 2)
                .opacity(selectedColor == color ? 1 : 0)
            )
            .overlay(
              Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 34, height: 34)
                .opacity(selectedColor == color ? 1 : 0)
            )
            .frame(maxWidth: .infinity)
            .onTapGesture {
              selectedColor = color
            }
        }
      }
      .padding(.vertical, 8)
    }
  }
}

// MARK: - Mode Helpers

extension CategoryEditView.Mode {
  var isAdd: Bool {
    if case .add = self {
      return true
    }
    return false
  }
}

#Preview("Add") {
  CategoryEditView(mode: .add) { _ in }
}

#Preview("Edit") {
  CategoryEditView(mode: .edit(ExpenseCategory.defaults[0])) { _ in }
}

import SwiftUI

struct CategorySettingsView: View {
    @Bindable var store: ExpenseStore

    @State private var editingCategory: ExpenseCategory?
    @State private var showAddSheet = false

    private var sortableCategories: [ExpenseCategory] {
        store.categories.filter { !$0.isSystemOther }
    }

    private var otherCategory: ExpenseCategory? {
        store.categories.first { $0.isSystemOther }
    }

    var body: some View {
        List {
            Section {
                ForEach(sortableCategories) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        categoryRow(category)
                    }
                }
                .onMove { source, destination in
                    store.moveCategory(from: source, to: destination)
                }

                if let category = otherCategory {
                    categoryRow(category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("分類設定")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "rectangle.stack.badge.plus")
                }
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditView(
                mode: .edit(category),
                onSave: { updated in
                    store.updateCategory(updated)
                },
                onDelete: category.isSystemOther ? nil : {
                    store.deleteCategory(id: category.id)
                }
            )
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryEditView(mode: .add) { newCategory in
                store.categories.append(newCategory)
            }
        }
    }
    private func categoryRow(_ category: ExpenseCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(category.color, in: RoundedRectangle(cornerRadius: 8))

            Text(category.name)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        CategorySettingsView(store: ExpenseStore())
    }
}

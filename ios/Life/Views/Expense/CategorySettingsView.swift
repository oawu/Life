import SwiftUI

struct CategorySettingsView: View {
    @Bindable var store: ExpenseStore

    @State private var editingCategory: ExpenseCategory?
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                ForEach(store.categories) { category in
                    Button {
                        editingCategory = category
                    } label: {
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
                .onMove { source, destination in
                    store.moveCategory(from: source, to: destination)
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
            CategoryEditView(mode: .edit(category)) { updated in
                store.updateCategory(updated)
            } onDelete: {
                store.deleteCategory(id: category.id)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryEditView(mode: .add) { newCategory in
                store.categories.append(newCategory)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategorySettingsView(store: ExpenseStore())
    }
}

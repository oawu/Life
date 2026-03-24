import SwiftUI

struct CategorySettingsView: View {
    @Bindable var store: ExpenseStore

    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var editingCategory: ExpenseCategory?
    @State private var showAddSheet = false
    @State private var showOfflineAlert = false

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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if !authManager.isGuest && !networkMonitor.isOnline {
                            showOfflineAlert = true
                        } else {
                            editingCategory = category
                        }
                    } label: {
                        categoryRow(category)
                    }
                }
                .onMove(perform: (!authManager.isGuest && !networkMonitor.isOnline) ? nil : { source, destination in
                    store.moveCategory(from: source, to: destination)
                })

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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if !authManager.isGuest && !networkMonitor.isOnline {
                        showOfflineAlert = true
                    } else {
                        showAddSheet = true
                    }
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
                store.addCategory(id: newCategory.id, name: newCategory.name, icon: newCategory.icon, color: newCategory.color)
            }
        }
        .alert("無法連線", isPresented: $showOfflineAlert) {
            Button("好") {}
        } message: {
            Text("此操作需要網路連線，請稍後再試")
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
        CategorySettingsView(store: ExpenseStore.preview())
    }
    .environment(AuthManager())
    .environment(NetworkMonitor())
}

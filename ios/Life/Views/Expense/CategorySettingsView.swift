import SwiftUI

struct CategorySettingsView: View {
    @Bindable var store: ExpenseStore

    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var editingCategory: ExpenseCategory?
    @State private var showAddSheet = false
    @State private var showOfflineAlert = false
    @State private var showGuestAlert = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false

    private var sortableCategories: [ExpenseCategory] {
        store.categories.filter { !$0.isOther }
    }

    private var otherCategory: ExpenseCategory? {
        store.categories.first { $0.isOther }
    }

    var body: some View {
        List {
            Section {
                ForEach(sortableCategories) { category in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if authManager.isGuest {
                            showGuestAlert = true
                            return
                        }
                        if !networkMonitor.isOnline {
                            showOfflineAlert = true
                        } else {
                            editingCategory = category
                        }
                    } label: {
                        categoryRow(category)
                    }
                    .accessibilityIdentifier(AID.catSettingsRow(category.id))
                }
                .onMove(perform: authManager.isGuest || !networkMonitor.isOnline ? nil : { source, destination in
                    Task {
                        do {
                            try await store.moveCategory(from: source, to: destination)
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
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
                if !authManager.isGuest {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if !networkMonitor.isOnline {
                            showOfflineAlert = true
                        } else {
                            showAddSheet = true
                        }
                    } label: {
                        Image(systemName: "rectangle.stack.badge.plus")
                    }
                    .accessibilityIdentifier(AID.btnAddCategory)
                }
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditView(
                mode: .edit(category),
                onSave: { updated in
                    Task {
                        do {
                            try await store.updateCategory(updated)
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                },
                onDelete: category.isOther ? nil : {
                    Task {
                        do {
                            try await store.deleteCategory(id: category.id)
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryEditView(mode: .add) { newCategory in
                Task {
                    do {
                        try await store.addCategory(name: newCategory.name, icon: newCategory.icon, color: newCategory.color)
                    } catch {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
        }
        .alert("登入後可編輯", isPresented: $showGuestAlert) {
            Button("好") {}
        } message: {
            Text("登入後即可自訂分類")
        }
        .alert("無法連線", isPresented: $showOfflineAlert) {
            Button("好") {}
        } message: {
            Text("此操作需要網路連線，請稍後再試")
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage)
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

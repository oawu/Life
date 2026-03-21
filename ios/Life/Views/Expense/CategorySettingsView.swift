import SwiftUI

struct CategorySettingsView: View {
    @Bindable var store: ExpenseStore

    @State private var editingCategory: ExpenseCategory?
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                Button {
                    showAddSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("新增分類")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            Color(.separator),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                )
            }

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
                .onDelete { indexSet in
                    let idsToDelete = indexSet.map { store.categories[$0].id }
                    for id in idsToDelete {
                        store.deleteCategory(id: id)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("分類設定")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .sheet(item: $editingCategory) { category in
            CategoryEditView(mode: .edit(category)) { updated in
                store.updateCategory(updated)
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

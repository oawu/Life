import SwiftUI

struct CategoryEditView: View {
    enum Mode {
        case add
        case edit(ExpenseCategory)
    }

    let mode: Mode
    let onSave: (ExpenseCategory) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = "fork.knife"
    @State private var selectedColor: Color = .blue
    @State private var customColor: Color = .blue
    @State private var isCustomColor: Bool = false
    @State private var hasUsedCustomColor: Bool = false
    @State private var showDeleteConfirmation: Bool = false

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
            ScrollView {
                VStack(spacing: 32) {
                    previewCard
                    nameCard
                    colorCard
                    iconCard

                    if case .edit = mode {
                        deleteButton
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
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

                    let isPreset = Self.colorOptions.contains { $0.0 == category.color }
                    if !isPreset {
                        isCustomColor = true
                        hasUsedCustomColor = true
                        customColor = category.color
                    }
                }
            }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        cardSection {
            VStack(spacing: 12) {
                Image(systemName: selectedIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(selectedColor, in: RoundedRectangle(cornerRadius: 12))

                Text(name.isEmpty ? "分類名稱" : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? Color(.secondaryLabel) : Color(.label))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Name

    private var nameCard: some View {
        cardSection(title: "名稱") {
            TextField("分類名稱", text: $name)
                .padding(12)
        }
    }

    // MARK: - Color

    private var colorCard: some View {
        cardSection(title: "顏色") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(Self.colorOptions, id: \.1) { color, _ in
                    ZStack {
                        if !isCustomColor && selectedColor == color {
                            Circle()
                                .stroke(color, lineWidth: 2)
                                .frame(width: 38, height: 38)
                        }
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                    }
                    .frame(width: 42, height: 42)
                    .onTapGesture {
                        isCustomColor = false
                        selectedColor = color
                    }
                }

                // Custom color picker
                ZStack {
                    ColorPicker("", selection: $customColor, supportsOpacity: false)
                        .labelsHidden()

                    Group {
                        if hasUsedCustomColor {
                            ZStack {
                                if isCustomColor {
                                    Circle()
                                        .stroke(
                                            AngularGradient(
                                                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                                                center: .center
                                            ),
                                            lineWidth: 2
                                        )
                                        .frame(width: 38, height: 38)
                                }
                                Circle()
                                    .fill(customColor)
                                    .frame(width: 32, height: 32)
                            }
                        } else {
                            Circle()
                                .fill(
                                    AngularGradient(
                                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                                        center: .center
                                    )
                                )
                                .frame(width: 32, height: 32)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: 42, height: 42)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .onChange(of: customColor) { _, newColor in
            isCustomColor = true
            hasUsedCustomColor = true
            selectedColor = newColor
        }
    }

    // MARK: - Icon

    private var iconCard: some View {
        cardSection(title: "圖示") {
            VStack(spacing: 16) {
                ForEach(Array(CategoryIcon.groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .padding(.leading, 4)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(group.icons, id: \.self) { icon in
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
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("刪除分類")
                .frame(maxWidth: .infinity)
                .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog("確定要刪除此分類嗎？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }

    // MARK: - Card Container

    private func cardSection(title: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.leading, 16)
            }
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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

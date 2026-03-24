import SwiftUI
import WatchKit

struct WatchCategoryPickerView: View {
    let categories: [ExpenseCategory]
    @Binding var selected: ExpenseCategory?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(categories) { category in
            Button {
                WKInterfaceDevice.current().play(.click)
                selected = category
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                        .frame(width: 24)
                    Text(category.name)
                    Spacer()
                    if selected?.id == category.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("分類")
    }
}

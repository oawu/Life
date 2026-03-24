import SwiftUI
import WatchKit

struct WatchCategoryPickerView: View {
    let categories: [ExpenseCategory]
    let onSelect: (ExpenseCategory) -> Void

    var body: some View {
        List(categories) { category in
            Button {
                WKInterfaceDevice.current().play(.click)
                onSelect(category)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                        .frame(width: 24)
                    Text(category.name)
                    Spacer()
                }
            }
        }
        .navigationTitle("分類")
    }
}

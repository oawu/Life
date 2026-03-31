import SwiftUI

struct SyncProgressOverlay: View {
    let progress: SyncProgress?

    var body: some View {
        if let progress = progress {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("正在同步開銷資料")
                        .font(.headline)

                    ProgressView(value: Double(progress.completed), total: Double(progress.total))
                        .progressViewStyle(.linear)

                    Text("\(progress.completed) / \(progress.total)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 48)
            }
            .transition(.opacity)
        }
    }
}

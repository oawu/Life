import SwiftUI

struct WatchLoginRequiredView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("請在 iPhone 登入")
                .font(.headline)
            Text("登入後即可使用手錶記帳")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

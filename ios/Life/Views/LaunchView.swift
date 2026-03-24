import SwiftUI

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink)

            Text("Life")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("記錄你的生活")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LaunchView()
}

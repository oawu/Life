import SwiftUI

struct ProfileView: View {
    var authManager: AuthManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 用戶資訊
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)

                if let user = authManager.currentUser {
                    Text(user.name.isEmpty ? "未命名" : user.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("個人")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("登出") {
                    authManager.signOut()
                }
            }
        }
    }
}

#if DEBUG
import SwiftUI

struct DebugOverlayView: View {
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AuthManager.self) private var authManager
    @State private var isExpanded = false
    @State private var position = CGPoint(x: UIScreen.main.bounds.width - 40, y: UIScreen.main.bounds.height - 160)
    @GestureState private var dragOffset = CGSize.zero
    @State private var forceAPIFailure = false

    // MARK: - Computed

    private var statusColor: Color {
        if networkMonitor.forceOffline {
            return .red
        }
        if forceAPIFailure {
            return .yellow
        }
        return .green
    }

    private var statusText: String {
        if networkMonitor.forceOffline {
            return "離線中"
        }
        if forceAPIFailure {
            return "API 故障"
        }
        return "網路正常"
    }

    private var authText: String {
        switch authManager.authState {
        case .launching:
            return "launching"
        case .guest:
            return "guest"
        case .authenticated:
            return "authenticated"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 展開時的背景遮罩
            if isExpanded {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded = false
                        }
                    }
            }

            // 面板
            Group {
                if isExpanded {
                    expandedPanel
                        .transition(.scale(scale: 0.5, anchor: .bottomTrailing).combined(with: .opacity))
                } else {
                    collapsedButton
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .position(
                x: position.x + dragOffset.width,
                y: position.y + dragOffset.height
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragOffset) { value, state, _ in
                        if abs(value.translation.width) > 5 || abs(value.translation.height) > 5 {
                            state = value.translation
                        }
                    }
                    .onEnded { value in
                        let distance = abs(value.translation.width) + abs(value.translation.height)
                        if distance > 5 {
                            // 拖曳：更新位置
                            position.x += value.translation.width
                            position.y += value.translation.height
                        } else {
                            // 點擊：切換展開
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Collapsed

    private var collapsedButton: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .fill(statusColor.opacity(0.8))
                    .frame(width: 16, height: 16)
            }
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    // MARK: - Expanded

    private var expandedPanel: some View {
        @Bindable var network = networkMonitor

        return VStack(alignment: .leading, spacing: 12) {
            // 狀態列
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Toggle: 模擬斷網
            Toggle(isOn: $network.forceOffline) {
                Label("模擬斷網", systemImage: "wifi.slash")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .onChange(of: network.forceOffline) {
                if network.forceOffline {
                    network.isOnline = false
                } else {
                    // 恢復：使用 NWPathMonitor 的真實狀態
                    network.isOnline = network.realOnline
                }
            }

            // Toggle: API 故障
            Toggle(isOn: $forceAPIFailure) {
                Label("API 故障", systemImage: "exclamationmark.icloud")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .onChange(of: forceAPIFailure) {
                APIClient.shared.forceAPIFailure = forceAPIFailure
            }

            Divider()

            // Auth 狀態
            HStack(spacing: 4) {
                Text("Auth:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(authText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
#endif

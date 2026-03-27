import SwiftUI
import CoreImage.CIFilterBuiltins

struct LedgerDetailView: View {
    @Bindable var store: ExpenseStore
    let ledgerId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var showEditSheet = false
    @State private var showLeaveConfirmation = false
    @State private var showUnsettledAlert = false
    @State private var showOfflineAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showCopiedToast = false
    @State private var isLeaving = false
    @State private var qrImage: UIImage?
    @State private var toastTask: DispatchWorkItem?

    private var ledger: Ledger? {
        store.ledgers.first { $0.id == ledgerId }
    }

    var body: some View {
        Group {
            if let ledger {
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 32) {
                            inviteCodeCard(ledger)
                            qrCodeCard
                            membersCard(ledger)
                            recurringExpenseCard
                            leaveButton
                        }
                        .padding(16)
                    }

                    if showCopiedToast {
                        copiedToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(ledger.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("編輯") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if !networkMonitor.isOnline {
                                showOfflineAlert = true
                            } else {
                                showEditSheet = true
                            }
                        }
                        .accessibilityIdentifier(AID.btnLedgerEdit)
                    }
                }
                .alert("無法連線", isPresented: $showOfflineAlert) {
                    Button("好") {}
                } message: {
                    Text("此操作需要網路連線，請稍後再試")
                }
                .sheet(isPresented: $showEditSheet) {
                    if let current = self.ledger {
                        LedgerEditView(mode: .editGroup(current)) { updated in
                            Task {
                                do {
                                    try await store.updateGroupLedger(updated)
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showErrorAlert = true
                                }
                            }
                        }
                    }
                }
                .alert("錯誤", isPresented: $showErrorAlert) {
                    Button("好") {}
                } message: {
                    Text(errorMessage)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generateQRCode()
        }
    }

    // MARK: - Invite Code

    private func inviteCodeCard(_ ledger: Ledger) -> some View {
        cardSection(title: "邀請碼") {
            HStack {
                Text(ledger.formattedInviteCode ?? "")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(2)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let code = ledger.formattedInviteCode {
                        UIPasteboard.general.string = code
                        showToast()
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                        .padding(10)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
            }
            .padding(16)
        }
    }

    // MARK: - QR Code

    private var qrCodeCard: some View {
        cardSection(title: "QR Code") {
            HStack {
                Spacer()
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                } else {
                    Text("無法產生 QR Code")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Members

    private func membersCard(_ ledger: Ledger) -> some View {
        cardSection(title: "成員（\(ledger.members.count) 人）") {
            VStack(spacing: 0) {
                ForEach(Array(ledger.members.enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        Text(member.name)
                            .font(.subheadline)

                        if member.isCurrentUser {
                            Text("(我)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < ledger.members.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
    }

    // MARK: - Recurring Expenses

    private var recurringExpenseCard: some View {
        NavigationLink {
            RecurringExpenseListView(store: store, ledgerId: ledgerId)
        } label: {
            cardSection(title: "固定開銷") {
                HStack(spacing: 8) {
                    Image(systemName: "repeat")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)

                    Text("管理固定開銷")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    let count = store.recurringExpenseCount(forLedger: ledgerId)
                    if count > 0 {
                        Text("\(count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leave

    private var hasUnsettledExpenses: Bool {
        guard let ledger else { return false }
        return ledger.expenses.contains { !ledger.settledExpenseIds.contains($0.id) }
    }

    private var leaveButton: some View {
        Button(role: .destructive) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if !networkMonitor.isOnline {
                showOfflineAlert = true
            } else if hasUnsettledExpenses {
                showUnsettledAlert = true
            } else {
                showLeaveConfirmation = true
            }
        } label: {
            Text("退出帳本")
                .frame(maxWidth: .infinity)
                .padding(12)
        }
        .accessibilityIdentifier(AID.btnLedgerLeave)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("帳本尚未結清", isPresented: $showUnsettledAlert) {
            Button("好") {}
        } message: {
            Text("請先完成結算後再退出帳本")
        }
        .confirmationDialog("確定要退出此帳本嗎？", isPresented: $showLeaveConfirmation, titleVisibility: .visible) {
            Button("退出", role: .destructive) {
                isLeaving = true
                Task {
                    do {
                        try await store.leaveGroupLedger(id: ledgerId)
                        await MainActor.run {
                            isLeaving = false
                            dismiss()
                        }
                    } catch {
                        await MainActor.run {
                            isLeaving = false
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
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

    // MARK: - Toast

    private var copiedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
            Text("已複製邀請碼")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.75))
        .clipShape(Capsule())
        .padding(.top, 8)
    }

    private func showToast() {
        toastTask?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedToast = true
        }

        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
        toastTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    // MARK: - QR Code Generator

    private func generateQRCode() {
        guard let code = ledger?.inviteCode else {
            return
        }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(code.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return
        }

        let scale = 200.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return
        }

        qrImage = UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        LedgerDetailView(store: ExpenseStore.preview(), ledgerId: "roommates")
    }
    .environment(NetworkMonitor())
}

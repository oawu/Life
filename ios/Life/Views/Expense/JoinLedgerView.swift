import SwiftUI
import AVFoundation

struct JoinLedgerView: View {
    let onJoined: (Ledger) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var inputCode: String = ""
    @State private var joinedLedger: Ledger?
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined

    private var canJoin: Bool {
        inputCode.trimmingCharacters(in: .whitespaces).count == 6
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    cameraArea
                    inputArea
                }

                if let ledger = joinedLedger {
                    successOverlay(ledger)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("掃碼加入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkCameraPermission()
            }
        }
    }

    // MARK: - Camera Area

    private var cameraArea: some View {
        ZStack {
            Color.black

            if cameraPermission == .authorized {
                CameraScannerView { code in
                    handleCode(code)
                }
            } else if cameraPermission == .denied || cameraPermission == .restricted {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                    Text("請在設定中開啟相機權限")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Text("以掃描邀請碼 QR Code")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.7))
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("正在要求相機權限⋯")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 16) {
            Text("或手動輸入邀請碼")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("#")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("XXXXXX", text: $inputCode)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: inputCode) { _, newValue in
                        if newValue.count > 6 {
                            inputCode = String(newValue.prefix(6))
                        }
                    }

                Button {
                    handleCode(inputCode.trimmingCharacters(in: .whitespaces))
                } label: {
                    Text("加入")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(canJoin ? Color.blue : Color.gray)
                        .clipShape(Capsule())
                }
                .disabled(!canJoin)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Success Overlay

    private func successOverlay(_ ledger: Ledger) -> some View {
        ZStack {
            Color(.systemBackground).opacity(0.95)

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("成功加入")
                    .font(.title2.weight(.semibold))

                Text(ledger.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Button {
                    onJoined(ledger)
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 12)
            }
            .padding(32)
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermission = status

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        }
    }

    private func handleCode(_ code: String) {
        guard !code.isEmpty, joinedLedger == nil else {
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let me = LedgerMember(id: Ledger.defaultMemberId, name: "我")
        let friend = LedgerMember(id: UUID().uuidString, name: "好友")

        let ledger = Ledger(
            id: UUID().uuidString,
            name: "好友帳本",
            type: .group,
            inviteCode: code.uppercased(),
            members: [me, friend],
            categories: ExpenseCategory.groupDefaults,
            expenses: [],
            recurringExpenses: []
        )

        withAnimation(.easeInOut(duration: 0.3)) {
            joinedLedger = ledger
        }
    }
}

// MARK: - Camera Scanner

struct CameraScannerView: UIViewRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        let onCodeScanned: (String) -> Void
        private var hasScanned = false

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else {
                return
            }
            hasScanned = true
            session?.stopRunning()
            onCodeScanned(value)
        }
    }
}

#Preview {
    JoinLedgerView { _ in }
}

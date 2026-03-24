import SwiftUI
import CoreImage.CIFilterBuiltins

struct CarrierEditView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var carrierNumber: String = ""
    @State private var debouncedNumber: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    private var displayNumber: String {
        debouncedNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var isValid: Bool {
        let trimmed = carrierNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.isEmpty {
            return true
        }
        return (try? Self.carrierRegex.wholeMatch(in: trimmed)) != nil
    }

    var body: some View {
        List {
            // Barcode Card
            Section {
                VStack(spacing: 0) {
                    // 條碼
                    VStack(spacing: 12) {
                        if let barcode = generateBarcode(from: debouncedNumber) {
                            Image(uiImage: barcode)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                        } else {
                            Rectangle()
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    Image(systemName: "barcode")
                                        .font(.title)
                                        .foregroundStyle(.tertiary)
                                }
                        }

                        // 載具號碼文字
                        Text(displayNumber.isEmpty ? "/ABC1234" : displayNumber)
                            .font(.system(.body, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(displayNumber.isEmpty ? .tertiary : .primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // 輸入
            Section {
                TextField("/ABC1234", text: $carrierNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($fieldFocused)
                    .disabled(!networkMonitor.isOnline)
            } header: {
                Text("請輸入個人載具號碼")
            } footer: {
                if !networkMonitor.isOnline {
                    Text("目前離線，無法修改")
                        .foregroundStyle(.secondary)
                } else if !isValid {
                    Text("格式錯誤：/ 開頭 + 7 碼（數字、大寫字母、.、-、+）")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("載具號碼")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            carrierNumber = authManager.carrierNumber
            debouncedNumber = authManager.carrierNumber
        }
        .onDisappear {
            debounceTask?.cancel()
            if !networkMonitor.isOnline {
                return
            }
            let trimmed = carrierNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if trimmed.isEmpty || (try? Self.carrierRegex.wholeMatch(in: trimmed)) != nil {
                authManager.updateCarrierNumber(trimmed)
            }
        }
        .onChange(of: carrierNumber) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                if !Task.isCancelled {
                    debouncedNumber = newValue
                }
            }
        }
    }

    // MARK: - Private

    private static let carrierRegex = /\/[0-9A-Z.\-+]{7}/
    private static let ciContext = CIContext()

    private func generateBarcode(from string: String) -> UIImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(trimmed.utf8)
        filter.quietSpace = 2

        guard let ciImage = filter.outputImage else {
            return nil
        }

        let scaleX = 300.0 / ciImage.extent.width
        let scaleY = 120.0 / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = Self.ciContext.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

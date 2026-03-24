import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var showSignOutAlert = false
    @State private var showImageSourceDialog = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isEditingName = false
    @State private var editingName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        List {
            // 頭像
            Section {
                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showImageSourceDialog = true
                    } label: {
                        if let image = authManager.avatarImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.borderless)

                    Button("更改") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showImageSourceDialog = true
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // 資訊
            Section {
                // 名稱
                HStack {
                    Text("名稱")

                    Spacer()

                    if isEditingName {
                        TextField("名稱", text: $editingName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($nameFieldFocused)
                            .onSubmit {
                                saveName()
                            }
                            .onChange(of: nameFieldFocused) { _, focused in
                                if !focused {
                                    saveName()
                                }
                            }
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let user = authManager.currentUser {
                                editingName = user.name
                            }
                            isEditingName = true
                            nameFieldFocused = true
                        } label: {
                            Text(authManager.currentUser?.name.isEmpty == false ? authManager.currentUser!.name : "未命名")
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isEditingName)

                // Email
                HStack {
                    Text("Email")

                    Spacer()

                    Text(authManager.currentUser?.email ?? "")
                        .foregroundStyle(.secondary)
                }

                // 載具號碼
                NavigationLink {
                    CarrierEditView()
                } label: {
                    HStack {
                        Text("載具號碼")

                        Spacer()

                        Text(authManager.carrierNumber.isEmpty ? "未設定" : authManager.carrierNumber)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 登出
            Section {
                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSignOutAlert = true
                } label: {
                    Text("登出")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("個人")
        .navigationBarTitleDisplayMode(.inline)
        .alert("確定要登出嗎？", isPresented: $showSignOutAlert) {
            Button("登出", role: .destructive) {
                authManager.signOut()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("選擇照片來源", isPresented: $showImageSourceDialog) {
            Button("從相簿選擇") {
                imagePickerSource = .photoLibrary
                showImagePicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照") {
                    imagePickerSource = .camera
                    showImagePicker = true
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: imagePickerSource) { image in
                authManager.avatarImage = image
            }
        }
    }

    // MARK: - Private

    private func saveName() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            authManager.updateName(trimmed)
        }
        isEditingName = false
    }

}

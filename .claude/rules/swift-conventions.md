# Swift 開發規範

## 縮排

統一使用 **4-space** 縮排，禁止使用 2-space 或 tab。

## 觸覺回饋（Haptic Feedback）

所有可點擊的互動元素（Button、Chip、Toggle、選擇器項目等）都必須加上輕觸覺回饋，讓用戶有操作反饋感：

```swift
// ✓ 正確：在 action 開頭觸發
Button {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    // 後續邏輯...
} label: {
    Text("按鈕")
}
```

**注意**：儲存成功等結果性回饋使用 `UINotificationFeedbackGenerator`（`.success` / `.error`），與操作觸發的 `.light` impact 區分。

## XCUITest：開發者登入（devLogin）

XCUITest 中的 `devLogin` helper 必須遵循以下模式，參考 `LoginExpenseTests`：

```swift
private func devLogin(email: String = "test@test.com") {
    let profileTab = app.tabBars.buttons["個人"]
    XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "個人 Tab 未出現")
    profileTab.tap()

    let devLoginBtn = app.buttons["btn_dev_login"]
    XCTAssertTrue(devLoginBtn.waitForExistence(timeout: 5), "開發者登入按鈕未出現")
    devLoginBtn.tap()

    let emailField = app.alerts["開發者登入"].collectionViews.textFields["Email"]
    XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email 輸入框未出現")
    emailField.tap()

    // triple tap 全選文字，再刪除
    emailField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    emailField.typeText(String(XCUIKeyboardKey.delete.rawValue))

    emailField.typeText(email)

    app.alerts["開發者登入"].buttons["登入"].tap()

    let signOutBtn = app.buttons["btn_sign_out"]
    XCTAssertTrue(signOutBtn.waitForExistence(timeout: 15), "登入未完成")
}
```

**重點**：
- Email 輸入框有預設文字，必須先**全選再刪除**才能正確輸入
- 使用 `tap(withNumberOfTaps: 3, numberOfTouches: 1)` 全選文字
- 使用 `XCUIKeyboardKey.delete` 刪除選取的文字
- `app.terminate()` + `app.launch()` 後建議加 `sleep(2)` 再呼叫 `devLogin()`

## XcodeGen

專案使用 XcodeGen 管理 `.xcodeproj`。**新增或刪除 Swift 檔案後，必須執行 `xcodegen generate` 重新產生專案檔**，否則 Xcode 會找不到新檔案：

```bash
cd /Users/oa/Workspace/32_Life/ios && xcodegen generate
```

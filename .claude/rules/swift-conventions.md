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

# iOS 程式碼全面審查

審查 `ios/Life/` 下所有 Swift 程式碼的品質、效能與安全性。

## 步驟

### 1. 掃描所有原始碼

使用 Agent（Explore）讀取 `ios/Life/` 下所有 `.swift` 檔案：

- `LifeApp.swift`、`Environment.swift`（根層級）
- `Models/*.swift`（資料模型）
- `Services/*.swift`（狀態管理、API、工具服務）
- `Views/**/*.swift`（UI 畫面）

### 2. 逐項檢查

**依重要性排序**，對每個檔案進行以下檢查：

#### ① 死碼與多餘程式
- 未使用的 `import`、變數、函式、參數
- 永遠不會執行的分支
- 已標記為 `TODO` 但永遠不會實作的程式碼
- 重複的邏輯或可以共用的程式碼

#### ② 效能問題
- 昂貴物件重複建立（如 `NumberFormatter`、`DateFormatter` 應 `static`）
- 不必要的 View 重繪（computed property 頻繁重算）
- 大量資料的 O(n²) 操作
- 圖片/資源的記憶體佔用

#### ③ 記憶體與資源釋放
- Strong reference cycle（`@Observable` + closure capture）
- 未取消的 `Task`、`Timer`、`DispatchWorkItem`
- `CLLocationManager`、`AVCaptureSession` 等系統資源的正確釋放
- SwiftUI View 中非 `@State` 的重量級物件（每次 struct 重建都會重新分配）

#### ④ Thread 安全性
- `@Observable` 屬性是否只在 Main Thread 修改
- `CLLocationManager` delegate callback 的 thread
- `CLGeocoder` completion handler 的 thread
- `AVCaptureMetadataOutput` delegate queue
- `async/await` 與 `MainActor` 的正確使用
- `DispatchQueue` 切換是否安全

#### ⑤ 命名一致性
- 檔案名與 class/struct 名是否對應
- SwiftUI View 命名慣例（`*View`、`*Row`、`*Card`）
- 服務層命名慣例（`*Service`、`*Manager`、`*Store`、`*Engine`）
- 變數名語意是否清晰，有無誤導性命名

#### ⑥ 優化建議（非必要）
- 可簡化或合併的邏輯
- 可改善可讀性的重構
- 現代化語法替換（如 `DispatchWorkItem` → `Task`）

### 3. 驗證關鍵發現

對每個發現的問題，必須回到原始碼逐行驗證：

- **排除 false positive**：確認問題真的存在，不是對 API 行為的誤解
- **確認 thread 行為**：查閱 Apple 文件確認 callback 的 thread 保證
- **確認記憶體模型**：理解 SwiftUI struct View 的生命週期再判斷

### 4. 產出報告

```
## iOS 程式碼審查結果

### 需修復

| 嚴重度 | 檔案 | 問題 | 說明 |
|--------|------|------|------|
| 🔴 | ... | ... | ... |
| 🟡 | ... | ... | ... |

### 無問題

| 檢查項目 | 狀態 |
|----------|------|
| Thread 安全性 | ✅ 無問題 |
| 記憶體洩漏 | ✅ 無問題 |
| ... | ... |

### 優化建議（非必要）

- ...
```

### 5. 修復問題

若發現需修復的問題：
1. 依嚴重度排序
2. 說明問題與修復方案
3. 詢問是否修復
4. 修復後重新驗證

## 注意事項

- 以 Apple 官方文件為準判斷 API 行為（thread 保證、生命週期等）
- 不要過度報告：確認是真實問題再列入
- SwiftUI struct View 的 stored property 重建是正常行為，僅當物件昂貴時才需關注
- `@Observable` 的 Observation framework 不等同 Combine，不要套用 Combine 的假設
- 規範以 `.claude/rules/swift-conventions.md` 為準
- 只修改程式碼，不修改文件

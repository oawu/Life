# iOS UI Test

執行 iOS XCUITest 並產出結構化測試報告。

參數：$ARGUMENTS

## 使用方式

- `/ios-test` — 執行所有測試
- `/ios-test SimpleTests` — 執行 SimpleTests 中的所有測試
- `/ios-test SimpleTests/test_addExpense_3x5` — 執行單一測試

## 步驟

### 1. 解析參數

解析 `$ARGUMENTS`，判斷測試範圍：

- **空白**：執行所有 LifeUITests
- **`ClassName`**：執行該 class 的所有測試
- **`ClassName/test_functionName`**：執行單一測試

### 2. 驗證測試存在

在 `ios/LifeUITests/` 目錄下搜尋 `.swift` 測試檔案：

- 若指定了 class，確認對應 `.swift` 檔案存在，且包含 `XCTestCase`
- 若指定了 function，確認 class 檔案中存在 `func <functionName>()`
- 若不存在，列出所有可用的測試 class 和 function，讓使用者選擇
- 不要繼續執行測試

### 3. 開啟模擬器

執行測試前先開啟 Simulator.app，讓使用者可以看到測試過程：

```
open -a Simulator
```

### 4. 產生 xcodebuild 指令

基本指令：

```
cd /Users/oa/Workspace/32_Life/ios && xcodebuild test \
  -project Life.xcodeproj \
  -scheme "Life Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/LifeBuild \
  -only-testing:<target> \
  -resultBundlePath /tmp/LifeTestResult.xcresult \
  2>&1
```

`-only-testing` 規則：
- 全部：`-only-testing:LifeUITests`
- 指定 class：`-only-testing:LifeUITests/ClassName`
- 指定 function：`-only-testing:LifeUITests/ClassName/functionName`

在執行前先刪除舊的 xcresult：`rm -rf /tmp/LifeTestResult.xcresult`

### 5. 執行測試

執行 xcodebuild 指令。若 build 失敗，直接回報錯誤訊息。

### 6. 產出報告

從 xcodebuild 輸出和 xcresult 解析結果，產出以下格式的報告：

```
## 測試結果

| 測試 | 結果 | 耗時 |
|------|------|------|
| test_homeScreen_shows | Pass | 2.1s |
| test_addExpense_3x5 | Fail | 8.3s |

通過：3/4（75%）
總耗時：25.6 秒
```

若有失敗的測試，額外列出失敗原因：

```
### 失敗詳情

**test_addExpense_3x5**
- 錯誤：XCTAssertTrue failed - "第二頁分類未出現"
- 位置：SimpleTests.swift:60
```

### 7. 讀取測試原始碼並解說流程

讀取每個測試的 Swift 原始碼，用人類易懂的方式描述測試流程。

對於通過的測試，產出類似：

```
**test_addExpense_3x5** (12.5s)
啟動 App → 按 3, x, 5, = （計算得 15）→ 滑到分類第二頁 → 點「醫療」分類 → 點「儲存」→ 確認計算機歸零（= 儲存成功）
```

對於失敗的測試，在流程描述後標註失敗點：

```
**test_addExpense_3x5** (8.3s) FAIL
啟動 App → 按 3, x, 5, = （計算得 15）→ 滑到分類第二頁 → [失敗] 第二頁分類未出現
```

## 注意事項

- 測試執行前不需要 `xcodegen generate`，直接使用現有 `.xcodeproj`
- 若 `.xcodeproj` 不存在或過期，先執行 `xcodegen generate`
- 測試使用 `Life Dev` scheme（Local config）
- 模擬器會自動啟動，不需手動 boot

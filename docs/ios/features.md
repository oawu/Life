# iOS App 功能模組

每個模組包含：畫面描述、使用者操作流程、目前實作狀態、後端需求。

> **目前狀態**：所有資料為純記憶體儲存（mock data），尚未串接後端 API。

---

## 1. 登入（Authentication）

### 畫面

**LoginView** — App 啟動時顯示（未登入）

- App Logo + 名稱 + 副標題
- Sign In with Apple 按鈕
- 開發者登入按鈕（LOCAL 環境限定，輸入 email 即可）
- Loading 狀態、錯誤訊息

### 流程

```
1. 用戶點「Sign In with Apple」
2. 系統彈出 Apple 授權畫面
3. 取得 identityToken + fullName
4. POST /api/auth/apple/callback → 取得 JWT + UserInfo
5. JWT 存入 Keychain → 進入 HomeView
```

**開發者登入（isDev）**：
```
1. 輸入任意 email
2. POST /api/auth/apple/callback { email, isDev: true }
3. 後端以 email 模擬登入（跳過 Apple token 驗證）
```

**App 冷啟動**：
```
1. 從 Keychain 讀取 JWT
2. GET /api/auth/me → 驗證 token 有效性
3. 成功 → 直接進入 HomeView
4. 失敗 → 清除 token → 顯示 LoginView
```

### 已實作的後端 API

| Method | Path | Body | Response | 說明 |
|--------|------|------|----------|------|
| POST | /api/auth/apple/callback | identityToken, fullName, isDev? | { token, user } | Apple 登入 |
| GET | /api/auth/me | — | { user } | 驗證 token |

### 已實作的後端 Table

| Table | 欄位 | 說明 |
|-------|------|------|
| User | id, email, name, avatar?, appleId, status, createAt, updateAt | 用戶 |

---

## 2. 記帳（Expense Recording）

### 畫面

**AddExpenseView** — Tab 1 主畫面

| 區塊 | 元件 | 說明 |
|------|------|------|
| 帳本切換 | LedgerSwitcher | 頂部橫向滾動 pill，尾端齒輪按鈕 |
| 金額輸入 | CalculatorView | 4×4 按鈕 + 顯示列，支援四則運算 |
| 分類選擇 | CategoryGridView | 4×2 分頁格，水平滾動 + 頁碼指示 |
| 付款人 | PayerChips | 僅群組帳本顯示，水平滾動成員 chip |
| 詳細資訊 | ExpenseDetailFields | 備註、日期時間、位置 |

### 流程

```
1. 選擇帳本（LedgerSwitcher）
   └─ 切換帳本 → 清空已選分類 + 付款人，分類列表自動替換
2. 輸入金額（CalculatorView）
   └─ 支援連續運算，按「=」取得結果
3. 選擇分類（CategoryGridView）
   └─ 點擊分類高亮，分頁滑動選擇
4.（群組帳本）選擇付款人（PayerChips）
   └─ 預設未選，必須選擇才能儲存
5. 填寫備註、日期、位置（ExpenseDetailFields）
   └─ 位置可：取得目前位置 / 地圖選點 / 清除
6. 點「儲存」
   └─ 驗證：金額 > 0、已選分類、群組帳本需選付款人
   └─ 儲存成功 → 顯示金額「已儲存 $150」→ 表單重置
```

### 儲存驗證規則

| 條件 | 規則 |
|------|------|
| 金額 | > 0 |
| 分類 | 必選 |
| 付款人 | 群組帳本必選，個人帳本不需要 |
| 備註 | 選填 |
| 日期 | 預設今天，可改 |
| 位置 | 選填 |

### 待實作後端需求

| Method | Path | Body | 說明 |
|--------|------|------|------|
| POST | /api/expenses | amount, categoryId, memo, date, lat?, lon?, address?, ledgerId, paidByMemberId? | 新增開銷 |
| GET | /api/expenses | ledgerId, page?, limit? | 取得開銷列表 |
| DELETE | /api/expenses/:id | — | 刪除開銷 |

### 待設計 Table

| Table | 欄位（建議） | 說明 |
|-------|-------------|------|
| Expense | id, ledgerId, categoryId, amount, memo, date, latitude?, longitude?, address?, paidByUserId?, createdByUserId, createAt | 開銷紀錄 |

---

## 3. 開銷列表（Expense List）

### 畫面

**ExpenseListView** — 從 AddExpenseView 點「明細」push 進入

- 頂部 LedgerSwitcher（safeAreaInset），滾動時漸變為毛玻璃背景（iOS 18+）
- 群組帳本顯示拆帳區塊（有差異時）+ 結清按鈕
- 空狀態：tray 圖示 + 「尚無開銷紀錄」
- 列表：按日期分組（新→舊），Section header 顯示日期 + 當日小計
- 時間線包含：開銷群組 + 結算紀錄（群組帳本）
- 每行：分類圖示（帶顏色）+ 分類名 + 備註 + 付款人（群組帳本）+ 金額
- 左滑刪除

### 流程

```
1. 切換帳本（LedgerSwitcher）
2. 顯示目前帳本的所有開銷
3. 按日期分組排列
4. 群組帳本：頂部顯示拆帳區塊（見 Section 8）
5. 左滑某筆 → 刪除
```

---

## 3a. 開銷詳情與編輯（Expense Detail & Edit）

### 畫面

**ExpenseDetailView** — 從 ExpenseListView 點擊開銷 push 進入

| 區塊 | 說明 |
|------|------|
| 金額 | 36pt rounded bold + 幣別 badge |
| 分類 | 圖示 + 名稱置中 |
| 詳細資訊 | 時間、備註（有才顯示）、付款人（群組才顯示） |
| 位置 | Map + Marker（180pt）、地址、「在 Apple 地圖中開啟」按鈕 |
| 刪除按鈕 | 紅色 + confirmationDialog 確認 |
| Toolbar | 右上角「編輯」→ sheet ExpenseEditView |

**ExpenseEditView** — Sheet 呈現

- 複用 CalculatorView、CategoryGridView、PayerChips、ExpenseDetailFields
- onAppear 預填所有欄位（金額、分類、備註、日期、付款人、位置）
- 取消 / 儲存按鈕

### 流程

```
查看詳情：
1. 開銷列表點擊某筆開銷 → push 到 ExpenseDetailView
2. 有位置時顯示地圖區塊，可開啟 Apple 地圖

編輯：
1. 詳情頁右上角「編輯」→ sheet ExpenseEditView
2. 修改欄位 → 儲存 → ExpenseStore.updateExpense()

刪除：
1. 詳情頁底部「刪除開銷」→ confirmationDialog 確認
2. 刪除成功 → pop back
```

---

## 3b. 開銷統計圖表（Expense Chart）

### 畫面

**ExpenseChartView** — 從 ExpenseListView 右上角按鈕 push 進入

| 區塊 | 說明 |
|------|------|
| Header | safeAreaInset 置中 segmented Picker（月/年），右上角圓餅圖顯隱 toggle |
| 列表 | 每個月/年為獨立 Section，所有期間一次列出 |
| 環形圖 | Swift Charts SectorMark（innerRadius 0.618），中心顯示總金額 |
| 分類明細 | 圖示色塊 + 名稱 + 進度條 + 金額 + 百分比，按金額降序 |

### 流程

```
1. 開銷列表右上角按鈕 → push ExpenseChartView
2. 切換月/年 segmented Picker → 重新分組統計
3. Toggle 圓餅圖顯隱
```

---

## 4. 分類管理（Category Management）

### 畫面

**CategorySettingsView** — 從 AddExpenseView 分類區的「設定」push 進入

- 頂部虛線「＋新增分類」按鈕
- 分類列表：圖示（帶顏色方塊）+ 名稱，可拖曳排序
- 點擊分類 → sheet 開啟 CategoryEditView

**CategoryEditView** — Sheet 呈現

| 區塊 | 說明 |
|------|------|
| 預覽卡片 | 圖示 + 顏色 + 名稱即時預覽 |
| 名稱 | TextField |
| 顏色 | 13 個預設色圓 + 自訂顏色（ColorPicker） |
| 圖示 | 兩步驟：① 選群組（3×3）→ ② 選圖示（6 欄），選後自動返回群組列表 |
| 刪除 | 僅編輯模式，確認對話框 |

### 流程

```
新增：
1. 點「新增分類」→ 開啟 CategoryEditView（add mode）
2. 預設無圖示（顯示 questionmark），必須選圖示才能儲存
3. 輸入名稱 + 選顏色 + 選圖示 → 儲存

編輯：
1. 點擊分類 → 開啟 CategoryEditView（edit mode）
2. 修改名稱/顏色/圖示 → 儲存
3. 儲存後自動更新該分類的所有開銷參考

刪除：
1. 編輯模式點「刪除分類」→ 確認 → 刪除

排序：
1. 拖曳手柄調整順序
```

### 圖示群組

9 組：餐飲、交通、購物、居住、娛樂、財務、健康、通訊、其他

### 待實作後端需求

| Method | Path | Body | 說明 |
|--------|------|------|------|
| GET | /api/ledgers/:id/categories | — | 取得帳本的分類列表 |
| POST | /api/ledgers/:id/categories | name, icon, color, sort | 新增分類 |
| PUT | /api/categories/:id | name?, icon?, color? | 更新分類 |
| DELETE | /api/categories/:id | — | 刪除分類 |
| PATCH | /api/ledgers/:id/categories/sort | ids: [String] | 排序分類 |

### 待設計 Table

| Table | 欄位（建議） | 說明 |
|-------|-------------|------|
| Category | id, ledgerId, name, icon, color, sort, createAt | 分類 |

---

## 5. 帳本管理（Ledger Management）

### 畫面

**LedgerSettingsView** — 從 LedgerSwitcher 齒輪按鈕 push 進入

- 頂部虛線「＋新增帳本」按鈕 → confirmationDialog（自己建立 / 掃碼加入）
- 個人帳本區：點擊 → sheet 編輯名稱
- 群組帳本區：可拖曳排序，點擊 → push 到詳情頁
- List 處於永久 editMode（顯示排序手柄）

**LedgerEditView** — Sheet 呈現

- 三種 mode：add / editPersonal / editGroup
- 名稱 TextField + 幣別選擇器（14 種幣別）+ 取消/儲存按鈕
- 帳本已有開銷時，幣別選擇器 disabled 並顯示提示
- add mode 建立群組帳本：自動生成邀請碼、預設成員「我」、使用群組預設分類

**LedgerDetailView** — 群組帳本詳情頁（push 進入）

| 區塊 | 說明 |
|------|------|
| 邀請碼卡片 | 大字 monospaced 顯示 `#XXXXXX`，複製按鈕 + toast |
| QR Code 卡片 | CIFilter 產生 200×200 QR 圖片 |
| 成員列表 | person.fill 圖示 + 名稱，「我」標注 |
| 固定開銷 | 顯示數量 + NavigationLink 進入 RecurringExpenseListView |
| 退出按鈕 | 未結清 → alert 攔截；已結清 → confirmationDialog 確認退出 |
| Toolbar | 「編輯」→ sheet 開啟 LedgerEditView(.editGroup) |

**JoinLedgerView** — 掃碼加入（Sheet 呈現）

| 區塊 | 說明 |
|------|------|
| 相機區 | AVFoundation 掃描 QR Code，處理權限狀態 |
| 手動輸入 | `#` 前綴 + TextField（6 碼大寫）+ 「加入」按鈕 |
| 成功 overlay | checkmark + 帳本名稱 + 「完成」按鈕 |

### 邀請碼規則

- 6 碼，顯示時加 `#` 前綴（如 `#K3XR7N`）
- 字元集（25 個）：`A C D E F G H J K M N P Q R T U V W X Y 3 4 6 7 9`
- 排除相似字：`0 O 1 I L S 5 Z 2 B 8`
- 建立群組帳本時自動生成

### 流程

```
建立帳本：
1. 點「新增帳本」→ 選「自己建立」
2. 輸入名稱 → 儲存
3. 自動生成邀請碼、預設成員「我」、群組預設分類

掃碼加入：
1. 點「新增帳本」→ 選「掃碼加入」
2. 掃 QR Code 或手動輸入 6 碼邀請碼
3. 成功 → 顯示成功 overlay → 完成後加入帳本列表
（目前為 mock 邏輯，建立假的「好友帳本」）

編輯帳本：
1. 個人帳本：點擊 → sheet 修改名稱 / 幣別
2. 群組帳本：點擊 → push 詳情頁 → 點「編輯」→ sheet 修改名稱 / 幣別

分享邀請碼：
1. 進入群組帳本詳情頁
2. 複製邀請碼（toast 提示「已複製邀請碼」）
3. 或讓對方掃描 QR Code

退出帳本：
1. 群組帳本詳情頁 → 點「退出帳本」
2. 帳本尚未結清 → alert 攔截（「帳本尚未結清，無法退出」）
3. 已結清 → confirmationDialog 確認 → 退出並自動切回個人帳本

人員異動規則：
- 帳本尚未結清時，任何人員無法加入或退出
- 加入群組帳本：未結清時 alert 攔截
- 退出群組帳本：未結清時 alert 攔截

排序：
1. 拖曳群組帳本調整順序（個人帳本固定在最前）
```

### 帳本類型

| 類型 | 邀請碼 | 成員 | 幣別 | 分類 | 說明 |
|------|--------|------|------|------|------|
| personal | 無 | 僅自己 | 預設 TWD | 個人預設（25 個） | 每人一個，不可刪除 |
| group | 有 | 多人 | 建立時選擇 | 群組預設（7 個） | 可多個，透過邀請碼加入 |

### 待實作後端需求

| Method | Path | Body | 說明 |
|--------|------|------|------|
| GET | /api/ledgers | — | 取得用戶所有帳本 |
| POST | /api/ledgers | name | 建立群組帳本（後端生成邀請碼） |
| PUT | /api/ledgers/:id | name? | 更新帳本名稱 |
| DELETE | /api/ledgers/:id | — | 刪除帳本（僅建立者？或所有成員？） |
| PATCH | /api/ledgers/sort | ids: [String] | 排序帳本 |
| POST | /api/ledgers/join | inviteCode | 以邀請碼加入帳本 |
| GET | /api/ledgers/:id/members | — | 取得帳本成員 |
| DELETE | /api/ledgers/:id/members/:userId | — | 移除成員 / 退出帳本 |

### 待設計 Table

| Table | 欄位（建議） | 說明 |
|-------|-------------|------|
| Ledger | id, name, type(personal/group), currency(varchar 3), inviteCode?, createdByUserId, sort, createAt, updateAt | 帳本 |
| LedgerMember | id, ledgerId, userId, role(owner/member), joinAt | 帳本成員（多對多） |

---

## 6. 位置選擇（Location Picker）

### 畫面

**LocationPickerView** — Sheet 呈現（從 ExpenseDetailFields 開啟）

- 全螢幕 MapKit 地圖，中心固定 pin 標記
- 底部地址列（拖動地圖後自動反向地理編碼）
- 右下角「目前位置」按鈕
- 導航列：取消 / 確認

### 流程

```
取得目前位置：
1. ExpenseDetailFields 點「取得目前位置」
2. 請求定位權限 → 取得座標 → 反向地理編碼 → 顯示地址

地圖選點：
1. ExpenseDetailFields 點「選擇位置」→ sheet LocationPickerView
2. 拖動地圖 → 停止後自動更新地址
3. 可點「目前位置」跳到所在地
4. 確認 → 回傳座標 + 地址

清除位置：
1. 已有位置時顯示「✕」按鈕 → 清除座標和地址
```

### 預設位置

無初始座標且無法定位時，預設台北（25.033, 121.565）。

---

## 7. 個人頁面（Profile）

### 畫面

**ProfileView** — Tab 2

| 區塊 | 說明 |
|------|------|
| 頭像區塊 | 100pt 圓形大頭照 + 「更改」文字按鈕，點擊 → confirmationDialog 選擇相簿/拍照 |
| 名稱 | 點擊切換為 TextField inline 編輯，完成後自動儲存 |
| Email | 靜態顯示，不可編輯 |
| 登出按鈕 | `role: .destructive`，點擊 → alert 確認後登出 |

**ImagePickerView**（Views/Profile/）— UIViewControllerRepresentable

- 包裝 UIImagePickerController
- 支援 photoLibrary 和 camera 兩種來源
- allowsEditing: true（裁切圓形頭像）

### 流程

```
更換頭像：
1. 點擊頭像圖片或「更改」按鈕
2. confirmationDialog：「從相簿選擇」/「拍照」
3. ImagePickerView sheet → 選擇/拍攝照片
4. 回傳 UIImage → authManager.avatarImage

編輯名稱：
1. 點擊名稱 → 切換為 TextField
2. 輸入完成（鍵盤 Done 或失焦）→ authManager.updateName()

登出：
1. 點「登出」→ alert「確定要登出嗎？」
2. 確認 → AuthManager.signOut()
3. 清除 Keychain JWT → isAuthenticated = false → 顯示 LoginView
```

---

## 8. 拆帳（Settlement）

### 畫面

拆帳功能整合於 **ExpenseListView**（群組帳本限定）

| 區塊 | 說明 |
|------|------|
| 拆帳區塊 | 列表頂部 Section，顯示轉帳明細（有差異時才顯示） |
| 結清按鈕 | 確認後標記所有開銷為已結算 |
| 結算紀錄 | 時間線中顯示「已經由 xxx 結算拆帳！」，可點擊進入詳情 |

**SettlementDetailView** — 從結算紀錄 push 進入

- 結算時間、操作者
- 轉帳明細快照（付款人 → 收款人 + 金額）

### 流程

```
拆帳計算：
1. 統計未結算開銷中每位成員的付款總額
2. 計算人均分攤金額
3. 貪婪配對產生最少筆轉帳明細
4. 持平時不顯示拆帳區塊

結清：
1. 點「結清」→ confirmationDialog 確認
2. 標記所有開銷為已結算
3. 建立 SettlementRecord（含轉帳明細快照 + 幣別）
4. toast「已完成結算」
5. 時間線中顯示結算紀錄
```

### 資料模型

- `SettlementTransfer`：from（成員）→ to（成員）+ 金額
- `SettlementRecord`：結算時間 + 操作者 + 轉帳明細快照 + 幣別符號
- `Ledger.settledExpenseIds`：已結算開銷 ID 集合（排除於拆帳計算）
- `Ledger.settlementRecords`：結算歷史紀錄

---

## 9. 固定開銷（Recurring Expense）

### 畫面

**RecurringExpenseListView** — 從帳本設定 / 帳本詳情 push 進入

- 列表：金額 + 排程描述 + 備註 + 付款人（群組帳本）
- 左滑刪除
- 右上角「＋」新增按鈕

**RecurringExpenseEditView** — Sheet 呈現

| 區塊 | 說明 |
|------|------|
| 金額輸入 | 複用 CalculatorView |
| 分類選擇 | 複用 CategoryGridView |
| 排程選擇 | 每天 / 每週 / 每月 / 每年 |
| 付款人 | 複用 PayerChips（群組帳本） |
| 詳細資訊 | 複用 ExpenseDetailFields（隱藏日期） |

### 流程

```
新增：
1. 點「＋」→ sheet RecurringExpenseEditView（add mode）
2. 輸入金額 + 選分類 + 選排程 → 儲存

編輯：
1. 點擊項目 → sheet RecurringExpenseEditView（edit mode）
2. 修改 → 儲存

刪除：
1. 左滑 → 刪除
```

### 排程規則

| 頻率 | 參數 | 顯示範例 |
|------|------|----------|
| daily | — | 每天 |
| weekly | dayOfWeek（1=日…7=六） | 每週三 |
| monthly | dayOfMonth（1-31） | 每月 15 日 |
| yearly | month + day | 每年 1 月 1 日 |

- 每月 29-31 日、每年特殊日期顯示橘色警告
- 新增時排程不預選，必須選擇才能儲存

### 入口

| 帳本類型 | 入口位置 |
|----------|----------|
| 個人帳本 | LedgerSettingsView → 固定開銷 |
| 群組帳本 | LedgerDetailView → 固定開銷 |

---

## 待開發功能

以下功能尚未實作，列出供規劃參考：

### Apple Watch App

- watchOS 記帳快速入口（金額 + 分類，簡化操作）
- 與 iPhone 同步帳本資料
- Complication 顯示今日花費

### Widget

- 今日花費摘要
- 快速記帳入口

### 後端同步

- 目前所有資料為記憶體儲存，App 重啟後消失
- 需實作後端 API 後改為網路同步
- 離線暫存 + 上線同步機制

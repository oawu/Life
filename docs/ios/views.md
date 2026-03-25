# iOS View 元件清單

所有 View 的檔案路徑、職責、參數、導航關係。

---

## 根層級

| View | 檔案 | 說明 |
|------|------|------|
| LifeApp | LifeApp.swift | App 入口，依 AuthState 切換 LaunchView / HomeView，`.environment(authManager)` 注入 |
| LaunchView | Views/LaunchView.swift | 啟動畫面（Logo + "Life"），AuthManager 背景檢查 token 後自動切走 |
| LoginPromptView | Views/LoginPromptView.swift | 可複用登入 sheet，接收 `message` 參數，登入成功自動 dismiss |
| GuestProfileView | Views/GuestProfileView.swift | Tab 2 訪客模式登入頁（品牌展示 + Apple Sign In） |
| HomeView | Views/HomeView.swift | 主畫面 TabView（記帳 + 個人），Tab 2 依 authState 切換 ProfileView / GuestProfileView |
| ProfileView | Views/ProfileView.swift | 個人頁，頭像更換 + 名稱編輯 + 登出（已登入限定） |

## 記帳功能群組（Views/Expense/）

### 核心

| View | 檔案 | 參數 | 說明 |
|------|------|------|------|
| AddExpenseView | AddExpenseView.swift | store: ExpenseStore | Tab 1 主畫面，整合所有記帳元件 |
| CalculatorView | CalculatorView.swift | engine: CalculatorEngine, currency: Currency | 4×4 計算機（金額輸入），左上幣別 badge |
| ExpenseDetailFields | ExpenseDetailFields.swift | memo, date, locationService | 備註 + 日期 + 位置 |
| ExpenseListView | ExpenseListView.swift | store: ExpenseStore | 開銷列表（按日期分組），toolbar 右上 push 到 ExpenseChartView |
| ExpenseDetailView | ExpenseDetailView.swift | store: ExpenseStore, expenseId: UUID | 開銷詳情頁（金額、分類、位置地圖、刪除） |
| ExpenseEditView | ExpenseEditView.swift | expense, ledger, store | 開銷編輯 sheet（複用記帳元件） |
| ExpenseChartView | ExpenseChartView.swift | store: ExpenseStore | 開銷統計圖表（環形圖 + 分類進度條），月/年切換 |
| SettlementDetailView | SettlementDetailView.swift | record: SettlementRecord | 結算紀錄詳情（轉帳明細） |

### 帳本

| View | 檔案 | 參數 | 呈現方式 |
|------|------|------|----------|
| LedgerSwitcher | LedgerSwitcher.swift | ledgers, selectedId, onSettingsTapped? | 嵌入 AddExpenseView 頂部 + ExpenseListView safeAreaInset |
| LedgerSettingsView | LedgerSettingsView.swift | store: ExpenseStore | push 從 AddExpenseView |
| LedgerEditView | LedgerEditView.swift | mode: Mode, onSave | sheet |
| LedgerDetailView | LedgerDetailView.swift | store: ExpenseStore, ledgerId: String | push 從 LedgerSettingsView |
| JoinLedgerView | JoinLedgerView.swift | onJoined: (Ledger) -> Void | sheet |

**LedgerEditView.Mode**：
- `.add` — 建立群組帳本
- `.editPersonal(Ledger)` — 編輯個人帳本名稱 + 幣別
- `.editGroup(Ledger)` — 編輯群組帳本名稱 + 幣別

### 分類

| View | 檔案 | 參數 | 呈現方式 |
|------|------|------|----------|
| CategoryGridView | CategoryGridView.swift | categories, selected, onSettingsTapped | 嵌入 AddExpenseView |
| CategorySettingsView | CategorySettingsView.swift | store: ExpenseStore | push 從 AddExpenseView |
| CategoryEditView | CategoryEditView.swift | mode: Mode, onSave, onDelete? | sheet |

**CategoryEditView.Mode**：
- `.add` — 新增分類（預設無圖示）
- `.edit(ExpenseCategory)` — 編輯分類

### 固定開銷

| View | 檔案 | 參數 | 呈現方式 |
|------|------|------|----------|
| RecurringExpenseListView | RecurringExpenseListView.swift | store: ExpenseStore, ledgerId: String | push 從 LedgerSettingsView / LedgerDetailView |
| RecurringExpenseEditView | RecurringExpenseEditView.swift | mode: Mode, ledger: Ledger, store: ExpenseStore | sheet |

**RecurringExpenseEditView.Mode**：
- `.add` — 新增固定開銷
- `.edit(RecurringExpense)` — 編輯固定開銷

### 付款人

| View | 檔案 | 參數 | 說明 |
|------|------|------|------|
| PayerChips | PayerChips.swift | members, selected | 群組帳本付款人選擇（水平 chip） |

### 位置

| View | 檔案 | 參數 | 呈現方式 |
|------|------|------|----------|
| LocationPickerView | LocationPickerView.swift | initialLat?, initialLon?, onConfirm | sheet |

## 個人頁面群組（Views/Profile/）

| View | 檔案 | 參數 | 呈現方式 |
|------|------|------|----------|
| ImagePickerView | ImagePickerView.swift | sourceType, onImagePicked | sheet（UIImagePickerController 包裝） |
| CarrierEditView | CarrierEditView.swift | （@Environment AuthManager） | push 從 ProfileView |

---

## 導航關係圖

```
LifeApp
├─ .launching → LaunchView（品牌 Logo，背景檢查 token）
├─ .guest / .authenticated → HomeView
└─ overlay: DebugOverlayView（#if DEBUG，浮動 debug 面板）

HomeView (TabView)
│
├─ Tab 1: AddExpenseView
│  │
│  ├─ 嵌入: LedgerSwitcher
│  ├─ 嵌入: CalculatorView
│  ├─ 嵌入: CategoryGridView
│  ├─ 嵌入: PayerChips（群組帳本時）
│  ├─ 嵌入: ExpenseDetailFields
│  │         └─ sheet: LocationPickerView
│  │
│  ├─ push: ExpenseListView
│  │         ├─ 嵌入: LedgerSwitcher（safeAreaInset）
│  │         ├─ push: ExpenseDetailView
│  │         │         └─ sheet: ExpenseEditView
│  │         ├─ push: SettlementDetailView
│  │         └─ push: ExpenseChartView
│  ├─ push: CategorySettingsView
│  │         └─ sheet: CategoryEditView
│  └─ push: LedgerSettingsView
│            ├─ sheet: LedgerEditView(.add)          ← 自己建立（訪客 → LoginPromptView）
│            ├─ sheet: JoinLedgerView                ← 掃碼加入（訪客 → LoginPromptView）
│            ├─ sheet: LoginPromptView               ← 訪客登入提示
│            ├─ sheet: LedgerEditView(.editPersonal) ← 個人帳本
│            ├─ push: RecurringExpenseListView        ← 個人帳本固定開銷
│            │         └─ sheet: RecurringExpenseEditView
│            └─ push: LedgerDetailView               ← 群組帳本
│                     ├─ sheet: LedgerEditView(.editGroup)
│                     └─ push: RecurringExpenseListView
│                               └─ sheet: RecurringExpenseEditView
│
└─ Tab 2（依 authState 切換）
   ├─ .authenticated → ProfileView
   │   ├─ 頭像/「更改」→ confirmationDialog → sheet: ImagePickerView
   │   ├─ 名稱 → inline TextField 編輯
   │   ├─ push: CarrierEditView（載具號碼編輯 + 條碼預覽）
   │   └─ 登出 → alert 確認 → LifeApp onChange 重設資料
   └─ .guest → GuestProfileView（品牌展示 + Apple Sign In）
```

**符號**：
- `push` = NavigationStack push（有返回按鈕）
- `sheet` = Modal sheet（有取消/關閉按鈕）
- `嵌入` = 直接嵌在父 View 中（非導航）

---

## Debug（`#if DEBUG` 限定）

| View | 檔案 | 說明 |
|------|------|------|
| DebugOverlayView | Views/DebugOverlayView.swift | 浮動 debug 面板，可拖曳圓形按鈕（狀態燈：綠/黃/紅），展開可切換「模擬斷網」「API 故障」，顯示 Auth 狀態 |

掛載於 `LifeApp.swift` 根層 `.overlay`，Release build 不包含。

---

## Watch Views（LifeWatch/Views/）

| View | 檔案 | 參數 | 說明 |
|------|------|------|------|
| WatchAddExpenseView | WatchAddExpenseView.swift | store: WatchExpenseStore | Wizard 協調器，NavigationStack(path:) + WatchStep enum 控制逐步導航 |
| WatchCalculatorView | WatchCalculatorView.swift | amount: Binding\<Int\>, currency, onConfirm | 3×4 數字計算機（純整數），幣別 badge + 千分位 + 單位 |
| WatchCategoryPickerView | WatchCategoryPickerView.swift | categories, onSelect | 分類列表選擇（圖示 + 名稱），點擊觸發 callback |
| WatchLedgerPickerView | WatchLedgerPickerView.swift | ledgers, selectedId, onSelect | 帳本列表選擇，點擊觸發 callback |
| WatchPayerPickerView | WatchPayerPickerView.swift | members, onSelect | 付款人列表選擇（群組帳本），點擊觸發 callback |
| WatchMemoOrSaveView | WatchMemoOrSaveView.swift | onSave, onMemo | 備註或儲存二選一（List 按鈕） |
| WatchMemoInputView | WatchMemoInputView.swift | memo: Binding\<String\>, onNext | 備註文字輸入 + 下一步按鈕 |
| WatchTimeOrSaveView | WatchTimeOrSaveView.swift | onSave, onAdjustTime | 時間或儲存二選一（List 按鈕） |
| WatchDatePickerView | WatchDatePickerView.swift | date: Binding\<Date\>, onSave | 日期與時間選擇 + 儲存按鈕 |

### Watch 導航結構（Wizard）

```
WatchAddExpenseView（NavigationStack root = 帳本列表）
├─ .calculator: WatchCalculatorView       ← 3×4 數字鍵盤
├─ .category: WatchCategoryPickerView     ← 分類選擇
├─ .payer: WatchPayerPickerView           ← 付款人（群組帳本限定）
├─ .memoOrSave: WatchMemoOrSaveView       ← 儲存 / 輸入備註
├─ .memo: WatchMemoInputView              ← 備註輸入
├─ .timeOrSave: WatchTimeOrSaveView       ← 儲存 / 調整時間
└─ .time: WatchDatePickerView             ← 時間選擇 → 儲存

流程：帳本 → 計算機 → 分類 → [付款人] → 備註或儲存 → [備註] → 時間或儲存 → [時間] → 儲存
儲存後 path.removeAll() pop 回帳本列表 + 成功動畫
```

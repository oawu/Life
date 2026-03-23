# iOS View 元件清單

所有 View 的檔案路徑、職責、參數、導航關係。

---

## 根層級

| View | 檔案 | 說明 |
|------|------|------|
| LifeApp | LifeApp.swift | App 入口，依 isAuthenticated 切換 LoginView / HomeView |
| LoginView | Views/LoginView.swift | 登入頁，Apple Sign In + 開發者登入 |
| HomeView | Views/HomeView.swift | 主畫面 TabView（記帳 + 個人） |
| ProfileView | Views/ProfileView.swift | 個人頁，顯示用戶資訊 + 登出 |

## 記帳功能群組（Views/Expense/）

### 核心

| View | 檔案 | 參數 | 說明 |
|------|------|------|------|
| AddExpenseView | AddExpenseView.swift | store: ExpenseStore | Tab 1 主畫面，整合所有記帳元件 |
| CalculatorView | CalculatorView.swift | engine: CalculatorEngine | 4×4 計算機（金額輸入） |
| ExpenseDetailFields | ExpenseDetailFields.swift | memo, date, locationService | 備註 + 日期 + 位置 |
| ExpenseListView | ExpenseListView.swift | store: ExpenseStore | 開銷列表（按日期分組） |

### 帳本

| View | 檔案 | 參數 | 呈現方式 |
|------|------|------|----------|
| LedgerSwitcher | LedgerSwitcher.swift | ledgers, selectedId, onSettingsTapped? | 嵌入 AddExpenseView 頂部 |
| LedgerSettingsView | LedgerSettingsView.swift | store: ExpenseStore | push 從 AddExpenseView |
| LedgerEditView | LedgerEditView.swift | mode: Mode, onSave | sheet |
| LedgerDetailView | LedgerDetailView.swift | store: ExpenseStore, ledgerId: String | push 從 LedgerSettingsView |
| JoinLedgerView | JoinLedgerView.swift | onJoined: (Ledger) -> Void | sheet |

**LedgerEditView.Mode**：
- `.add` — 建立群組帳本
- `.editPersonal(Ledger)` — 編輯個人帳本名稱
- `.editGroup(Ledger)` — 編輯群組帳本名稱

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

---

## 導航關係圖

```
LoginView ─────────────────────────────────────────── 認證成功 ──→ HomeView

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
│  ├─ push: CategorySettingsView
│  │         └─ sheet: CategoryEditView
│  └─ push: LedgerSettingsView
│            ├─ sheet: LedgerEditView(.add)          ← 自己建立
│            ├─ sheet: JoinLedgerView                ← 掃碼加入
│            ├─ sheet: LedgerEditView(.editPersonal) ← 個人帳本
│            ├─ push: RecurringExpenseListView        ← 個人帳本固定開銷
│            │         └─ sheet: RecurringExpenseEditView
│            └─ push: LedgerDetailView               ← 群組帳本
│                     ├─ sheet: LedgerEditView(.editGroup)
│                     └─ push: RecurringExpenseListView
│                               └─ sheet: RecurringExpenseEditView
│
└─ Tab 2: ProfileView
```

**符號**：
- `push` = NavigationStack push（有返回按鈕）
- `sheet` = Modal sheet（有取消/關閉按鈕）
- `嵌入` = 直接嵌在父 View 中（非導航）

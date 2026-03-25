# iOS App 架構總覽

## 技術棧

| 項目 | 技術 |
|------|------|
| 語言 | Swift 5.9+ |
| UI 框架 | SwiftUI（iOS 17.0+） |
| 本地儲存 | SwiftData（VersionedSchema + MigrationPlan） |
| 狀態管理 | `@Observable`（Observation framework） |
| 專案管理 | XcodeGen（`project.yml` → `.xcodeproj`） |
| Target | Life（iOS）、LifeWatch（watchOS）、LifeWidget |
| 環境 | Local / Beta / Prod（xcconfig 切換） |

## 專案結構

```
ios/
├── Shared/                  # 兩個 target 共用
│   ├── Models/              # Expense, Ledger, ExpenseCategory, Currency, RecurringExpense
│   └── Extensions/          # Color+Hex 等跨平台擴展
├── Life/                    # 主 App
│   ├── LifeApp.swift        # App 入口（含 ModelContainer 初始化）
│   ├── Environment.swift    # 環境設定（API URL、isDev 判斷）
│   ├── Models/
│   │   ├── CategoryIcon.swift     # 圖示群組（僅 Life 使用）
│   │   ├── Persistence/           # SwiftData @Model 類別
│   │   │   ├── LifeSchema.swift          # VersionedSchema + MigrationPlan
│   │   │   ├── GuestExpense.swift        # 訪客開銷（純本地）
│   │   │   ├── CachedLedger.swift        # 帳本快取
│   │   │   ├── CachedCategory.swift      # 分類快取
│   │   │   ├── CachedExpense.swift       # 開銷快取（含離線未同步）
│   │   │   ├── CachedMember.swift        # 成員快取
│   │   │   ├── CachedRecurringExpense.swift  # 固定開銷快取
│   │   │   └── CachedSettlement.swift    # 結算紀錄快取
│   │   └── API/                   # API Response 解碼模型
│   │       ├── StateResponse.swift       # GET /api/state 回應
│   │       └── CRUDResponses.swift       # CRUD API 回應
│   ├── Services/            # 狀態管理、API、工具服務
│   └── Views/               # UI 畫面
│       ├── LaunchView.swift
│       ├── LoginPromptView.swift
│       ├── GuestProfileView.swift
│       ├── HomeView.swift
│       ├── ProfileView.swift
│       ├── Profile/         # 個人頁面相關
│       └── Expense/         # 記帳功能群組
├── LifeWatch/               # watchOS App（快速記帳）
│   ├── Services/            # WatchExpenseStore, WatchLocationService, WatchSessionManager
│   └── Views/               # Watch UI 畫面
├── LifeWidget/              # Widget Extension（待開發）
├── Config/                  # 環境 xcconfig
└── project.yml              # XcodeGen 設定（Life + LifeWatch 皆引用 Shared）
```

## App 啟動流程

```
LifeApp
├─ AuthManager.init() → checkExistingToken()
│  ├─ 有 token → GET /api/auth/me 驗證
│  │  ├─ 成功 → authState = .authenticated
│  │  └─ 失敗 → 清除 token → authState = .guest
│  └─ 無 token → authState = .guest
│
├─ .launching → LaunchView（品牌 Logo，等待 token 檢查完成）
├─ .guest → HomeView（訪客模式，可用個人帳本記帳）
└─ .authenticated → HomeView（完整功能）
```

**AuthState 狀態機**：
- `.launching`：App 啟動，正在檢查 token
- `.guest`：未登入，可使用個人帳本記帳、分類等基本功能
- `.authenticated`：已登入，完整功能（API-first + 本地快取）

**狀態轉換處理**（LifeApp.handleAuthStateChange）：
- `.authenticated` → `.guest`（登出）：`dataManager.clearAllCache()` → `expenseStore.reload()` → Watch sync
- `.guest` / `.launching` → `.authenticated`（登入）：`expenseStore.initAfterLogin(guestExpenses:)` → Watch sync

**自動狀態重整**：
- App 回前景（`scenePhase == .active`）：`syncOfflineExpenses()` + `refreshState()`
- 網路恢復（`isOnline false → true`）：`syncOfflineExpenses()` + `refreshState()`

## 導航結構

```
LifeApp
├─ .launching → LaunchView（品牌 Logo）
└─ .guest / .authenticated → HomeView（TabView）
   │
   ├─ Tab 1：記帳（NavigationStack）
   │  └─ AddExpenseView
   │     ├─ [明細] → push ExpenseListView
   │     │  ├─ 開銷行 → push ExpenseDetailView
   │     │  │  └─ [編輯] → sheet ExpenseEditView
   │     │  ├─ 結算紀錄 → push SettlementDetailView
   │     │  └─ [統計] → push ExpenseChartView
   │     ├─ [分類設定] → push CategorySettingsView
   │     │  └─ 分類行 → sheet CategoryEditView
   │     └─ [帳本設定] → push LedgerSettingsView
   │        ├─ [＋新增帳本]（訪客 → LoginPromptView sheet）
   │        │  ├─ 自己建立 → sheet LedgerEditView(.add)
   │        │  └─ 掃碼加入 → sheet JoinLedgerView
   │        ├─ 個人帳本 → sheet LedgerEditView(.editPersonal)
   │        │  └─ 固定開銷 → push RecurringExpenseListView
   │        └─ 群組帳本 → push LedgerDetailView
   │           ├─ [編輯] → sheet LedgerEditView(.editGroup)
   │           └─ 固定開銷 → push RecurringExpenseListView
   │
   └─ Tab 2：個人（NavigationStack）
      ├─ .authenticated → ProfileView
      │  ├─ 頭像/「更改」→ confirmationDialog → sheet ImagePickerView
      │  ├─ 名稱 → inline TextField 編輯
      │  └─ [登出] → alert 確認 → LifeApp onChange 重設資料
      └─ .guest → GuestProfileView（品牌展示 + Apple Sign In）

LifeWatch（獨立 App）
└─ WatchAddExpenseView（主表單，捲動 List）
   ├─ 帳本 → push WatchLedgerPickerView
   ├─ 金額 → push WatchAmountInputView
   ├─ 分類 → push WatchCategoryPickerView
   ├─ 付款人 → push WatchPayerPickerView（群組帳本）
   ├─ 備註 → WatchMemoInputView（內嵌於主表單）
   └─ 時間 → push WatchDatePickerView
```

## 狀態管理

| 物件 | 類型 | 說明 |
|------|------|------|
| `AuthManager` | @Observable | 全 App（.environment 注入），AuthState 狀態機、JWT、用戶資訊 |
| `NetworkMonitor` | @Observable | 全 App（.environment 注入），NWPathMonitor 偵測網路狀態。DEBUG 模式提供 `forceOffline` flag 模擬離線 |
| `DataManager` | @MainActor @Observable | SwiftData CRUD，Guest 開銷 + Cached* 快取管理 |
| `ExpenseStore` | @MainActor @Observable | 帳本、分類、開銷的業務邏輯（API 呼叫 + DataManager 快取） |
| `CalculatorEngine` | @Observable | AddExpenseView 計算機運算邏輯 |
| `LocationService` | @Observable | AddExpenseView 定位與反向地理編碼 |
| `PhoneSessionManager` | class（非 MainActor） | WCSession iPhone 端，MainActor 隔離存取 ExpenseStore |
| `WatchExpenseStore` | @Observable | Watch 端帳本 + 分類 + 開銷暫存 |
| `WatchLocationService` | @Observable | Watch 端定位與反向地理編碼 |
| `WatchSessionManager` | class | WCSession Watch 端（接收資料、回傳開銷） |

### 資料流（Guest 模式）

```
GuestExpense（SwiftData）
  ↕ DataManager.addGuestExpense / fetchGuestExpenses
ExpenseStore
├─ ledgers: [Ledger]              ← 1 本隱含個人帳本
├─ categories: [ExpenseCategory]  ← 靜態預設（ExpenseCategory.defaults，不可編輯）
└─ expenses: [Expense]            ← 從 GuestExpense 轉換
```

### 資料流（Authenticated 模式）

```
Server（API）
  ↕ ExpenseStore（API 呼叫 + 結果快取）
Cached*（SwiftData 快取）
  ↕ DataManager 映射 Cached* → ViewModel struct
ExpenseStore（對 View 層的 API）
├─ ledgers: [Ledger]              ← DataManager.fetchCachedLedgers()
├─ currentLedgerId: String        ← 目前選取的帳本
├─ categories: [ExpenseCategory]  ← computed，代理到 currentLedger.categories
├─ expenses: [Expense]            ← computed，代理到 currentLedger.expenses
├─ isGroupLedger: Bool            ← computed
├─ currentMembers: [LedgerMember] ← computed
└─ currentCurrency: Currency      ← computed
```

各 View 透過 `store` 存取資料，不持有獨立副本。切換帳本時 `categories`/`expenses` 自動切換。

### @MainActor 隔離

`DataManager` 和 `ExpenseStore` 皆標記 `@MainActor`，確保 SwiftData `ModelContext` 的線程安全。`PhoneSessionManager` 因 WCSession delegate 在背景線程執行，不標記 `@MainActor`，改用 `Task { @MainActor [expenseStore] in }` 存取 MainActor-isolated 屬性。

## 環境設定

| 環境 | API URL | Bundle ID |
|------|---------|-----------|
| Local | `http://local-api-life.iwi.tw` | `tw.iwi.life.beta` |
| Beta | `https://beta-api-life.iwi.tw` | `tw.iwi.life.beta` |
| Prod | `https://api-life.iwi.tw` | `tw.iwi.life` |

`AppEnvironment.isLocal` 控制開發模式功能（如開發者登入按鈕）。

## 權限

| 權限 | 用途 | Info.plist Key |
|------|------|----------------|
| 位置（使用中） | 記錄開銷發生地點 | NSLocationWhenInUseUsageDescription |
| 相機 | 掃描帳本邀請碼 QR Code 及拍攝大頭照 | NSCameraUsageDescription |
| 相簿 | 選擇大頭照 | NSPhotoLibraryUsageDescription |
| Apple Sign In | 登入 | Entitlements |

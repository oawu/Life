# iOS App 架構總覽

## 技術棧

| 項目 | 技術 |
|------|------|
| 語言 | Swift 5.9+ |
| UI 框架 | SwiftUI（iOS 17.0+） |
| 狀態管理 | `@Observable`（Observation framework） |
| 專案管理 | XcodeGen（`project.yml` → `.xcodeproj`） |
| Target | Life（iOS）、LifeWatch（watchOS）、LifeWidget |
| 環境 | Local / Beta / Prod（xcconfig 切換） |

## 專案結構

```
ios/
├── Life/                    # 主 App
│   ├── LifeApp.swift        # App 入口
│   ├── Environment.swift    # 環境設定（API URL、isDev 判斷）
│   ├── Models/              # 資料模型
│   ├── Services/            # 狀態管理、API、工具服務
│   └── Views/               # UI 畫面
│       ├── LoginView.swift
│       ├── HomeView.swift
│       ├── ProfileView.swift
│       └── Expense/         # 記帳功能群組
├── LifeWatch/               # watchOS App（待開發）
├── LifeWidget/              # Widget Extension（待開發）
├── Config/                  # 環境 xcconfig
└── project.yml              # XcodeGen 設定
```

## App 啟動流程

```
LifeApp
├─ AuthManager.init() → 檢查 Keychain 中的 JWT
│  ├─ 有 token → GET /api/auth/me 驗證
│  │  ├─ 成功 → isAuthenticated = true
│  │  └─ 失敗 → 清除 token
│  └─ 無 token → 等待登入
│
├─ isAuthenticated = true → HomeView
└─ isAuthenticated = false → LoginView
```

## 導航結構

```
LifeApp
├─ LoginView（未登入）
│  ├─ Sign In with Apple
│  └─ 開發者登入（LOCAL 限定）
│
└─ HomeView（已登入，TabView）
   │
   ├─ Tab 1：記帳（NavigationStack）
   │  └─ AddExpenseView
   │     ├─ [紀錄] → push ExpenseListView
   │     ├─ [分類設定] → push CategorySettingsView
   │     │  └─ 分類行 → sheet CategoryEditView
   │     └─ [帳本設定] → push LedgerSettingsView
   │        ├─ [＋新增帳本] → confirmationDialog
   │        │  ├─ 自己建立 → sheet LedgerEditView(.add)
   │        │  └─ 掃碼加入 → sheet JoinLedgerView
   │        ├─ 個人帳本 → sheet LedgerEditView(.editPersonal)
   │        │  └─ 固定開銷 → push RecurringExpenseListView
   │        └─ 群組帳本 → push LedgerDetailView
   │           ├─ [編輯] → sheet LedgerEditView(.editGroup)
   │           └─ 固定開銷 → push RecurringExpenseListView
   │
   └─ Tab 2：個人（NavigationStack）
      └─ ProfileView
         └─ [登出] → 清除 token → 返回 LoginView
```

## 狀態管理

| 物件 | 類型 | 作用範圍 | 說明 |
|------|------|----------|------|
| `AuthManager` | @Observable | 全 App | 登入狀態、JWT、用戶資訊 |
| `ExpenseStore` | @Observable | Tab 1 | 帳本、分類、開銷（所有記帳資料） |
| `CalculatorEngine` | @Observable | AddExpenseView | 計算機運算邏輯 |
| `LocationService` | @Observable | AddExpenseView | 定位與反向地理編碼 |

### 資料流

```
ExpenseStore
├─ ledgers: [Ledger]           ← 所有帳本（含分類、開銷）
├─ currentLedgerId: String     ← 目前選取的帳本
├─ categories: [ExpenseCategory]  ← computed，代理到 currentLedger.categories
├─ expenses: [Expense]            ← computed，代理到 currentLedger.expenses
├─ isGroupLedger: Bool            ← computed
├─ currentMembers: [LedgerMember] ← computed
└─ currentCurrency: Currency      ← computed
```

各 View 透過 `store` 存取資料，不持有獨立副本。切換帳本時 `categories`/`expenses` 自動切換，現有 View 無需修改。

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
| 相機 | 掃描帳本邀請碼 QR Code | NSCameraUsageDescription |
| Apple Sign In | 登入 | Entitlements |

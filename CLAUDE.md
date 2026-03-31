# Life 專案指南

本文件供 Claude 及開發者快速了解專案架構。編碼規範請見 `.claude/rules/`（自動載入）。

---

## 專案概述

Life 是一個 Web 應用服務（含 App 生態）。

**主要功能：** 記帳與財務管理（個人 / 群組拆帳）

### 文件導讀

| 文件 | 定位 | 適合場景 |
|------|------|----------|
| CLAUDE.md | 入口索引 | 快速了解專案結構、功能清單 |
| docs/architecture.md | 架構總覽 | 系統運作方式、資料流動、技術棧 |
| docs/ios/overview.md | iOS 架構 | 導航結構、狀態管理、技術棧 |
| docs/ios/features.md | iOS 功能 | 所有功能模組詳述、操作流程、後端需求 |
| docs/ios/data-models.md | iOS 資料模型 | Client 模型 + 後端 Table 設計建議 |
| docs/ios/views.md | iOS View 清單 | 所有 View 的參數、職責、導航關係 |
| docs/backend/api-routes.md | API 路由 | 完整路由表 |
| docs/frontend/*.md | 前端參考 | 組件 API、頁面結構、UI 工具 |
| docs/backend/*.md | 後端參考 | ORM、路由、驗證、Controller |
| docs/worker/*.md | Worker 參考 | 架構總覽、模組說明 |
| .claude/rules/ | 編碼規範 | 自動載入，寫程式時遵守 |

---

## 資料夾結構

```
life/
├── frontend/          # 前端程式（Lalilo 框架）
│   ├── src/           # 原始碼（html/scss/js/model/tmpl/img/icon）
│   ├── cmd/           # 建構工具
│   └── dist/          # 編譯輸出
├── backend/           # 後端程式（Maple 框架）
│   ├── App/           # 應用程式碼（Controller、Middleware、Model、View）
│   ├── Router/        # 路由定義
│   ├── Config/        # 設定檔
│   ├── Migration/     # 資料庫遷移
│   ├── Public/        # Web 入口 + 靜態檔案
│   └── System/        # 框架核心（勿修改）
├── ios/               # iOS App（XcodeGen + SwiftUI + SwiftData）
│   ├── Life/          # 主 App（iPhone / iPad）
│   ├── LifeWatch/     # watchOS App
│   ├── LifeWidget/    # Widget Extension
│   ├── Shared/        # 共用 Models + Extensions（Life & Watch）
│   ├── Config/        # 環境設定（Local / Beta / Prod）
│   └── project.yml    # XcodeGen 設定（產生 .xcodeproj）
├── worker/            # Node.js Worker 常駐服務（pm2）
│   └── src/           # Job 調度、處理器、服務模組
├── work/              # 工作目錄（暫存）
├── docs/              # 專案文件
└── .claude/           # rules/（編碼規範）+ commands/（自訂指令）
```

---

## 組件命名空間

（待開發後補齊 window.Core 結構）

---

## 已完成功能

- Apple Sign In 登入（後端 API + iOS App）
- Auth 狀態機（AuthState: launching / guest / authenticated）
  - 訪客可記帳（純本地），群組帳本/分類管理/固定開銷/個人資料需登入
  - LaunchView：品牌 Logo，背景驗證 token 後自動切到 HomeView
  - LoginPromptView：可複用 sheet，接收 `message` 參數
  - GuestProfileView：Tab 2 訪客模式，品牌展示 + Apple Sign In
  - 備份提醒：訪客累積 10 筆開銷時 alert 提示登入
- API-first 同步架構（Server-authoritative）
  - Guest 模式：純本地 SwiftData（GuestExpense），靜態預設分類（不可編輯）
  - Authenticated 模式：API call → 成功 → 更新本地快取（Cached* models）
  - 離線：僅允許新增開銷（isSynced = false），其餘操作阻擋 → alert「無法連線」
  - Manifest Diff Sync：`GET /api/manifest` 回傳輕量版本清單，iOS 比對後只拉差異開銷
  - `POST /api/ledgers/:id/expenses/fetch`：批次取得指定開銷（每批 200 筆）
  - `GET /api/state`：Manifest 失敗時的 fallback 全量路徑
  - `POST /api/auth/init`：登入時上傳 Guest 開銷 → 回傳 metadata + uploadedExpenses（不含全量 expenses）
  - 登入同步提示：有 Guest 開銷時彈 alert 詢問「上傳」或「捨棄」，無開銷時靜默初始化
  - 登入轉換：initAfterLogin() → rebuildFromState → mergeExpenses → 清除 GuestExpense → refreshViaManifest
  - 登出轉換：clearAllCache() → reload()
  - 版本追蹤：`Ledger.version`（metadata 變更遞增）+ `Expense.version`（開銷更新遞增）
  - 同步進度 UI：SyncProgressOverlay（fetch > 50 筆時顯示進度條）
  - 離線同步：依帳本分組批次上傳，指數退避重試（1s → 2s，最多 3 次）
  - @MainActor 隔離：DataManager + ExpenseStore 標記 @MainActor 確保 SwiftData 線程安全
- iOS 記帳功能（計算機、分類選擇、位置記錄、帳本切換）
  - Tab 1 直接進入 AddExpenseView，「明細」push 到開銷列表
  - 儲存成功顯示金額「已儲存 $150」+ 打勾動畫
  - 開銷列表（ExpenseListView）：safeAreaInset LedgerSwitcher，滾動時漸變毛玻璃（iOS 18+）
  - 帳本切換（LedgerSwitcher）：頂部橫向滾動 pill，群組帳本顯示 PayerChips
  - 開銷詳情頁：金額 + 分類 + 位置地圖 + 編輯/刪除
  - 開銷編輯 Sheet：複用計算機/分類/付款人/詳細欄位，預填所有欄位
  - 統計圖表（ExpenseChartView）：月/年切換，環形圖 + 分類進度條
  - 下拉重新整理：開銷列表 / 統計圖表 / 開銷詳情皆支援，先同步離線開銷再拉取最新狀態
- 帳本管理（已串接後端 API）
  - 帳本設定頁 → 個人帳本（sheet 編輯）、群組帳本（push 詳情頁）
  - 建立群組帳本（POST /api/ledgers）：Hashids 從 ID 動態計算邀請碼（8 碼+）+ 預設分類
  - 掃碼加入（JoinLedgerView）：AVFoundation 掃 QR + 手動輸入邀請碼
  - 退出帳本：未結清攔截，已結清 → confirmationDialog → POST /api/ledgers/:id/leave
  - 帳本幣別：14 種預設幣別，已有開銷時不可變更
- 分類管理（已串接後端 API，訪客不可編輯）
  - CategorySettingsView：瀏覽、排序，訪客點擊 → alert「登入後可編輯」
  - CategoryEditView：兩步驟圖示選擇，自訂顏色（ColorPicker）
  - 「其他」分類（categoryId = null）：不可編輯/刪除/排序，永遠在最後
  - 刪除分類 → Server 級聯 Expense/RecurringExpense.categoryId → null
- 固定開銷管理（已串接後端 API）
  - RecurringExpenseListView + RecurringExpenseEditView
  - 排程：daily / weekly / monthly / yearly，月 29-31 日顯示橘色警告
- 拆帳功能（群組帳本，已串接後端 API）
  - 拆帳區塊：未結算開銷 → 人均分攤 → 貪婪配對 → 轉帳明細
  - 結清：POST /api/ledgers/:id/settle → 標記已結算 + 建立 Settlement 紀錄
  - 結算詳情頁：結算時間、操作者、轉帳明細快照
- 個人頁面（已串接 PUT /api/auth/me）
  - 頭像更換、名稱 inline 編輯、載具號碼（Code 128 條碼預覽）、登出
- Apple Watch 快速記帳（LifeWatch App）
  - Wizard 逐步導航：帳本 → 計算機 → 分類 → [付款人] → [備註] → [時間] → 儲存
  - WatchConnectivity：iPhone → Watch（帳本/分類/isLoggedIn/isOnline）；Watch → iPhone（開銷）
  - PhoneSessionManager 收到 Watch 開銷後呼叫 API 建立 + 更新快取
  - 訪客模式：Watch 帳本列表只顯示個人帳本
  - 離線提示：帳本列表底部 wifi.slash +「離線中」
- 本地持久化架構（SwiftData）
  - Guest：`GuestExpense`（categoryKey 識別分類）
  - Authenticated：`Cached*`（CachedLedger, CachedExpense, CachedCategory, CachedMember, CachedRecurringExpense, CachedSettlement）
  - `DataManager`（@MainActor）：Repository 層，Guest 方法 + Cached 快取方法
  - `ExpenseStore`（@MainActor）：業務邏輯層，依 auth 狀態切換 Guest / Authenticated 行為
  - `LifeSchema`：VersionedSchema（SchemaV1）+ LifeMigrationPlan
- 網路感知 + 離線模式
  - `NetworkMonitor`：NWPathMonitor 偵測網路狀態，`.environment` 注入
  - 已登入離線攔截：群組帳本操作、分類管理、個人資料 → alert「無法連線」
  - 離線新增開銷不攔截（isSynced = false），網路恢復時自動批次同步
- 後端 CRUD API（完整路由表見 docs/backend/api-routes.md）
  - 資料表：User, Ledger, LedgerMember, Category, Expense, RecurringExpense, Settlement（Migration 001-010）
  - State API（GET /api/state）：回傳用戶所有帳本完整資料
  - Auth Init API（POST /api/auth/init）：登入初始化 + 上傳 Guest 開銷
  - Category CRUD（POST/PUT/DELETE + sort）
  - Expense CRUD（POST/PUT/DELETE + batch）
  - RecurringExpense CRUD（POST/PUT/DELETE）
  - Ledger API（建立/查看/更新/加入/退出/成員/結算）
- Worker 常駐服務（Node.js + pm2）
  - CLI 執行：後端透過 HTTP 觸發 PHP CLI 命令（debounce / queue / timeout）
  - Job 調度引擎：並發控制、超時保護、重試機制（暫無任務類型）
  - 排程服務：每分鐘檢查，同日同任務防重複
    - `recurring-trigger`（每日 00:05）：檢查啟用的 RecurringExpense，依頻率自動建立 Expense
  - HTTP 端點：`/worker/notify`、`/worker/status`、`/exec/cli`
  - PHP Lib（Worker）：`Worker::cli()->maple('route')->exec()` / `fire()`
  - Config 共享：讀取 `backend/Config/Worker.php`（port 8700）

---

## 後端速查

### 資料模型

| Model | 表名 | 說明 |
|-------|------|------|
| User | User | 用戶（Apple Sign In 登入） |
| Ledger | Ledger | 帳本（personal / group） |
| LedgerMember | LedgerMember | 帳本成員（owner / member） |
| Category | Category | 分類（key 識別系統預設，categoryId=null 為「其他」） |
| Expense | Expense | 開銷（isSettled yes/no） |
| RecurringExpense | RecurringExpense | 固定開銷（isEnabled yes/no） |
| Settlement | Settlement | 結算紀錄 |

### Lib 工具

| Lib | 說明 |
|-----|------|
| Jwt | JWT 簽發與驗證（HS256 / RS256） |
| Hashids | ID 混淆編碼（minLength / salt / alphabet） |
| Worker | Worker 服務通訊（status / notify / cli） |

---

## 開發注意事項

### 測試登入（isDev）

非 Production 環境下，API `POST /api/auth/apple/callback` 支援 `isDev: true` 參數，以 email 模擬登入（跳過 Apple token 驗證）。iOS App 在 LOCAL 環境會顯示「開發者登入」按鈕。

### iOS `Environment` 命名衝突

iOS App 中 `Environment.swift` 內的 `enum Environment` 已重命名為 `enum AppEnvironment`，避免與 SwiftUI 的 `@Environment` 屬性包裝器衝突。引用環境設定時使用 `AppEnvironment.apiBaseURL` 等。

### CSS class 命名偏好

- 在不造成碰撞的前提下盡量精簡
- 偏好原生 HTML tag（`header`）取代自訂 class（`.section-header`）
- 子元素用短名：`.info`、`.arrow`、`.name`、`.count`

---

## 待開發

（待規劃後補齊）

---

## 參考文件

```
docs/
├── architecture.md              # 系統架構、技術棧、資料模型、資料流
├── frontend/
│   ├── pages.md                 # 頁面功能詳述
│   ├── components.md            # 通用組件
│   ├── ui.md                    # UI 組件
│   ├── helpers.md               # Helper 工具
│   ├── env.md                   # window.Env 環境變數
│   └── framework/               # Lalilo 框架（overview, el3, scss, js, model, asset, serve, build, deploy, flow）
├── backend/
│   ├── overview.md              # Maple 框架總覽
│   ├── api-routes.md            # 完整路由表
│   ├── router.md / controller.md / middleware.md / migration.md / valid.md / orm.md
│   └──                          # 路由、控制器、中介層、Migration、驗證、ORM
├── ios/
│   ├── overview.md              # iOS 架構、導航結構、狀態管理
│   ├── features.md              # iOS 功能模組、操作流程
│   ├── data-models.md           # iOS 資料模型、後端 Table 設計
│   └── views.md                 # iOS View 清單、參數、導航關係
├── postman/
│   ├── Life-API.postman_collection.json    # API Collection
│   ├── Life-Worker.postman_collection.json # Worker Collection
│   ├── Life-Local.postman_environment.json # 環境變數
│   └── README.md                # Postman 使用說明
├── test/
│   ├── scenarios.md             # 測試情境總表（75 個情境）
│   ├── api-tests.md             # 後端 API curl 測試腳本
│   ├── app-log-tests.md         # App log 驗證清單
│   ├── e2e-tests.md             # E2E 測試項目
│   ├── integration-tests.md     # 模擬器 + 後端整合測試
│   └── mcp-setup.md             # iOS 模擬器 MCP 自動化設定
└── worker/
    ├── overview.md              # Worker 架構總覽、觸發流程、Config 共享
    ├── modules.md               # 逐模組 API 說明
    └── setup.md                 # 安裝、部署、pm2 管理

.claude/rules/                   # 編碼規範（自動載入）
├── coding-conventions.md        # 通用規範（if 大括號、命名、early return）
├── el3-template.md              # El3 語法速查 + 常見錯誤
├── scss-conventions.md          # SCSS 規範
├── js-conventions.md            # JS 通用規範（Icon、PageRedirect）
├── vuejs-conventions.md         # Vue 組件規範（命名、結構、_prepare）
├── design-standards.md          # 視覺設計 + iOS 色彩
├── php-conventions.md           # PHP 後端規範 + Docker 執行
├── swift-conventions.md         # Swift 開發規範（縮排）
└── git-conventions.md           # Git 開發規範（--no-ff）
```

- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines)

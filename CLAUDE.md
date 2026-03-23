# Life 專案指南

本文件供 Claude 及開發者快速了解專案架構。編碼規範請見 `.claude/rules/`（自動載入）。

---

## 專案概述

Life 是一個 Web 應用服務（含 App 生態）。

**主要功能：** （待定義）

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
├── ios/               # iOS App（XcodeGen + SwiftUI）
│   ├── Life/          # 主 App（iPhone / iPad）
│   ├── LifeWatch/     # watchOS App
│   ├── LifeWidget/    # Widget Extension
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
- iOS 記帳功能（純記憶體儲存，含計算機、分類選擇、位置記錄）
  - 登入後直接進入新增開銷頁面（Tab 1），「紀錄」按鈕 push 到開銷列表
  - 帳本切換（LedgerSwitcher）：頂部橫向滾動 pill，支援個人帳本 + 群組帳本
    - 切換帳本自動替換分類、清空已選分類
    - 群組帳本顯示付款人選擇器（PayerChips），預設「我」
    - ExpenseStore 以 computed property 代理 `categories`/`expenses` 到 currentLedger，現有分類相關 View 無需修改
  - 帳本管理（LedgerSettingsView + LedgerEditView + LedgerDetailView）：
    - LedgerSwitcher 尾端齒輪按鈕進入帳本設定
    - 帳本設定頁：個人帳本（點擊 sheet 編輯名稱）、群組帳本可排序（點擊 push 到詳情頁）
    - 新增帳本：confirmationDialog 二選一（自己建立 / 掃碼加入）
    - 帳本編輯 Sheet：三種 mode（add / editPersonal / editGroup），只編輯名稱
    - 帳本詳情頁（LedgerDetailView）：邀請碼卡片（複製 + toast）、QR Code、成員列表、刪除
    - 邀請碼：6 碼（#開頭），25 字元集（排除相似字），建立時自動生成
    - 掃碼加入（JoinLedgerView）：AVFoundation 相機掃 QR + 手動輸入邀請碼，mock 加入
    - 刪除群組帳本（確認對話框），刪除當前帳本自動切回個人帳本
  - 分類設定頁面（CategorySettingsView）：瀏覽、排序分類，頂部虛線新增按鈕
    - 系統預設「其他」分類：不可編輯、不可刪除、不可排序，永遠在最後
    - 刪除分類時，所屬開銷與固定開銷自動歸類到「其他」
  - 分類編輯 Sheet（CategoryEditView）：新增/編輯/刪除分類（名稱、圖示、顏色），支援自訂顏色（彩球 ColorPicker）
    - 圖示選擇器為兩步驟：先選群組（3×3），再選圖示（6 欄），選後自動返回群組列表
    - 新增模式預設無圖示（顯示 questionmark），須選擇圖示才能儲存
  - 固定開銷管理（RecurringExpenseListView + RecurringExpenseEditView）：
    - 個人帳本設定頁、群組帳本詳情頁皆有入口
    - 列表頁：顯示金額、排程描述、備註、付款人（群組），左滑刪除，右上角新增
    - 編輯 Sheet：複用 CalculatorView、CategoryGridView、PayerChips、ExpenseDetailFields（隱藏日期）
    - 排程選擇（frequencyCard）：每天 / 每週 / 每月 / 每年，新增時不預選
    - 每月 29-31 日、每年特殊日期顯示橘色警告
    - RecurringFrequency enum：daily / weekly(dayOfWeek) / monthly(dayOfMonth) / yearly(month, day)
    - Ledger 新增 `recurringExpenses` 欄位，ExpenseStore 代理 + CRUD 方法
    - 成員移除時級聯刪除對應的固定開銷

---

## 後端速查

### 資料模型

| Model | 表名 | 說明 |
|-------|------|------|
| User | User | 用戶（支援 Google / Apple 登入） |

### Lib 工具

| Lib | 說明 |
|-----|------|
| Jwt | JWT 簽發與驗證（HS256 / RS256） |

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
└── worker/
    └── overview.md              # Worker 架構總覽

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

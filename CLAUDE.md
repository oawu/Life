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
  - 分類設定頁面（CategorySettingsView）：瀏覽、排序、刪除分類，常駐編輯模式，頂部虛線新增按鈕
  - 分類編輯 Sheet（CategoryEditView）：新增/編輯分類（名稱、圖示、顏色），支援自訂顏色（彩球 ColorPicker）

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

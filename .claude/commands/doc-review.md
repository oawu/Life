# 文件整理與審查

全面審查專案文件的一致性與完整性，確保所有文件反映目前的程式碼狀態。根據差異程度自動決定處理深度——小幅差異直接修正，過時架構整段改寫。

## 三層資訊架構

| 層級 | 檔案 | 定位 |
|------|------|------|
| 1. 永遠載入 | `CLAUDE.md` | 精簡入口索引 + 開發注意事項（~200 行） |
| 2. 自動載入 | `.claude/rules/` | 編碼規範（僅修正錯誤，不大改） |
| 3. 按需查閱 | `docs/` | 深度參考文件（準確且最新） |

## 步驟

### 1. 蒐集現況

使用 Agent（Explore）並行讀取原始碼，掌握專案最新狀態：

- `backend/Router/Main.php` + `Cli.php` — 路由
- `backend/App/Model/*.php` — 資料模型、enum const、關聯
- `backend/App/Lib/*.php` — Lib 工具
- `backend/Migration/*.php` — 資料表結構
- `frontend/src/model/*.js` — 前端頁面資源清單
- `worker/src/routes/main.js` — Worker HTTP 路由
- `ios/Life/**/*.swift` — iOS App 原始碼（Views、Models、Services）

### 2. 比對文件與原始碼

逐一檢查以下文件，找出**過時或遺漏**的內容，並標記嚴重度：

| 文件 | 檢查重點 |
|------|----------|
| `CLAUDE.md` | 組件命名空間（`window.Core`）、Model 表格、已完成功能、參考文件索引 |
| `docs/architecture.md` | 系統架構圖、技術棧表格、資料模型關係、關鍵資料流 |
| `docs/backend/overview.md` | 目錄結構、Lib 說明 |
| `docs/backend/api-routes.md` | API 路由表是否完整 |
| `docs/worker/overview.md` | HTTP 端點表、目錄結構 |
| `docs/frontend/pages.md` | 頁面功能描述 |
| `docs/ios/overview.md` | iOS 導航結構、狀態管理 |
| `docs/ios/features.md` | iOS 功能模組、操作流程 |
| `docs/ios/data-models.md` | iOS 資料模型、後端 Table 設計 |
| `docs/ios/views.md` | iOS View 清單、參數、導航關係 |
| `.claude/rules/*.md` | 編碼規範（僅修正錯誤） |

嚴重度分級：

| 嚴重度 | 定義 | 範例 |
|--------|------|------|
| Critical | 描述已被取代的架構 | 舊架構 vs 新架構 |
| High | 文件間直接矛盾 | controller.md vs php-conventions.md |
| Medium | 遺漏新功能文件 | 新模組未記錄 |
| Low | 措辭不精確、連結失效 | 方法名稱錯誤 |

### 3. 執行修正

依嚴重度由高到低，分批處理：

1. **Quick Fix** — 單行修正（API 前綴、URL、措辭）
2. **深度改寫** — 整段或整份重寫（過時架構描述）
3. **新增區段** — 補齊遺漏的功能文件
4. **入口更新** — CLAUDE.md 結構調整

改寫原則：

- 以原始碼為唯一事實來源
- 過時檔案引用替換為新對應
- CLAUDE.md 控制在 ~200 行，詳細內容移至 `docs/`
- `.claude/rules/` 僅修正錯誤或新增必要規範，不做大幅改寫

### 4. 指令與知識同步

**指令同步** — 檢查並更新 `.claude/commands/` 的路由表與範圍：

| 指令 | 更新重點 |
|------|----------|
| `save-commit.md` | 「判斷更新位置」路由表是否涵蓋所有文件 |
| `doc-review.md` | Step 1 原始碼清單、Step 2 比對表 |
| `project-report.md` | 程式碼統計是否涵蓋新目錄 |
| `start.md` | URL、port、啟動指令 |

**知識遷移** — 檢查 `MEMORY.md` 是否有通用知識應遷入專案文件：

- 穩定的開發慣例 → `CLAUDE.md`「開發注意事項」
- 編碼規範 → `.claude/rules/`
- 架構知識 → `docs/`

遷移後清理 `MEMORY.md`，僅保留無法放入專案文件的項目。

### 5. 交叉驗證

確認文件間的引用不矛盾：

- `CLAUDE.md` 的文件導讀表格 → 所有連結的文件實際存在
- `docs/architecture.md` 資料表 ↔ `Migration/*.php`
- Worker 端點表 ↔ `worker/src/routes/main.js`
- `MEMORY.md` 的文件清單 → 反映最新文件結構

每項標記 PASS / FAIL，FAIL 項立即修正。

### 6. 輸出摘要

```
## 變更摘要

| 嚴重度 | 檔案 | 變更 |
|--------|------|------|
| High | ... | ... |

## 驗證結果

| 項目 | 狀態 |
|------|------|
| API 路由一致性 | PASS |
| 資料表一致性 | PASS |
```

若所有文件均與原始碼一致，輸出「所有文件已是最新狀態」。

## 注意事項

- 只修改**文件**（`.md` 檔案），不修改程式碼
- 以原始碼為唯一事實來源（source of truth）
- 保持各文件現有的風格與格式
- 不新增不必要的文件
- 大量修改前先用 plan mode 列出完整改動清單，取得確認後再執行
- 改寫整份文件時使用 Write 工具，局部修正使用 Edit 工具
- 驗證步驟不可省略，文件間的交叉引用是最容易遺漏的問題

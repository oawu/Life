# 專案全面審查

深度檢視整個專案的程式碼品質、文件完整性與規範遵守度，產出結構化審查報告並執行修正。使用 plan mode 規劃，取得確認後執行。

## 目標

- 讓下一個 session 能快速 100% 了解專案架構、規範、流程、邏輯
- 發現程式碼中不符規範或潛在問題的寫法
- 補強文件遺漏，確保文件反映最新狀態
- 精簡 CLAUDE.md，搬移細節至 docs/
- 遷移 MEMORY.md 知識至專案文件

## 步驟

### 1. 全面閱讀原始碼

使用多個 Agent（Explore）並行讀取，完整掌握專案現況：

**後端（PHP）：**
- `backend/Router/*.php` — 所有路由定義
- `backend/App/Controller/Api/*.php` — 所有 API Controller
- `backend/App/Model/*.php` — 資料模型、enum const、關聯
- `backend/App/Lib/*.php` — Lib 工具
- `backend/App/Middleware/*.php` — 中介層
- `backend/Migration/*.php` — 最近 5 個 Migration

**前端（JS）：**
- `frontend/src/js/**/*.js` — 所有 JS 檔案
- `frontend/src/model/*.js` — Model（asset 載入清單）

**Worker（Node.js）：**
- `worker/src/**/*.js` — 所有 Worker 檔案

### 2. 程式碼品質審查

以 `.claude/rules/` 規範為準，逐檔檢查：

#### PHP 後端
- enum / 布林欄位是否定義 const（禁止硬編碼字串或數字）
- Controller 是否用 `Valid::check()` 驗證（禁止直接 `$_GET` / `Payload::getJson()` 手動取值）
- `transaction()` 內 `create()` / `save()` / `update()` 是否有 `?? error()` 保護
- `transaction()` 使用 `static function()` 而非 `function()`
- `use` 與 `class` 之間是否有空行
- 關聯式陣列 `=>` 是否對齊
- Plugin 欄位是否用 `getValue()` 判斷

#### JavaScript 前端
- setup() 區塊順序是否正確（引用→普通→響應式→計算→事件→模板輔助→私有→初始→回傳）
- 私有變數/函式是否加 `_` 前綴
- `console.log` / `console.error` 遺留（應改 Toastr 或移除）
- 是否使用 Icon 組件（禁止 inline SVG）
- 是否使用 PageRedirect（禁止直接 `window.location.href`）

#### Worker（Node.js）
- 重複程式碼（跨檔案共用常數、工具函式）
- `var` 使用（應改 `const` / `let`）
- 錯誤處理是否完整

#### SCSS
- iOS 系統色彩是否使用 CSS 自訂屬性（禁止舊式 `ios-color()` 函數）
- Dark Mode 屬性是否集中（不被其他屬性隔開）

### 3. 文件完整性檢查

比對原始碼與文件，找出不一致：

| 文件 | 檢查重點 |
|------|----------|
| `CLAUDE.md` | 組件命名空間、Model 表格、已完成功能、參考文件索引 |
| `docs/architecture.md` | 系統架構、資料模型、資料流 |
| `docs/backend/api-routes.md` | API 路由表是否完整 |
| `docs/backend/overview.md` | Model/Lib 說明 |
| `docs/worker/overview.md` | Worker 模組說明 |
| `docs/frontend/pages.md` | 頁面功能描述 |
| `docs/frontend/components.md` | 組件 API |
| `docs/frontend/ui.md` | UI 組件 API |

### 4. CLAUDE.md 精簡檢查

確保 CLAUDE.md 維持在 ~200 行以內：
- 詳細內容是否已搬至 `docs/`，CLAUDE.md 只留索引連結
- 是否有與 `.claude/rules/` 重複的規範內容
- 是否有過時的功能描述或路由列表

### 5. MEMORY.md 知識遷移

檢查 MEMORY.md 是否有內容應遷入專案文件：
- 穩定的開發慣例 → `.claude/rules/` 或 CLAUDE.md
- 架構知識 → `docs/`
- 遷移後清理，僅保留無法放入專案文件的項目（如待修正問題清單）

### 6. 產出審查計畫

使用 plan mode，產出結構化的審查報告：

```markdown
## 程式碼問題

### 高優先（應立即修正）
| 嚴重度 | 問題 | 位置 |
|--------|------|------|

### 中優先（建議修正）
| 嚴重度 | 問題 | 位置 |
|--------|------|------|

### 低優先（記錄供後續參考）
| 嚴重度 | 問題 | 位置 |
|--------|------|------|

## 文件問題
| 文件 | 問題 | 修正方式 |
|------|------|----------|

## CLAUDE.md 優化
| 區塊 | 現行 | 目標 | 動作 |
|------|------|------|------|

## MEMORY.md 遷移
| 內容 | 遷移目標 | 動作 |
|------|----------|------|

## 建議
- ...
```

### 7. 執行修正

取得確認後，依優先順序執行：

1. 文件數值錯誤修正（最高優先，避免誤導）
2. 文件補強與遺漏修正
3. CLAUDE.md 精簡（搬移至 docs/）
4. MEMORY.md 遷移
5. 高優先程式碼問題修正（若用戶同意）
6. 中低優先問題記錄至 MEMORY.md 待辦

## 注意事項

- 程式碼問題預設「僅記錄不修正」，除非用戶明確要求修正
- 文件修正以原始碼為唯一事實來源
- CLAUDE.md 控制在 ~200 行，詳細內容移至 `docs/`
- `.claude/rules/` 僅修正錯誤，不做大幅改寫
- 大量修改前必須用 plan mode 取得確認
- 修正完成後執行 `/review` 驗證，再用 `/save-commit` 提交

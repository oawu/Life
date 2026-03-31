# Postman Collection

Life 專案的 API 與 Worker 測試集合。

## 檔案清單

| 檔案 | 用途 |
|------|------|
| `Life-API.postman_collection.json` | API Collection |
| `Life-Worker.postman_collection.json` | Worker Collection |
| `Life-Local.postman_environment.json` | 環境變數（API + Worker 共用） |

## 環境變數

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `baseurl` | `http://local-api-life.iwi.tw/` | API Base URL |
| `workerurl` | `http://localhost:8700/` | Worker Base URL |
| `--token` | — | API 認證 JWT Token（登入後自動設定） |
| `--cli-token` | — | Worker CLI 認證 Token |
| `--ledger-id` | — | 帳本 ID（建立後自動設定） |
| `--category-id` | — | 分類 ID（建立後自動設定） |
| `--expense-id` | — | 開銷 ID（建立後自動設定） |
| `--recurring-expense-id` | — | 固定開銷 ID（建立後自動設定） |

---

## API Collection 結構

### Auth

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | Apple Sign In（isDev） | POST | `/api/auth/apple/callback` | — | 開發者登入，自動存 `--token` |
| 02 | 🔐 取得當前用戶 | GET | `/api/auth/me` | Bearer | — |
| 03 | 🔐 更新個人資料 | PUT | `/api/auth/me` | Bearer | name / carrierNumber |
| 04 | 🔐 登入初始化 | POST | `/api/auth/init` | Bearer | 帶 guest 開銷 |
| 05 | 🔐 登入初始化（無開銷） | POST | `/api/auth/init` | Bearer | 空開銷陣列 |

### State

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 🔐 取得完整狀態 | GET | `/api/state` | Bearer | 回傳所有帳本完整資料 |

### Manifest

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 🔐 取得 Manifest | GET | `/api/manifest` | Bearer | 版本清單 + metadata |
| 02 | 🔐 批次取得開銷 | POST | `/api/ledgers/{{--ledger-id}}/expenses/fetch` | Bearer | 指定 ID 批次取得（最多 200） |

### Ledger

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 🔐 建立群組帳本 | POST | `/api/ledgers` | Bearer | 自動存 `--ledger-id` |
| 02 | 🔐 取得帳本詳情 | GET | `/api/ledgers/{{--ledger-id}}` | Bearer | — |
| 03 | 🔐 更新帳本 | PUT | `/api/ledgers/{{--ledger-id}}` | Bearer | name / currency |
| 04 | 🔐 加入群組帳本 | POST | `/api/ledgers/join` | Bearer | inviteCode |
| 05 | 🔐 退出群組帳本 | POST | `/api/ledgers/{{--ledger-id}}/leave` | Bearer | — |
| 06 | 🔐 取得成員列表 | GET | `/api/ledgers/{{--ledger-id}}/members` | Bearer | — |
| 07 | 🔐 結算拆帳 | POST | `/api/ledgers/{{--ledger-id}}/settle` | Bearer | transfers[] |

### Category

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 🔐 建立分類 | POST | `/api/ledgers/{{--ledger-id}}/categories` | Bearer | 自動存 `--category-id` |
| 02 | 🔐 更新分類 | PUT | `/api/categories/{{--category-id}}` | Bearer | name / icon / color |
| 03 | 🔐 刪除分類 | DELETE | `/api/categories/{{--category-id}}` | Bearer | — |
| 04 | 🔐 排序分類 | PUT | `/api/ledgers/{{--ledger-id}}/categories/sort` | Bearer | categoryIds[] |

### Expense

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 🔐 建立開銷 | POST | `/api/ledgers/{{--ledger-id}}/expenses` | Bearer | 自動存 `--expense-id` |
| 02 | 🔐 批次建立開銷 | POST | `/api/ledgers/{{--ledger-id}}/expenses/batch` | Bearer | 離線同步用 |
| 03 | 🔐 更新開銷 | PUT | `/api/expenses/{{--expense-id}}` | Bearer | — |
| 04 | 🔐 刪除開銷 | DELETE | `/api/expenses/{{--expense-id}}` | Bearer | — |

### RecurringExpense

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 🔐 建立固定開銷 | POST | `/api/ledgers/{{--ledger-id}}/recurring-expenses` | Bearer | 自動存 `--recurring-expense-id` |
| 02 | 🔐 更新固定開銷 | PUT | `/api/recurring-expenses/{{--recurring-expense-id}}` | Bearer | — |
| 03 | 🔐 刪除固定開銷 | DELETE | `/api/recurring-expenses/{{--recurring-expense-id}}` | Bearer | — |

### Test

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | DB 重置 | POST | `/api/test/reset` | — | 僅限非 Production |
| 02 | DB 查詢 | POST | `/api/test/query` | — | 僅限 SELECT |

---

## Worker Collection 結構

### Worker

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | Worker 狀態 | GET | `/worker/status` | — | 查詢 Worker 運行狀態 |
| 02 | Worker 通知 | POST | `/worker/notify` | — | 觸發 Job Dispatcher |

### Exec

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 🔐 CLI 執行 | POST | `/exec/cli` | Bearer | 執行 PHP CLI 命令 |

---

## 使用方式

1. 匯入 Collection：Postman → Import → 選擇 `.json` 檔案
2. 匯入 Environment：Postman → Environments → Import → 選擇 `Life-Local.postman_environment.json`
3. 選擇環境：右上角下拉選「Life-Local」
4. 執行 `Auth > 01 | Apple Sign In（isDev）` 取得 token
5. 後續認證 API 會自動帶入 `--token`

### 建議測試順序

```
Auth 01（登入）→ Auth 04（初始化）→ State 01（完整狀態）→ Manifest 01（Manifest）
→ Ledger 01（建立帳本）→ Category 01（建立分類）→ Expense 01（建立開銷）
→ Manifest 02（批次取得開銷）
```

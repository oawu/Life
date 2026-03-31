# 系統架構

## 技術棧

| 層級 | 技術 | 說明 |
|------|------|------|
| 前端框架 | Lalilo | 靜態檔案產生器 |
| 前端 UI | Vue 3 CDN | Composition API |
| 模板引擎 | El3 | 縮排式 Vue template 語法 |
| 樣式 | SCSS + @oawu/scss | CSS 預處理器 |
| 後端框架 | Maple 9 | PHP 7.4，MVC + Active Record ORM |
| Worker | Node.js 18+ | pm2 常駐服務 |
| 資料庫 | MySQL | InnoDB, utf8mb4 |
| iOS App | SwiftUI | iOS 17+, watchOS 10+, XcodeGen |
| 容器 | Docker | 本機開發環境 |

---

## API 網址

| 環境 | 網址 |
|------|------|
| 本地 | `http://local-api-life.iwi.tw` |
| 線上測試 | `https://beta-api-life.iwi.tw` |
| 線上正式 | `https://api-life.iwi.tw` |

---

## 資料模型

### User（用戶）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| name | varchar(190) | 名稱 |
| email | varchar(190) | Email |
| avatar | text | 頭像 URL |
| googleId | varchar(190), UNIQUE | Google 登入 ID |
| appleId | varchar(190), UNIQUE | Apple 登入 ID |
| status | enum(active, disabled) | 狀態 |
| token | varchar(512) | JWT Token（伺服端比對用） |
| carrierNumber | varchar(10) | 載具號碼 |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

### Ledger（帳本）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| name | varchar(100) | 帳本名稱 |
| type | enum(personal, group) | 類型 |
| currency | varchar(3) DEFAULT 'TWD' | 幣別代碼 |
| version | int unsigned DEFAULT 1 | 狀態版本號（metadata 變更時遞增） |
| createdByUserId | int unsigned | 建立者 User ID |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

### LedgerMember（帳本成員）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| ledgerId | int unsigned | Ledger ID |
| userId | int unsigned | User ID |
| role | enum(owner, member) | 角色 |
| sort | int unsigned | 排序 |
| joinAt | datetime | 加入時間 |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- UNIQUE(ledgerId, userId)

### Category（分類）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| ledgerId | int unsigned | Ledger ID |
| key | varchar(50), nullable | 系統預設分類識別碼（如 breakfast） |
| name | varchar(50) | 分類名稱 |
| icon | varchar(50) | SF Symbol 圖示 |
| color | varchar(7) DEFAULT '#007AFF' | 色碼 #RRGGBB |
| sort | int unsigned DEFAULT 0 | 排序（ASC） |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- INDEX(ledgerId)
- `key` 用於 Guest → Authenticated 登入轉換時配對分類
- `categoryId = null` 代表「其他」分類，移除舊的 isSystemDefault 概念

### Expense（開銷）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| ledgerId | int unsigned | Ledger ID |
| categoryId | int unsigned, nullable | Category ID（null = 其他） |
| amount | int unsigned | 金額（整數） |
| memo | varchar(200) DEFAULT '' | 備註 |
| date | datetime | 消費日期時間 |
| latitude | decimal(10,7), nullable | 緯度 |
| longitude | decimal(10,7), nullable | 經度 |
| address | varchar(200), nullable | 地址 |
| isSettled | tinyint unsigned DEFAULT 0 | 是否已結算（0=否, 1=是） |
| paidByUserId | int unsigned, nullable | 付款人 User ID |
| createdByUserId | int unsigned | 建立者 User ID |
| version | int unsigned DEFAULT 1 | 版本號（更新時遞增） |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- INDEX(ledgerId)

### RecurringExpense（固定開銷）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| ledgerId | int unsigned | Ledger ID |
| categoryId | int unsigned, nullable | Category ID（null = 其他） |
| amount | int unsigned | 金額 |
| frequencyType | varchar(10) | 頻率類型 daily/weekly/monthly/yearly |
| frequencyValue | json, nullable | 頻率參數 |
| memo | varchar(200) DEFAULT '' | 備註 |
| isEnabled | tinyint unsigned DEFAULT 1 | 是否啟用（0=否, 1=是） |
| latitude | decimal(10,7), nullable | 緯度 |
| longitude | decimal(10,7), nullable | 經度 |
| address | varchar(200), nullable | 地址 |
| paidByUserId | int unsigned, nullable | 付款人 User ID |
| createdByUserId | int unsigned | 建立者 User ID |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- INDEX(ledgerId)

### Settlement（結算紀錄）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| ledgerId | int unsigned | Ledger ID |
| settledByUserId | int unsigned | 結算者 User ID |
| transfers | json, nullable | 轉帳明細快照 |
| currencySymbol | varchar(5) | 幣別符號 |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- INDEX(ledgerId)

---

## 資料流

### 同步架構（API-first + 本地快取）

採用 **Server-authoritative** 模式，Server 為唯一真實資料來源。iOS 端分為 Guest（純本地）和 Authenticated（API-first + 本地快取）兩種模式。

```
Guest 模式（未登入）
├─ 分類：靜態預設（hardcoded），以 key 識別（如 breakfast）
├─ 開銷：SwiftData 本地持久化（GuestExpense）
├─ 無帳本概念（隱含一本個人帳本）
└─ 無 API 呼叫

Authenticated 模式（已登入）
├─ 所有資料來自 Server，本地為 SwiftData 快取（Cached* models）
├─ CRUD：API call → 成功 → 更新本地快取
├─ 離線：僅允許新增開銷（isSynced = false），其餘操作阻擋
└─ 狀態重整：App 回前景、網路恢復時 Manifest Diff Sync（差異同步）
```

### 狀態重整流程（Manifest Diff Sync）

採用 manifest-based 差異同步：Server 回傳輕量 manifest（開銷 `"id-version|..."` 清單 + metadata），App 比對本地快取後只拉取差異，大幅降低頻寬。

**版本追蹤機制：**

| 欄位 | 所在表 | 用途 | 遞增時機 |
|------|--------|------|----------|
| `Ledger.version` | Ledger | 帳本 metadata 版本 | 帳本名稱/幣別變更、成員加入/退出、分類 CRUD/排序、固定開銷 CRUD、結算 |
| `Expense.version` | Expense | 開銷版本 | 開銷更新、結算標記 isSettled、分類刪除 cascade |

```
Client（iOS App）                                Server
    │                                              │
    │── 1. syncOfflineExpenses ─────────────────→  │  POST /api/ledgers/:id/expenses/batch
    │←─ 上傳結果（id + version）────────────────  │
    │                                              │
    │── 2. GET /api/manifest ──────────────────→  │
    │                                              │
    │←─ Manifest Response ─────────────────────  │
    │   · 每個帳本：version + metadata              │
    │   · expenses: "100-1|101-2|102-1"           │
    │                                              │
    │   3. 比對：                                   │
    │   ├─ 帳本 version 不同 → 重建 metadata        │
    │   ├─ Server 有、本地沒有的帳本 → 建立          │
    │   ├─ 本地有、Server 沒有的帳本 → 刪除          │
    │   └─ 逐帳本 diff expenses：                   │
    │       ├─ Server 有、本地沒有 → needFetch      │
    │       ├─ version 不同 → needFetch            │
    │       └─ 本地有、Server 沒有 → needDelete     │
    │                                              │
    │── 4. POST /ledgers/:id/expenses/fetch ──→  │  分批 200 筆
    │←─ 完整開銷資料 ─────────────────────────  │
    │                                              │
    │   5. mergeExpenses（增量合併）                 │
    │   6. reload()                                │
    └──────────────────────────────────────────────┘
```

**Fallback：** manifest 失敗時退回 `GET /api/state` 全量重建。

### CRUD 操作流程（已登入 + 有網路）

```
1. iOS 呼叫 ExpenseStore 方法（async throws）
2. ExpenseStore 發送 API 請求
3. Server 處理 → 回傳結果
4. 成功 → DataManager 更新本地快取
5. 失敗 → throw error → View 顯示錯誤 alert
```

### 離線開銷同步

```
離線新增開銷：
1. DataManager.addUnsyncedExpense() → isSynced = false
2. 網路恢復時 → ExpenseStore.syncOfflineExpenses()
3. 依帳本分組 → POST /api/ledgers/:id/expenses/batch → 批次上傳
4. 失敗時指數退避重試（1s → 2s，最多 3 次）
5. 成功 → DataManager.markExpensesSynced(localId, serverId, version)
6. 接著 refreshViaManifest() 差異拉取
```

### 登入轉換（Guest → Authenticated）

```
1. Apple Sign In → 取得 token
2. POST /api/auth/init（上傳 guest 開銷，帶 categoryKey）
3. Server：找到或建立個人帳本 + 預設分類 + 建立開銷
4. Response：帳本 metadata（不含 expenses）+ uploadedExpenses
5. rebuildFromState → mergeExpenses（上傳的開銷）→ 清除 GuestExpense
6. refreshViaManifest()（差異拉取其餘開銷）
```

### 登出轉換（Authenticated → Guest）

```
1. 清除所有 Cached* 快取
2. 清除 Keychain token
3. 回到 Guest 模式（空白）
```

**狀態重整時機：**
1. `guest → authenticated`（登入成功）→ `initAfterLogin()` → `refreshViaManifest()`
2. `scenePhase == .active`（App 回到前景）→ `refreshState()`（manifest diff）
3. `isOnline false → true`（網路恢復）→ `syncOfflineExpenses()` + `refreshState()`（manifest diff）

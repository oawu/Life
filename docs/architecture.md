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
| localId | varchar(36), nullable | Client UUID（同步配對用） |
| name | varchar(100) | 帳本名稱 |
| type | enum(personal, group) | 類型 |
| currency | varchar(3) | 幣別代碼（TWD / JPY 等） |
| inviteCode | varchar(6), UNIQUE, nullable | 邀請碼（群組帳本） |
| createdByUserId | int unsigned | 建立者 User ID |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- UNIQUE(createdByUserId, localId)

### LedgerMember（帳本成員）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| ledgerId | int unsigned | Ledger ID |
| userId | int unsigned | User ID |
| role | enum(owner, member) | 角色 |
| sort | int unsigned | 排序 |
| joinAt | datetime | 加入時間 |

- UNIQUE(ledgerId, userId)

### Category（分類）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| localId | varchar(36) | Client UUID |
| ledgerId | int unsigned | Ledger ID |
| name | varchar(50) | 分類名稱 |
| icon | varchar(50) | SF Symbol 圖示 |
| color | varchar(7) | 色碼 #RRGGBB |
| sort | int unsigned | 排序 |
| isSystemDefault | tinyint unsigned | 是否為系統預設 |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- UNIQUE(ledgerId, localId)

### Expense（開銷）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| localId | varchar(36) | Client UUID |
| ledgerId | int unsigned | Ledger ID |
| categoryId | int unsigned | Category ID |
| amount | int unsigned | 金額（整數） |
| memo | varchar(200) | 備註 |
| date | datetime | 消費日期時間 |
| latitude | decimal(10,7), nullable | 緯度 |
| longitude | decimal(10,7), nullable | 經度 |
| address | varchar(200), nullable | 地址 |
| isSettled | tinyint unsigned | 是否已結算 |
| paidByUserId | int unsigned, nullable | 付款人 User ID |
| createdByUserId | int unsigned | 建立者 User ID |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- UNIQUE(ledgerId, localId)

### RecurringExpense（固定開銷）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| localId | varchar(36) | Client UUID |
| ledgerId | int unsigned | Ledger ID |
| categoryId | int unsigned | Category ID |
| amount | int unsigned | 金額 |
| frequencyType | varchar(10) | 頻率類型 daily/weekly/monthly/yearly |
| frequencyValue | json, nullable | 頻率參數 |
| memo | varchar(200) | 備註 |
| isEnabled | tinyint unsigned | 是否啟用 |
| latitude | decimal(10,7), nullable | 緯度 |
| longitude | decimal(10,7), nullable | 經度 |
| address | varchar(200), nullable | 地址 |
| paidByUserId | int unsigned, nullable | 付款人 User ID |
| createdByUserId | int unsigned | 建立者 User ID |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

- UNIQUE(ledgerId, localId)

### Settlement（結算紀錄）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| ledgerId | int unsigned | Ledger ID |
| settledByUserId | int unsigned | 結算者 User ID |
| transfers | json, nullable | 轉帳明細快照 |
| currencySymbol | varchar(5) | 幣別符號 |
| createAt | datetime | 新增時間 |

- INDEX(ledgerId)

---

## 資料流

### 同步架構（Sync）

採用 **Push-then-Pull** 模式，Server-authoritative 衝突解決。

```
Client（iOS App）                          Server
    │                                        │
    ├─── Push（本地變更 → Server）──────────→│
    │    · 送出所有帳本 + 分類（upsert）       │
    │    · 送出 pending 開銷 + 固定開銷       │
    │    · 送出 deleted 清單                  │
    │                                        │
    │←── Push Response（serverId mapping）──│
    │    · 更新本地 serverId + syncStatus     │
    │    · 清除已同步的 deleted 記錄           │
    │                                        │
    ├─── Pull（lastSyncAt → Server）────────→│
    │                                        │
    │←── Pull Response（遠端資料）───────────│
    │    · 依 serverId 合併到本地             │
    │    · 更新 lastSyncAt                   │
    └────────────────────────────────────────┘
```

**同步時機：**
1. `guest → authenticated`（登入成功）
2. `scenePhase == .active`（App 回到前景）
3. `isOnline false → true`（網路恢復）

**去重機制：**
- Ledger：UNIQUE(createdByUserId, localId)
- Category / Expense / RecurringExpense：UNIQUE(ledgerId, localId)
- Push 時以 localId 做 upsert，避免重複建立

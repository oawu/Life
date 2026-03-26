# API 路由表

所有 API 路由前綴為 `/api`，經過 `Api` + `Cors` Middleware。

## 公開路由

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | auth/apple/callback | Api\Auth@appleCallback | Apple Sign In 回調 |
| POST | test/reset           | Api\Test@reset         | 測試 DB 重置（僅限非 Production） |
| POST | test/query           | Api\Test@query         | 測試 DB 查詢（僅限非 Production，只允許 SELECT） |

## 需認證路由

經過 `Auth` Middleware，需帶 `Authorization: Bearer <token>` header。

### Auth

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| GET | auth/me | Api\Auth@me | 取得當前用戶 |
| PUT | auth/me | Api\Auth@updateProfile | 更新個人資料（name / carrierNumber） |
| POST | auth/init | Api\Auth@init | 登入初始化（上傳 guest 開銷 + 回傳完整 state） |

### State

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| GET | state | Api\State@index | 取得完整 State（所有帳本 + 分類 + 開銷 + 固定開銷 + 結算紀錄） |

### Ledger（帳本）

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | ledgers | Api\Ledger@create | 建立群組帳本 |
| GET | ledgers/:id | Api\Ledger@show | 取得帳本詳情 |
| PUT | ledgers/:id | Api\Ledger@update | 更新帳本名稱/幣別 |
| POST | ledgers/join | Api\Ledger@join | 用邀請碼加入群組帳本 |
| POST | ledgers/:id/leave | Api\Ledger@leave | 退出群組帳本 |
| GET | ledgers/:id/members | Api\Ledger@members | 取得成員列表 |
| POST | ledgers/:id/settle | Api\Ledger@settle | 結算拆帳 |

### Category（分類）

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | ledgers/:id/categories | Api\Category@create | 建立分類 |
| PUT | categories/:id | Api\Category@update | 更新分類（name / icon / color） |
| DELETE | categories/:id | Api\Category@destroy | 刪除分類（級聯 Expense/RecurringExpense.categoryId → null） |
| PUT | ledgers/:id/categories/sort | Api\Category@sort | 排序分類 |

### Expense（開銷）

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | ledgers/:id/expenses | Api\Expense@create | 建立單筆開銷 |
| POST | ledgers/:id/expenses/batch | Api\Expense@batch | 批次建立開銷（離線同步用） |
| PUT | expenses/:id | Api\Expense@update | 更新開銷 |
| DELETE | expenses/:id | Api\Expense@destroy | 刪除開銷 |

### RecurringExpense（固定開銷）

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | ledgers/:id/recurring-expenses | Api\RecurringExpense@create | 建立固定開銷 |
| PUT | recurring-expenses/:id | Api\RecurringExpense@update | 更新固定開銷 |
| DELETE | recurring-expenses/:id | Api\RecurringExpense@destroy | 刪除固定開銷 |

---

## State API 詳細說明

### GET /api/state

回傳用戶所有帳本的完整資料。用於 App 回前景時重建本地快取。

**Response：**
```json
{
  "ledgers": [{
    "id": 1,
    "name": "個人",
    "type": "personal",
    "currency": "TWD",
    "inviteCode": null,
    "members": [{
      "id": 1,
      "userId": 1,
      "name": "小明",
      "role": "owner",
      "isCurrentUser": true
    }],
    "categories": [{
      "id": 10,
      "key": "breakfast",
      "name": "早餐",
      "icon": "sunrise",
      "color": "#FF9500",
      "sort": 0
    }],
    "expenses": [{
      "id": 100,
      "categoryId": 10,
      "amount": 150,
      "memo": "",
      "date": "2026-03-24 08:00:00",
      "latitude": null,
      "longitude": null,
      "address": null,
      "isSettled": false,
      "paidByUserId": null,
      "createdByUserId": 1
    }],
    "recurringExpenses": [{
      "id": 50,
      "categoryId": 10,
      "amount": 300,
      "frequencyType": "monthly",
      "frequencyValue": {"dayOfMonth": 1},
      "memo": "月租",
      "isEnabled": true,
      "latitude": null,
      "longitude": null,
      "address": null,
      "paidByUserId": null,
      "createdByUserId": 1
    }],
    "settlements": [{
      "id": 1,
      "settledByUserId": 1,
      "transfers": [{"fromUserId": 2, "fromName": "小華", "toUserId": 1, "toName": "小明", "amount": 500}],
      "currencySymbol": "$",
      "createAt": "2026-03-24 18:00:00"
    }]
  }]
}
```

- `categoryId = null` 表示「其他」分類
- `paidByUserId = null` 表示個人帳本（無付款人概念）

### POST /api/auth/init

登入後呼叫，上傳 guest 開銷，回傳完整 state。

**Request：**
```json
{
  "expenses": [
    {
      "categoryKey": "breakfast",
      "amount": 150,
      "memo": "",
      "date": "2026-03-24 08:00:00",
      "latitude": null,
      "longitude": null,
      "address": null
    }
  ]
}
```

**處理邏輯：**
1. 找用戶的個人帳本（`type = personal`）
2. 不存在 → 建立個人帳本 + owner 成員 + 預設分類（`Category::defaultPersonalCategories()`，帶 key）
3. 每筆 guest expense → 依 categoryKey 查找分類 → 找不到則 categoryId = null → 建立 Expense
4. 回傳完整 state（複用 State controller 的邏輯）

**Response：** 同 `GET /api/state` 格式。

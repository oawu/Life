# API 路由表

所有 API 路由前綴為 `/api`，經過 `Api` + `Cors` Middleware。

## 公開路由

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | auth/apple/callback | Api\Auth@appleCallback | Apple Sign In 回調 |

## 需認證路由

經過 `Auth` Middleware，需帶 `Authorization: Bearer <token>` header。

### Auth

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| GET | auth/me | Api\Auth@me | 取得當前用戶 |
| PUT | auth/me | Api\Auth@updateProfile | 更新個人資料（name / carrierNumber） |

### Sync

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | sync/push | Api\Sync@push | 推送本地變更到 Server |
| POST | sync/pull | Api\Sync@pull | 拉取 Server 變更到本地 |

### Ledger（群組帳本）

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | ledgers | Api\Ledger@create | 建立群組帳本 |
| GET | ledgers/:id | Api\Ledger@show | 取得帳本詳情 |
| PUT | ledgers/:id | Api\Ledger@update | 更新帳本名稱/幣別 |
| POST | ledgers/join | Api\Ledger@join | 用邀請碼加入群組帳本 |
| POST | ledgers/:id/leave | Api\Ledger@leave | 退出群組帳本 |
| GET | ledgers/:id/members | Api\Ledger@members | 取得成員列表 |
| POST | ledgers/:id/settle | Api\Ledger@settle | 結算拆帳 |

---

## Sync API 詳細說明

### Push 流程（Client → Server）

Client 將本地資料推送到 Server，Server 執行 upsert 後回傳 serverId mapping。

**Request：**
```json
{
  "ledgers": [{
    "localId": "uuid",
    "name": "個人",
    "type": "personal",
    "currency": "TWD",
    "categories": [{
      "localId": "uuid",
      "name": "早餐",
      "icon": "fork.knife",
      "color": "#FF6B35",
      "sort": 0,
      "isSystemDefault": false
    }],
    "expenses": [{
      "localId": "uuid",
      "amount": 150,
      "categoryLocalId": "uuid",
      "memo": "午餐",
      "date": "2026-03-24 12:00:00",
      "latitude": null,
      "longitude": null,
      "address": null
    }],
    "recurringExpenses": [{
      "localId": "uuid",
      "amount": 300,
      "categoryLocalId": "uuid",
      "frequencyType": "monthly",
      "frequencyValue": {"dayOfMonth": 1},
      "memo": "月租",
      "isEnabled": true
    }],
    "deletedExpenseLocalIds": ["uuid1"],
    "deletedCategoryLocalIds": [],
    "deletedRecurringLocalIds": []
  }]
}
```

**處理邏輯：**
1. 每個 ledger 依 `(createdByUserId, localId)` 做 upsert
2. 新帳本自動建立 owner LedgerMember
3. categories 依 `(ledgerId, localId)` 做 upsert（**每次送全量**，確保 categoryLocalId 可被解析）
4. expenses / recurringExpenses 依 `(ledgerId, localId)` 做 upsert（**只送 pending**）
5. deleted 清單依 localId 查找並刪除
6. `categoryLocalId` → 透過 `_resolveCategoryId()` 轉為 server 端 categoryId

**Response：**
```json
{
  "mappings": {
    "ledgers": [{"localId": "uuid", "serverId": 1}],
    "categories": [{"localId": "uuid", "serverId": 10}],
    "expenses": [{"localId": "uuid", "serverId": 100}],
    "recurringExpenses": [{"localId": "uuid", "serverId": 50}]
  }
}
```

Client 收到後更新本地 `serverId` + `syncStatus = "synced"`，並清除已同步的 deleted 記錄。

### Pull 流程（Server → Client）

Client 帶 `lastSyncAt` 拉取 Server 端變更，Server 回傳用戶所有帳本的完整結構。

**Request：**
```json
{"lastSyncAt": "2026-03-24 12:00:00"}
```

首次同步不帶 `lastSyncAt`（或 null），Server 回傳全量資料。

**處理邏輯：**
1. 查詢用戶所屬的所有帳本（透過 LedgerMember）
2. 每個帳本回傳：members、categories（全量）、expenses + recurringExpenses + settlements（依 `updateAt >= lastSyncAt` 過濾）
3. 預載所有相關 User 避免 N+1 查詢

**Response：**
```json
{
  "ledgers": [{
    "serverId": 1,
    "name": "個人",
    "type": "personal",
    "currency": "TWD",
    "inviteCode": null,
    "members": [{
      "serverId": 1,
      "userId": 1,
      "name": "小明",
      "role": "owner",
      "isCurrentUser": true
    }],
    "categories": [{"serverId": 10, "localId": "uuid", "name": "早餐", "icon": "fork.knife", "color": "#FF6B35", "sort": 0, "isSystemDefault": false}],
    "expenses": [{"serverId": 100, "localId": "uuid", "categoryId": 10, "amount": 150, "memo": "午餐", "date": "2026-03-24 12:00:00", "isSettled": false, "paidByUserId": null, "createdByUserId": 1}],
    "recurringExpenses": [],
    "settlements": []
  }],
  "serverTime": "2026-03-24 18:00:00"
}
```

Client 依 `serverId` 合併到本地（有則更新，無則新增），並儲存 `serverTime` 作為下次 pull 的 `lastSyncAt`。

# 後端 API 測試

可直接複製執行的 curl 指令，獨立驗證每個 API 端點。

---

## 環境準備

```bash
BASE=http://local-api-life.iwi.tw

# 取得測試 token（LOCAL 環境 dev login）
TOKEN=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test@test.com","isDev":true}' | jq -r '.token')

echo "TOKEN=$TOKEN"

# 驗證 token
curl -s $BASE/api/auth/me \
  -H "Authorization: Bearer $TOKEN" | jq .

# 取得第二個測試帳號（用於多人測試）
TOKEN2=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test2@test.com","isDev":true}' | jq -r '.token')
```

### DB 查詢捷徑

```bash
# 進入 PHP 容器
alias dbq='docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php -r"'

# 範例：查詢用戶
dbq "\"require 'System/Load.php'; \\\$u = \\App\\Model\\User::one('email', 'test@test.com'); echo \\\$u->id;\""
```

---

## Auth（4 組）

### auth-1：Dev Login

```bash
# 請求
curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test@test.com","isDev":true}' | jq .

# 預期回應（200）
# {
#   "token": "<jwt_string>",
#   "expiresIn": 86400,
#   "tokenType": "Bearer"
# }
```

**驗證**：`token` 非空字串、`expiresIn` > 0

---

### auth-2：取得當前用戶

```bash
curl -s $BASE/api/auth/me \
  -H "Authorization: Bearer $TOKEN" | jq .

# 預期回應（200）
# {
#   "user": {
#     "id": 1,
#     "email": "test@test.com",
#     "name": "test",
#     "carrierNumber": null,
#     "status": "active"
#   }
# }
```

**錯誤情境**：
```bash
# 無 token → 401
curl -s -w "\n%{http_code}" $BASE/api/auth/me

# 無效 token → 401
curl -s -w "\n%{http_code}" $BASE/api/auth/me \
  -H "Authorization: Bearer invalid_token"
```

---

### auth-3：更新個人資料

```bash
# 更新 name
curl -s -X PUT $BASE/api/auth/me \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"測試用戶"}' | jq .

# 預期回應（200）
# { "user": { "id": 1, "name": "測試用戶", ... } }

# 更新 carrierNumber
curl -s -X PUT $BASE/api/auth/me \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"carrierNumber":"/AB12345"}' | jq .
```

---

### auth-4：登入初始化（帶 guest 開銷）

```bash
curl -s -X POST $BASE/api/auth/init \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "expenses": [
      {"categoryKey":"breakfast","amount":100,"memo":"早餐","date":"2026-03-25 08:00:00"},
      {"categoryKey":"lunch","amount":150,"memo":"午餐","date":"2026-03-25 12:00:00"},
      {"categoryKey":"dinner","amount":200,"memo":"","date":"2026-03-25 18:00:00"}
    ]
  }' | jq .

# 預期回應（200）
# {
#   "ledgers": [{
#     "id": N,
#     "name": "個人",
#     "type": "personal",
#     "members": [{ "isCurrentUser": true, ... }],
#     "categories": [...],  // 包含 breakfast/lunch/dinner 等預設分類
#     "expenses": [         // 3 筆剛上傳的開銷
#       { "amount": 100, "categoryId": N, ... },
#       { "amount": 150, "categoryId": N, ... },
#       { "amount": 200, "categoryId": N, ... }
#     ],
#     ...
#   }]
# }
```

**驗證重點**：
- personal ledger 存在
- expenses 有 3 筆，金額分別 100/150/200
- categoryKey 正確對應到 categoryId（breakfast → 早餐分類）
- 無 categoryKey 的 → categoryId=null

**DB 驗證**：
```sql
-- 用戶的 personal ledger
SELECT * FROM Ledger WHERE createdByUserId = ? AND type = 'personal';

-- 該帳本的開銷
SELECT id, categoryId, amount, memo FROM Expense WHERE ledgerId = ? ORDER BY date;
```

---

## State（2 組）

### state-1：取得完整 State（空）

```bash
# 新帳號首次取 state（可能只有 personal ledger）
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq .

# 預期回應（200）
# { "ledgers": [...] }
```

---

### state-2：取得完整 State（有資料）

```bash
# 有帳本 + 開銷後
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers | length'
# 預期：>= 1

curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[0].expenses | length'
# 預期：>= 0

# 驗證結構完整性
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[0] | keys'
# 預期包含：categories, currency, expenses, id, inviteCode, members, name, recurringExpenses, settlements, type
```

---

## Ledger（8 組）

### ledger-1：建立群組帳本

```bash
curl -s -X POST $BASE/api/ledgers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"測試群組","currency":"TWD"}' | jq .

# 預期回應（200）
# {
#   "ledger": {
#     "id": N,
#     "name": "測試群組",
#     "type": "group",
#     "currency": "TWD",
#     "inviteCode": "ABCDEF",  // 6 碼
#     "members": [{ "role": "owner", "isCurrentUser": true, ... }],
#     "categories": [...]  // 預設分類
#   }
# }

# 儲存帳本 ID 和邀請碼
LEDGER_ID=$(curl -s -X POST $BASE/api/ledgers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"API測試群組","currency":"TWD"}' | jq -r '.ledger.id')

INVITE_CODE=$(curl -s $BASE/api/ledgers/$LEDGER_ID \
  -H "Authorization: Bearer $TOKEN" | jq -r '.ledger.inviteCode')

echo "LEDGER_ID=$LEDGER_ID, INVITE_CODE=$INVITE_CODE"
```

**驗證**：inviteCode 為 6 字元、member 含 owner、有預設分類

---

### ledger-2：查看帳本詳情

```bash
curl -s $BASE/api/ledgers/$LEDGER_ID \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

### ledger-3：更新帳本名稱

```bash
curl -s -X PUT $BASE/api/ledgers/$LEDGER_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"改名後的群組"}' | jq .

# 驗證
curl -s $BASE/api/ledgers/$LEDGER_ID \
  -H "Authorization: Bearer $TOKEN" | jq '.ledger.name'
# 預期："改名後的群組"
```

---

### ledger-4：有開銷時改幣別 → 400

```bash
# 先建立一筆開銷
curl -s -X POST $BASE/api/ledgers/$LEDGER_ID/expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"amount":100,"memo":"test"}' > /dev/null

# 嘗試改幣別
curl -s -w "\n%{http_code}" -X PUT $BASE/api/ledgers/$LEDGER_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"currency":"USD"}'

# 預期：400 + 錯誤訊息
```

---

### ledger-5：用邀請碼加入帳本

```bash
curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$INVITE_CODE\"}" | jq .

# 預期回應（200）
# { "ledger": { ... 包含新成員 ... } }

# 驗證成員數
curl -s $BASE/api/ledgers/$LEDGER_ID/members \
  -H "Authorization: Bearer $TOKEN" | jq '.members | length'
# 預期：2
```

---

### ledger-6：無效邀請碼 → 404

```bash
curl -s -w "\n%{http_code}" -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d '{"inviteCode":"ZZZZZZ"}'

# 預期：404
```

---

### ledger-7：未結清時加入 → 視實作而定

```bash
# 此測試需帳本有未結算開銷，看後端是否攔截
# 注意：依照目前實作，可能允許加入（攔截在退出時）
```

---

### ledger-8：退出帳本

```bash
# TOKEN2 退出帳本
curl -s -X POST $BASE/api/ledgers/$LEDGER_ID/leave \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' | jq .

# 預期回應（200）
# { "success": true }

# 驗證成員數回到 1
curl -s $BASE/api/ledgers/$LEDGER_ID/members \
  -H "Authorization: Bearer $TOKEN" | jq '.members | length'
# 預期：1
```

---

## Category（5 組）

### cat-1：建立分類

```bash
# 先取得帳本 ID（用 personal ledger）
PERSONAL_ID=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .id')

curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/categories \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"測試分類","icon":"star","color":"#FF0000"}' | jq .

# 預期回應（200）
# { "category": { "id": N, "name": "測試分類", "icon": "star", "color": "#FF0000", "sort": N } }

CAT_ID=$(curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/categories \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"待刪除分類","icon":"trash","color":"#999999"}' | jq -r '.category.id')
```

---

### cat-2：更新分類

```bash
curl -s -X PUT $BASE/api/categories/$CAT_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"改名分類","icon":"heart","color":"#00FF00"}' | jq .
```

---

### cat-3：刪除分類（cascade）

```bash
# 先用此分類建立開銷
EXP_FOR_CAT=$(curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"categoryId\":$CAT_ID,\"amount\":999,\"memo\":\"cascade test\"}" | jq -r '.expense.id')

# 刪除分類
curl -s -X DELETE $BASE/api/categories/$CAT_ID \
  -H "Authorization: Bearer $TOKEN" | jq .

# 預期：{ "success": true }

# 驗證開銷的 categoryId → null
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.type==\"personal\") | .expenses[] | select(.id==$EXP_FOR_CAT) | .categoryId"
# 預期：null
```

---

### cat-4：排序分類

```bash
# 取得現有分類 ID 列表
CAT_IDS=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.type==\"personal\") | .categories[].id]")

# 反轉順序
REVERSED=$(echo $CAT_IDS | jq 'reverse')

curl -s -X PUT $BASE/api/ledgers/$PERSONAL_ID/categories/sort \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"categoryIds\":$REVERSED}" | jq .

# 預期：{ "success": true }
```

---

### cat-5：刪除非成員的分類 → 403

```bash
# TOKEN2 嘗試刪除 TOKEN 的分類
SOME_CAT=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .categories[0].id')

curl -s -w "\n%{http_code}" -X DELETE $BASE/api/categories/$SOME_CAT \
  -H "Authorization: Bearer $TOKEN2"

# 預期：403
```

---

## Expense（6 組）

### exp-1：建立單筆開銷

```bash
# 取得一個分類 ID
FIRST_CAT=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .categories[0].id')

curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"categoryId\":$FIRST_CAT,
    \"amount\":350,
    \"memo\":\"午餐便當\",
    \"date\":\"2026-03-25 12:30:00\",
    \"latitude\":25.033,
    \"longitude\":121.565,
    \"address\":\"台北市信義區\"
  }" | jq .

# 預期回應（200）
# {
#   "expense": {
#     "id": N,
#     "categoryId": N,
#     "amount": 350,
#     "memo": "午餐便當",
#     "date": "2026-03-25 12:30:00",
#     "latitude": 25.033,
#     "longitude": 121.565,
#     "address": "台北市信義區",
#     "isSettled": false,
#     "paidByUserId": null,
#     "createdByUserId": N
#   }
# }
```

---

### exp-2：建立開銷（categoryId=null → 其他）

```bash
curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"amount":50,"memo":"其他開銷"}' | jq .

# 預期：expense.categoryId = null
```

---

### exp-3：批次建立開銷

```bash
curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/expenses/batch \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"expenses\": [
      {\"categoryId\":$FIRST_CAT,\"amount\":100,\"memo\":\"batch-1\",\"date\":\"2026-03-25 08:00:00\"},
      {\"categoryId\":$FIRST_CAT,\"amount\":200,\"memo\":\"batch-2\",\"date\":\"2026-03-25 12:00:00\"},
      {\"amount\":300,\"memo\":\"batch-3\",\"date\":\"2026-03-25 18:00:00\"}
    ]
  }" | jq .

# 預期回應（200）
# { "expenses": [
#   { "id": N, "amount": 100, ... },
#   { "id": N+1, "amount": 200, ... },
#   { "id": N+2, "amount": 300, "categoryId": null, ... }
# ]}
```

**驗證**：回傳 3 筆，各有獨立 id

---

### exp-4：更新開銷

```bash
# 取得剛建立的開銷 ID
EXP_ID=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses[0].id')

curl -s -X PUT $BASE/api/expenses/$EXP_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"amount":999,"memo":"已更新"}' | jq .

# 預期：expense.amount = 999, expense.memo = "已更新"
```

---

### exp-5：刪除開銷

```bash
curl -s -X DELETE $BASE/api/expenses/$EXP_ID \
  -H "Authorization: Bearer $TOKEN" | jq .

# 預期：{ "success": true }

# 驗證已刪除
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.type==\"personal\") | .expenses[] | select(.id==$EXP_ID)"
# 預期：無輸出
```

---

### exp-6：批次建立含無效金額

```bash
curl -s -w "\n%{http_code}" -X POST $BASE/api/ledgers/$PERSONAL_ID/expenses/batch \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"expenses":[{"amount":100,"memo":"ok"},{"amount":-50,"memo":"bad"}]}'

# 預期：400
```

---

## RecurringExpense（4 組）

### rec-1：建立固定開銷

```bash
curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/recurring-expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"categoryId\":$FIRST_CAT,
    \"amount\":5000,
    \"frequencyType\":\"monthly\",
    \"frequencyValue\":1,
    \"memo\":\"月租費\",
    \"isEnabled\":true
  }" | jq .

# 預期回應（200）
# {
#   "recurringExpense": {
#     "id": N,
#     "categoryId": N,
#     "amount": 5000,
#     "frequencyType": "monthly",
#     "frequencyValue": 1,
#     "memo": "月租費",
#     "isEnabled": true,
#     ...
#   }
# }

REC_ID=$(curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/recurring-expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"categoryId\":$FIRST_CAT,\"amount\":100,\"frequencyType\":\"daily\",\"memo\":\"test rec\",\"isEnabled\":true}" | jq -r '.recurringExpense.id')
```

---

### rec-2：更新固定開銷（toggle isEnabled）

```bash
curl -s -X PUT $BASE/api/recurring-expenses/$REC_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"isEnabled":false}' | jq .

# 預期：recurringExpense.isEnabled = false
```

---

### rec-3：刪除固定開銷

```bash
curl -s -X DELETE $BASE/api/recurring-expenses/$REC_ID \
  -H "Authorization: Bearer $TOKEN" | jq .

# 預期：{ "success": true }
```

---

### rec-4：非成員操作 → 403

```bash
# TOKEN2 嘗試更新 TOKEN 的固定開銷
curl -s -w "\n%{http_code}" -X PUT $BASE/api/recurring-expenses/$REC_ID \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d '{"isEnabled":false}'

# 預期：403
```

---

## Settlement（2 組）

### stl-1：結算拆帳

```bash
# 前置：建立群組帳本，兩人各記帳
# 先建立群組帳本
STL_LEDGER=$(curl -s -X POST $BASE/api/ledgers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"結算測試","currency":"TWD"}' | jq -r '.ledger.id')

STL_INVITE=$(curl -s $BASE/api/ledgers/$STL_LEDGER \
  -H "Authorization: Bearer $TOKEN" | jq -r '.ledger.inviteCode')

# TOKEN2 加入
curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$STL_INVITE\"}" > /dev/null

# 取得兩人 userId
MEMBERS=$(curl -s $BASE/api/ledgers/$STL_LEDGER/members \
  -H "Authorization: Bearer $TOKEN")
USER1_ID=$(echo $MEMBERS | jq '.members[] | select(.isCurrentUser==true) | .userId')
USER2_ID=$(echo $MEMBERS | jq '.members[] | select(.isCurrentUser==false) | .userId')

# TOKEN 記帳 600
curl -s -X POST $BASE/api/ledgers/$STL_LEDGER/expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":600,\"memo\":\"A付\",\"paidByUserId\":$USER1_ID}" > /dev/null

# TOKEN2 記帳 200
curl -s -X POST $BASE/api/ledgers/$STL_LEDGER/expenses \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":200,\"memo\":\"B付\",\"paidByUserId\":$USER2_ID}" > /dev/null

# 結算（人均 400，B→A 200）
curl -s -X POST $BASE/api/ledgers/$STL_LEDGER/settle \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"transfers\":[{\"fromUserId\":$USER2_ID,\"toUserId\":$USER1_ID,\"amount\":200}]}" | jq .

# 預期回應（200）
# {
#   "settlement": {
#     "id": N,
#     "settledByUserId": USER1_ID,
#     "transfers": [...],
#     "currencySymbol": "$",
#     "createAt": "2026-..."
#   }
# }
```

**DB 驗證**：
```sql
-- 所有開銷已標記 settled
SELECT id, isSettled FROM Expense WHERE ledgerId = ?;
-- 預期：全部 isSettled = 'yes'

-- Settlement 紀錄
SELECT * FROM Settlement WHERE ledgerId = ?;
```

---

### stl-2：結算後加入

```bash
# 結算後，新人用邀請碼加入
TOKEN3=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test3@test.com","isDev":true}' | jq -r '.token')

curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN3" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$STL_INVITE\"}" | jq .

# 預期：200（允許加入，因為已結清）
```

---

## 清理測試資料

```bash
# 如需重置資料庫（⚠️ 會刪除所有資料）
# docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php migration -R"
# docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php migration"
```

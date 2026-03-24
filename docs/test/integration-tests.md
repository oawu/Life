# 模擬器 + 後端整合測試

僅涵蓋 10 個高風險路徑的端到端驗證，每個測試需在模擬器操作 + 後端 DB 驗證。

---

## 環境準備

```bash
BASE=http://local-api-life.iwi.tw

# 重置資料庫（確保乾淨狀態）
docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php migration -R"
docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php migration"

# 取得 token（用於 DB 驗證）
TOKEN=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test@test.com","isDev":true}' | jq -r '.token')
```

---

## INT-001：訪客 5 筆 → 登入 → 驗證 Server 有 5 筆

**風險原因**：登入同步是最複雜的流程

**前置條件**
- 全新安裝 App（或刪除重裝模擬器 App）
- 後端資料庫已重置

**操作步驟**
1. App 啟動 → Guest 模式
2. 依序新增 5 筆開銷：
   - 早餐 $100
   - 午餐 $150
   - 晚餐 $200
   - 交通 $50
   - 飲料 $80
3. 開發者登入（test@test.com）
4. 等待同步完成（觀察 Xcode console）

**App 端驗證**
- [ ] 開銷列表顯示 5 筆
- [ ] 金額合計 $580
- [ ] 各分類正確對應

**Log 驗證**
```
[LifeApp] authState changed: guest → authenticated
[LifeApp] initAfterLogin started, guestExpenses=5
[ExpenseStore] initAfterLogin: uploading 5 guest expenses
[DataManager] rebuildFromState: created N ledgers
```

**後端驗證**
```bash
# 查詢用戶 ID
USER_ID=$(curl -s $BASE/api/auth/me \
  -H "Authorization: Bearer $TOKEN" | jq '.user.id')

# 驗證 personal ledger
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | {name, expenseCount: (.expenses | length)}'
# 預期：expenseCount = 5

# 驗證各筆金額
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[].amount] | sort'
# 預期：[50, 80, 100, 150, 200]
```

---

## INT-002：登出再登入不產生重複資料

**風險原因**：曾經的 bug 根源

**前置條件**
- INT-001 完成後，已登入使用者有 5 筆開銷

**操作步驟**
1. Tab 2 → 登出（確認 alert）
2. 訪客模式新增 3 筆開銷：
   - 早餐 $120
   - 零食 $45
   - 交通 $60
3. 重新登入（test@test.com）
4. 等待同步完成

**App 端驗證**
- [ ] 開銷列表顯示 8 筆（5 舊 + 3 新）
- [ ] 無重複開銷
- [ ] 只有 1 本個人帳本

**Log 驗證**
```
[LifeApp] authState changed: authenticated → guest
[DataManager] clearAllCache
[LifeApp] authState changed: guest → authenticated
[LifeApp] initAfterLogin started, guestExpenses=3
[ExpenseStore] initAfterLogin: uploading 3 guest expenses
```

**後端驗證**
```bash
# 只有 1 本 personal ledger
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal")] | length'
# 預期：1

# 共 8 筆開銷
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses | length'
# 預期：8
```

---

## INT-003：離線 3 筆 → 上線 → 驗證 Server batch

**風險原因**：離線同步核心

**前置條件**
- 已登入，記住目前開銷數量

**操作步驟**
1. 記下目前開銷總數 N
2. 開啟飛航模式
3. 新增 3 筆開銷（金額 111、222、333）
4. 關閉飛航模式
5. 等待 log 顯示同步完成

**App 端驗證**
- [ ] 3 筆開銷顯示正常
- [ ] 同步後金額不變

**Log 驗證**
```
[ExpenseStore] addExpense: mode=auth, online=false  (x3)
[LifeApp] network changed: isOnline=true
[ExpenseStore] syncOfflineExpenses: found 3 unsynced
[ExpenseStore] syncOfflineExpenses: batch uploaded 3 to ledger X
[DataManager] markExpensesSynced: 3 expenses
```

**後端驗證**
```bash
# 開銷總數 = N + 3
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses | length'

# 驗證 3 筆新增的金額
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==111 or .amount==222 or .amount==333)] | length'
# 預期：3
```

---

## INT-004：網路慢 → 新增 → 回前景 → 驗證 Server

**風險原因**：剛修的 bug（App 回前景時同步離線開銷）

**前置條件**
- 已登入

**操作步驟**
1. 使用 Network Link Conditioner 設定極慢網路（或透過 Xcode 模擬）
2. 新增 1 筆開銷（金額 777）
3. 觀察是否 API 失敗降級為離線
4. 恢復正常網路
5. 切到背景 → 切回前景

**App 端驗證**
- [ ] 開銷已顯示
- [ ] 回前景後正常同步

**Log 驗證**
```
[ExpenseStore] addExpense: mode=auth, online=true
[ExpenseStore] addExpense API failed, falling back to offline: ...
[LifeApp] scenePhase: active, triggering sync + refresh
[ExpenseStore] syncOfflineExpenses: found 1 unsynced
[ExpenseStore] syncOfflineExpenses: batch uploaded 1 to ledger X
```

**後端驗證**
```bash
# 驗證 777 元開銷存在
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==777)'
```

---

## INT-005：刪除分類 → 驗證 Expense.categoryId=NULL

**風險原因**：cascade 正確性

**前置條件**
- 已登入，有自訂分類 + 該分類下有開銷

**操作步驟**
1. 建立自訂分類「測試分類」
2. 用「測試分類」記 2 筆開銷
3. 刪除「測試分類」
4. 查看 2 筆開銷

**App 端驗證**
- [ ] 2 筆開銷歸為「其他」分類
- [ ] 「測試分類」從列表消失

**後端驗證**
```bash
# 驗證開銷的 categoryId 為 null
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses[] | select(.categoryId==null)'
```

---

## INT-006：3 人群組帳本 → 各自記帳 → 結算

**風險原因**：結算核心流程

**前置條件**
- 3 個測試帳號

**操作步驟**
1. 帳號 A 建立群組帳本「聚餐」
2. 帳號 B、C 用邀請碼加入
3. A 記帳 $900（A 付）
4. B 記帳 $300（B 付）
5. C 記帳 $0
6. A 發起結算

**App 端驗證**
- [ ] 結算前拆帳：C→A $400、B→A $100
- [ ] 結算後：「已結清」

**後端驗證**
```bash
TOKEN_A=$TOKEN
TOKEN_B=$TOKEN2
TOKEN_C=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test3@test.com","isDev":true}' | jq -r '.token')

# 建立群組帳本
LEDGER=$(curl -s -X POST $BASE/api/ledgers \
  -H "Authorization: Bearer $TOKEN_A" \
  -H 'Content-Type: application/json' \
  -d '{"name":"聚餐","currency":"TWD"}' | jq -r '.ledger.id')

INVITE=$(curl -s $BASE/api/ledgers/$LEDGER \
  -H "Authorization: Bearer $TOKEN_A" | jq -r '.ledger.inviteCode')

# B、C 加入
curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN_B" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$INVITE\"}" > /dev/null

curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN_C" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$INVITE\"}" > /dev/null

# 取得成員 userId
MEMBERS=$(curl -s $BASE/api/ledgers/$LEDGER/members -H "Authorization: Bearer $TOKEN_A")
USER_A=$(echo $MEMBERS | jq '[.members[] | select(.isCurrentUser==true)][0].userId')

MEMBERS_B=$(curl -s $BASE/api/ledgers/$LEDGER/members -H "Authorization: Bearer $TOKEN_B")
USER_B=$(echo $MEMBERS_B | jq '[.members[] | select(.isCurrentUser==true)][0].userId')

# A 記帳 900
curl -s -X POST $BASE/api/ledgers/$LEDGER/expenses \
  -H "Authorization: Bearer $TOKEN_A" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":900,\"memo\":\"A付晚餐\",\"paidByUserId\":$USER_A}" > /dev/null

# B 記帳 300
curl -s -X POST $BASE/api/ledgers/$LEDGER/expenses \
  -H "Authorization: Bearer $TOKEN_B" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":300,\"memo\":\"B付飲料\",\"paidByUserId\":$USER_B}" > /dev/null

# 結算
USER_C=$(echo $MEMBERS | jq '[.members[] | select(.isCurrentUser==false)][1].userId')
curl -s -X POST $BASE/api/ledgers/$LEDGER/settle \
  -H "Authorization: Bearer $TOKEN_A" \
  -H 'Content-Type: application/json' \
  -d "{\"transfers\":[
    {\"fromUserId\":$USER_C,\"toUserId\":$USER_A,\"amount\":400},
    {\"fromUserId\":$USER_B,\"toUserId\":$USER_A,\"amount\":100}
  ]}" | jq .

# 驗證 isSettled
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN_A" | jq "[.ledgers[] | select(.id==$LEDGER) | .expenses[].isSettled] | all"
# 預期：true

# 驗證 Settlement 紀錄
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN_A" | jq ".ledgers[] | select(.id==$LEDGER) | .settlements | length"
# 預期：1
```

---

## INT-007：結算後退出 → 驗證 cascade

**風險原因**：cascade 正確性（RecurringExpense + Member 刪除）

**前置條件**
- INT-006 完成，帳本已結清

**操作步驟**
1. B 先建立 1 筆固定開銷
2. B 退出帳本

**App 端驗證**
- [ ] B 的帳本列表不再顯示「聚餐」

**後端驗證**
```bash
# B 建立固定開銷
curl -s -X POST $BASE/api/ledgers/$LEDGER/recurring-expenses \
  -H "Authorization: Bearer $TOKEN_B" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":100,\"frequencyType\":\"monthly\",\"frequencyValue\":1,\"memo\":\"B的固定開銷\",\"isEnabled\":true}" > /dev/null

# B 退出
curl -s -X POST $BASE/api/ledgers/$LEDGER/leave \
  -H "Authorization: Bearer $TOKEN_B" \
  -H 'Content-Type: application/json' | jq .

# 驗證 B 不在成員中
curl -s $BASE/api/ledgers/$LEDGER/members \
  -H "Authorization: Bearer $TOKEN_A" | jq '.members | length'
# 預期：2（A + C）

# 驗證 B 的固定開銷已刪除
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN_A" | jq ".ledgers[] | select(.id==$LEDGER) | .recurringExpenses | length"
# 預期：0
```

---

## INT-008：最後成員退出 → 帳本完全刪除

**風險原因**：cascade 邊界

**前置條件**
- 群組帳本只剩 1 位成員（或新建一個只有自己的群組帳本）

**操作步驟**
1. 建立新群組帳本（不邀請任何人）
2. 退出

**後端驗證**
```bash
# 建立帳本
SOLO_LEDGER=$(curl -s -X POST $BASE/api/ledgers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"獨自帳本","currency":"TWD"}' | jq -r '.ledger.id')

# 退出
curl -s -X POST $BASE/api/ledgers/$SOLO_LEDGER/leave \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' | jq .

# 驗證帳本不在 state 中
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.id==$SOLO_LEDGER)] | length"
# 預期：0
```

---

## INT-009：多帳本離線開銷 → 上線 → 各帳本分別 batch

**風險原因**：多帳本同步正確性

**前置條件**
- 已登入，有個人帳本 + 群組帳本

**操作步驟**
1. 開飛航模式
2. 個人帳本新增 2 筆（金額 111、222）
3. 切到群組帳本新增 2 筆（金額 333、444）
4. 關閉飛航模式
5. 等待同步完成

**App 端驗證**
- [ ] 個人帳本顯示 2 筆新開銷
- [ ] 群組帳本顯示 2 筆新開銷

**Log 驗證**
```
[ExpenseStore] syncOfflineExpenses: found 4 unsynced
[ExpenseStore] syncOfflineExpenses: batch uploaded 2 to ledger X
[ExpenseStore] syncOfflineExpenses: batch uploaded 2 to ledger Y
```

**後端驗證**
```bash
# 個人帳本有 111 和 222
PERSONAL_ID=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .id')

curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.id==$PERSONAL_ID) | .expenses[] | select(.amount==111 or .amount==222)] | length"
# 預期：2

# 群組帳本有 333 和 444
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.type==\"group\") | .expenses[] | select(.amount==333 or .amount==444)] | length"
# 預期：2
```

---

## INT-010：回前景 state rebuild → 保留未同步開銷

**風險原因**：rebuildFromState 邊界

**前置條件**
- 已登入

**操作步驟**
1. 開飛航模式
2. 新增 2 筆開銷（金額 555、666）
3. 關閉飛航模式
4. **立即**切到背景 → 切回前景（趁 sync 還沒完成）
5. 或：使用 Network Link Conditioner 讓 batch API 很慢

**App 端驗證**
- [ ] 2 筆開銷始終顯示在列表中
- [ ] 最終成功同步到 Server

**Log 驗證**
```
[DataManager] rebuildFromState: preserving 2 unsynced expenses
[DataManager] rebuildFromState: created N ledgers
```

**後端驗證**
```bash
# 等同步完成後驗證
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.type==\"personal\") | .expenses[] | select(.amount==555 or .amount==666)] | length"
# 預期：2
```

---

## 測試結果記錄模板

| # | 測試 | 日期 | 結果 | 備註 |
|---|------|------|------|------|
| 1 | INT-001 訪客→登入 | | Pass/Fail | |
| 2 | INT-002 登出再登入 | | Pass/Fail | |
| 3 | INT-003 離線→上線 | | Pass/Fail | |
| 4 | INT-004 網路慢 | | Pass/Fail | |
| 5 | INT-005 刪分類 cascade | | Pass/Fail | |
| 6 | INT-006 3人結算 | | Pass/Fail | |
| 7 | INT-007 結算後退出 | | Pass/Fail | |
| 8 | INT-008 最後成員退出 | | Pass/Fail | |
| 9 | INT-009 多帳本離線 | | Pass/Fail | |
| 10 | INT-010 rebuild保留未同步 | | Pass/Fail | |

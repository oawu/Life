# App Log 驗證清單

在 Xcode console 觀察結構化 log，驗證關鍵路徑的執行順序。

---

## Log 格式規範

| 前綴 | 元件 | 位置 |
|------|------|------|
| `[LifeApp]` | App 生命週期 | LifeApp.swift |
| `[ExpenseStore]` | 業務邏輯層 | ExpenseStore.swift |
| `[DataManager]` | Repository 層 | DataManager.swift |

---

## 認證相關

### AUTH-001：冷啟動 — 有效 token

**操作**：殺掉 App → 重新啟動（Keychain 有有效 JWT）

**預期 log 序列**：
1. `[LifeApp] authState changed: launching → authenticated`
2. `[LifeApp] initAfterLogin started, guestExpenses=0`
3. `[ExpenseStore] initAfterLogin: uploading 0 guest expenses`
4. `[ExpenseStore] refreshState: start`（如果 init 觸發 state 同步）
5. `[ExpenseStore] refreshState: received N ledgers`

**不應看到**：
- `[ExpenseStore] initAfterLogin error`

---

### AUTH-002：冷啟動 — 無 token

**操作**：首次安裝 → 啟動

**預期 log 序列**：
1. `[LifeApp] authState changed: launching → guest`

**不應看到**：
- `[ExpenseStore] refreshState`（Guest 不觸發）
- `[ExpenseStore] initAfterLogin`

---

### AUTH-005：Apple Sign In — 有訪客開銷

**操作**：訪客記 5 筆 → 登入

**預期 log 序列**：
1. `[LifeApp] authState changed: guest → authenticated`
2. `[LifeApp] initAfterLogin started, guestExpenses=5`
3. `[ExpenseStore] initAfterLogin: uploading 5 guest expenses`
4. `[ExpenseStore] refreshState: start`（如 init 後觸發 state）
5. `[ExpenseStore] refreshState: received N ledgers`
6. `[DataManager] rebuildFromState: preserving 0 unsynced expenses`
7. `[DataManager] rebuildFromState: created N ledgers`

**不應看到**：
- `[ExpenseStore] initAfterLogin error`

---

### AUTH-006：登出

**操作**：Tab 2 → 登出 → 確認

**預期 log 序列**：
1. `[LifeApp] authState changed: authenticated → guest`
2. `[DataManager] clearAllCache`

**不應看到**：
- `[DataManager] clearAllCache error`
- `[ExpenseStore] refreshState`（Guest 不觸發）

---

## 開銷相關

### EXP-001：Guest 新增開銷

**操作**：訪客模式 → 輸入金額 → 儲存

**預期 log**：
1. `[ExpenseStore] addExpense: mode=guest`

**不應看到**：
- `[ExpenseStore] addExpense: mode=auth`
- 任何 API 相關 log

---

### EXP-004：Auth+Online 新增開銷

**操作**：已登入 + 有網路 → 輸入金額 → 儲存

**預期 log**：
1. `[ExpenseStore] addExpense: mode=auth, online=true`

**不應看到**：
- `[ExpenseStore] addExpense API failed`

---

### EXP-008：Auth+Offline 新增開銷

**操作**：已登入 + 飛航模式 → 輸入金額 → 儲存

**預期 log**：
1. `[ExpenseStore] addExpense: mode=auth, online=false`

**不應看到**：
- `[ExpenseStore] addExpense API failed`（因為 isOnline=false 不會嘗試 API）

---

### EXP-013：Auth+Slow 新增開銷（API 失敗降級）

**操作**：已登入 + 網路慢（NWPathMonitor=online，API timeout）→ 輸入金額 → 儲存

**預期 log**：
1. `[ExpenseStore] addExpense: mode=auth, online=true`
2. `[ExpenseStore] addExpense API failed, falling back to offline: ...`

---

## 離線同步

### SYNC-001：離線 → 上線自動同步

**操作**：飛航模式下新增 2 筆開銷 → 關閉飛航模式

**預期 log 序列**：
1. `[ExpenseStore] addExpense: mode=auth, online=false`（第 1 筆）
2. `[ExpenseStore] addExpense: mode=auth, online=false`（第 2 筆）
3. `[LifeApp] network changed: isOnline=true`
4. `[ExpenseStore] syncOfflineExpenses: found 2 unsynced`
5. `[ExpenseStore] syncOfflineExpenses: batch uploaded 2 to ledger X`
6. `[DataManager] markExpensesSynced: 2 expenses`
7. `[ExpenseStore] refreshState: start`
8. `[ExpenseStore] refreshState: received N ledgers`
9. `[DataManager] rebuildFromState: preserving 0 unsynced expenses`
10. `[DataManager] rebuildFromState: created N ledgers`

**不應看到**：
- `[ExpenseStore] syncOfflineExpenses error`
- `[ExpenseStore] refreshState error`

---

### SYNC-002：回前景同步

**操作**：已登入 → 切到其他 App → 切回 Life

**預期 log 序列**：
1. `[LifeApp] scenePhase: active, triggering sync + refresh`
2. `[ExpenseStore] syncOfflineExpenses: found 0 unsynced`
3. `[ExpenseStore] refreshState: start`
4. `[ExpenseStore] refreshState: received N ledgers`
5. `[DataManager] rebuildFromState: preserving 0 unsynced expenses`
6. `[DataManager] rebuildFromState: created N ledgers`

---

### SYNC-003：多帳本離線開銷分別 batch

**操作**：個人帳本離線新增 2 筆 + 群組帳本離線新增 2 筆 → 上線

**預期 log 序列**：
1. `[LifeApp] network changed: isOnline=true`
2. `[ExpenseStore] syncOfflineExpenses: found 4 unsynced`
3. `[ExpenseStore] syncOfflineExpenses: batch uploaded 2 to ledger X`
4. `[ExpenseStore] syncOfflineExpenses: batch uploaded 2 to ledger Y`
5. `[DataManager] markExpensesSynced: 2 expenses`（或 4 如果合併呼叫）
6. `[ExpenseStore] refreshState: start`
7. `[ExpenseStore] refreshState: received N ledgers`

---

### SYNC-005 / STA-003：rebuildFromState 保留未同步

**操作**：有 2 筆未同步 → 回前景

**預期 log 序列**：
1. `[LifeApp] scenePhase: active, triggering sync + refresh`
2. `[ExpenseStore] syncOfflineExpenses: found 2 unsynced`
3. `[ExpenseStore] syncOfflineExpenses: batch uploaded 2 to ledger X`
4. `[DataManager] markExpensesSynced: 2 expenses`
5. `[ExpenseStore] refreshState: start`
6. `[ExpenseStore] refreshState: received N ledgers`
7. `[DataManager] rebuildFromState: preserving 0 unsynced expenses`

**如果 sync 失敗**（網路問題）：
1. `[LifeApp] scenePhase: active, triggering sync + refresh`
2. `[ExpenseStore] syncOfflineExpenses: found 2 unsynced`
3. `[ExpenseStore] syncOfflineExpenses error for ledger X: ...`
4. `[ExpenseStore] refreshState: start`
5. `[ExpenseStore] refreshState: received N ledgers`
6. `[DataManager] rebuildFromState: preserving 2 unsynced expenses`（保留未同步）
7. `[DataManager] rebuildFromState: created N ledgers`

---

## 狀態重整

### STA-001：回前景 rebuild

**操作**：另一裝置新增開銷 → 本機切回前景

**預期 log 序列**：
1. `[LifeApp] scenePhase: active, triggering sync + refresh`
2. `[ExpenseStore] syncOfflineExpenses: found 0 unsynced`
3. `[ExpenseStore] refreshState: start`
4. `[ExpenseStore] refreshState: received N ledgers`
5. `[DataManager] rebuildFromState: preserving 0 unsynced expenses`
6. `[DataManager] rebuildFromState: created N ledgers`

---

## 網路狀態變化

### 網路恢復完整流程

**操作**：飛航模式 → 關閉飛航

**預期 log 序列**（已登入）：
1. `[LifeApp] network changed: isOnline=true`
2. `[ExpenseStore] syncOfflineExpenses: found N unsynced`
3. （如有）`[ExpenseStore] syncOfflineExpenses: batch uploaded ...`
4. （如有）`[DataManager] markExpensesSynced: ...`
5. `[ExpenseStore] refreshState: start`
6. `[ExpenseStore] refreshState: received N ledgers`

**預期 log 序列**（訪客）：
1. `[LifeApp] network changed: isOnline=true`
（無後續，Guest 不觸發 sync/refresh）

---

## Xcode Console 篩選技巧

```
# 只看 LifeApp log
[LifeApp]

# 只看 ExpenseStore log
[ExpenseStore]

# 只看 DataManager log
[DataManager]

# 只看錯誤
error

# 只看同步相關
sync
```

# 測試情境總表

> 已整併至 [e2e-tests.md](e2e-tests.md)，本文件保留作為情境索引參考。

所有測試案例的索引，涵蓋 App 在各環境條件下的行為驗證。

---

## 環境說明

- **Auth 狀態**：Guest / Authenticated / Launching
- **網路狀態**：Online / Offline / Slow（API timeout 但 NWPathMonitor 顯示 online）
- **後端指令**：`docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php ..."`
- **DB 查詢**：`docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php -r \"...\"`
- **模擬器自動化**：透過 MCP Server 操控（詳見 `docs/test/mcp-setup.md`）

## 權限矩陣（總覽）

| 功能 | Guest | Auth+Online | Auth+Offline | Auth+Slow |
|------|-------|-------------|--------------|-----------|
| 個人帳本記帳 | Local | API | Local (isSynced=false) | Fallback to Local |
| 開銷編輯 | Local | API | 已同步:Blocked / 未同步:Local | 已同步:Error / 未同步:Local |
| 開銷刪除 | Local | API | 已同步:Blocked / 未同步:Local | 已同步:Error / 未同步:Local |
| 分類管理 | Blocked（靜態預設） | API | Blocked | Error |
| 帳本管理 | Blocked（LoginPrompt） | API | Blocked | Error |
| 固定開銷管理 | Blocked（LoginPrompt） | API | Blocked | Error |
| 拆帳結算 | N/A | API | Blocked | Error |
| 個人資料 | Blocked（GuestProfile） | API | Blocked | Error |
| 統計圖表 | Local | Local(cached) | Local(cached) | Local(cached) |
| 離線同步 | N/A | 回前景/網路恢復 auto | N/A | 回前景 retry |
| State 重整 | N/A | 回前景/網路恢復 auto | N/A | 回前景 retry |

---

## 1. 認證（AUTH-001 ~ 008）

### AUTH-001：冷啟動 — 有效 token

**環境** Auth: Launching / Network: Online
**前置條件** Keychain 有有效 JWT
**操作步驟**
1. 殺掉 App → 重新啟動

**預期結果**
- LaunchView 短暫顯示 → 自動切到 HomeView（Authenticated）
- Log：`[LifeApp] authState changed: launching → authenticated`

**測試層** Layer 3（log）

---

### AUTH-002：冷啟動 — 無 token

**環境** Auth: Launching / Network: Online
**前置條件** Keychain 無 JWT（首次安裝或已登出）
**操作步驟**
1. 殺掉 App → 重新啟動

**預期結果**
- LaunchView → HomeView（Guest 模式）
- Tab 1 顯示 AddExpenseView，Tab 2 顯示 GuestProfileView
- Log：`[LifeApp] authState changed: launching → guest`

**測試層** Layer 3（log）

---

### AUTH-003：冷啟動 — 過期 token

**環境** Auth: Launching / Network: Online
**前置條件** Keychain 有過期 JWT
**操作步驟**
1. 殺掉 App → 重新啟動

**預期結果**
- LaunchView → GET /api/auth/me 失敗 → 清除 token → Guest 模式
- Log：`[LifeApp] authState changed: launching → guest`

**測試層** Layer 3（log）

---

### AUTH-004：Apple Sign In — 無訪客開銷

**環境** Auth: Guest / Network: Online
**前置條件** 訪客模式，未記任何開銷
**操作步驟**
1. Tab 2 → 點「Sign In with Apple」（或 LOCAL 環境開發者登入）
2. 完成授權

**預期結果**
- authState → authenticated
- POST /api/auth/init（expenses=[]）→ 建立個人帳本 + 預設分類
- 開銷列表為空
- Log：`[ExpenseStore] initAfterLogin: uploading 0 guest expenses`

**測試層** Layer 3（log）+ Layer 4（整合）

---

### AUTH-005：Apple Sign In — 有訪客開銷

**環境** Auth: Guest / Network: Online
**前置條件** 訪客已記 5 筆開銷
**操作步驟**
1. Tab 2 → 登入

**預期結果**
- POST /api/auth/init（expenses=5）→ 5 筆開銷建立在 Server
- GuestExpense 清除
- 開銷列表顯示 5 筆
- Log：`[ExpenseStore] initAfterLogin: uploading 5 guest expenses`

**測試層** Layer 3（log）+ Layer 4（整合）

---

### AUTH-006：登出

**環境** Auth: Authenticated / Network: Online
**前置條件** 已登入，有開銷資料
**操作步驟**
1. Tab 2 → 捲到底部 → 點「登出」→ 確認

**預期結果**
- Cached* 資料全部清除
- 切到 Guest 模式，Tab 1 AddExpenseView
- Log：`[DataManager] clearAllCache` → `[LifeApp] authState changed: authenticated → guest`

**測試層** Layer 3（log）

---

### AUTH-007：登出後再登入 — 不重複資料

**環境** Auth: Authenticated → Guest → Authenticated / Network: Online
**前置條件** 已登入 5 筆 → 登出 → 訪客新增 3 筆 → 重新登入
**操作步驟**
1. 登出
2. 訪客模式新增 3 筆開銷
3. 重新登入

**預期結果**
- Server 共 8 筆開銷（5 舊 + 3 新）
- App 顯示 8 筆，無重複
- 只有 1 本 personal ledger

**測試層** Layer 4（整合）

---

### AUTH-008：冷啟動 — 離線 + 有效 token

**環境** Auth: Launching / Network: Offline
**前置條件** Keychain 有有效 JWT，飛航模式
**操作步驟**
1. 開飛航模式 → 殺掉 App → 重新啟動

**預期結果**
- GET /api/auth/me 失敗 → 降級為 Guest 或使用快取資料（視 AuthManager 實作）
- 不應 crash

**測試層** Layer 3（log）

---

## 2. 開銷 CRUD（EXP-001 ~ 014）

### EXP-001：Guest 新增開銷

**環境** Auth: Guest / Network: N/A
**前置條件** 訪客模式
**操作步驟**
1. 輸入金額 150，選分類「早餐」
2. 點儲存

**預期結果**
- 顯示「已儲存 $150」+ 打勾動畫
- GuestExpense 新增一筆（categoryKey=breakfast）
- Log：`[ExpenseStore] addExpense: mode=guest`

**測試層** Layer 3（log）

---

### EXP-002：Guest 編輯開銷

**環境** Auth: Guest / Network: N/A
**前置條件** 訪客有 1 筆開銷
**操作步驟**
1. 明細 → 點開銷 → 編輯 → 改金額為 200
2. 儲存

**預期結果**
- GuestExpense 金額更新為 200
- 列表顯示更新後金額

**測試層** Layer 3（log）

---

### EXP-003：Guest 刪除開銷

**環境** Auth: Guest / Network: N/A
**前置條件** 訪客有 1 筆開銷
**操作步驟**
1. 明細 → 點開銷 → 刪除 → 確認

**預期結果**
- GuestExpense 刪除
- 列表為空

**測試層** Layer 3（log）

---

### EXP-004：Auth+Online 新增開銷

**環境** Auth: Authenticated / Network: Online
**前置條件** 已登入，有個人帳本
**操作步驟**
1. 輸入金額 300，選分類「午餐」，輸入備註
2. 儲存

**預期結果**
- POST /api/ledgers/:id/expenses → 200
- CachedExpense 新增（isSynced=true）
- 顯示「已儲存 $300」
- Log：`[ExpenseStore] addExpense: mode=auth, online=true`

**測試層** Layer 2（curl）+ Layer 3（log）

---

### EXP-005：Auth+Online 編輯已同步開銷

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 1 筆已同步開銷
**操作步驟**
1. 點開銷 → 編輯 → 改金額
2. 儲存

**預期結果**
- PUT /api/expenses/:id → 200
- CachedExpense 更新

**測試層** Layer 2（curl）

---

### EXP-006：Auth+Online 刪除已同步開銷

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 1 筆已同步開銷
**操作步驟**
1. 點開銷 → 刪除 → 確認

**預期結果**
- DELETE /api/expenses/:id → 200
- CachedExpense 刪除

**測試層** Layer 2（curl）

---

### EXP-007：Auth+Online 新增開銷（categoryId=null → 其他）

**環境** Auth: Authenticated / Network: Online
**前置條件** 已登入
**操作步驟**
1. 選分類「其他」→ 輸入金額 → 儲存

**預期結果**
- POST body 不帶 categoryId（或 categoryId=null）
- Server Expense.categoryId = NULL
- 開銷列表顯示「其他」分類圖示

**測試層** Layer 2（curl）

---

### EXP-008：Auth+Offline 新增開銷（離線排隊）

**環境** Auth: Authenticated / Network: Offline
**前置條件** 已登入 + 飛航模式
**操作步驟**
1. 輸入金額 200，選分類「午餐」
2. 儲存

**預期結果**
- 不呼叫 API
- CachedExpense 新增（isSynced=false）
- 顯示「已儲存 $200」
- Log：`[ExpenseStore] addExpense: mode=auth, online=false`

**測試層** Layer 3（log）+ Layer 4（整合）

---

### EXP-009：Auth+Offline 編輯已同步開銷 → 阻擋

**環境** Auth: Authenticated / Network: Offline
**前置條件** 有 1 筆已同步開銷（serverId 不為 nil），飛航模式
**操作步驟**
1. 點開銷 → 編輯 → 改金額 → 儲存

**預期結果**
- Alert「目前無法連線，請稍後再試」
- 開銷不變

**測試層** Layer 3（log）

---

### EXP-010：Auth+Offline 編輯未同步開銷 → 允許

**環境** Auth: Authenticated / Network: Offline
**前置條件** 先離線新增 1 筆（isSynced=false），仍在離線
**操作步驟**
1. 點未同步開銷 → 編輯 → 改金額 → 儲存

**預期結果**
- 本地更新成功
- 仍標記 isSynced=false

**測試層** Layer 3（log）

---

### EXP-011：Auth+Offline 刪除已同步開銷 → 阻擋

**環境** Auth: Authenticated / Network: Offline
**前置條件** 有 1 筆已同步開銷，飛航模式
**操作步驟**
1. 點開銷 → 刪除

**預期結果**
- Alert「目前無法連線，請稍後再試」
- 開銷不變

**測試層** Layer 3（log）

---

### EXP-012：Auth+Offline 刪除未同步開銷 → 允許

**環境** Auth: Authenticated / Network: Offline
**前置條件** 先離線新增 1 筆，仍在離線
**操作步驟**
1. 點未同步開銷 → 刪除

**預期結果**
- 本地刪除成功

**測試層** Layer 3（log）

---

### EXP-013：Auth+Slow 新增開銷（API 失敗降級）

**環境** Auth: Authenticated / Network: Slow（NWPathMonitor=online，API timeout）
**前置條件** 已登入，模擬 API 極慢
**操作步驟**
1. 輸入金額 → 儲存

**預期結果**
- API 呼叫失敗 → 降級為離線新增
- CachedExpense isSynced=false
- 顯示「已儲存」（不顯示錯誤）
- Log：`[ExpenseStore] addExpense API failed, falling back to offline: ...`

**測試層** Layer 3（log）

---

### EXP-014：Auth+Online 群組帳本新增開銷（指定付款人）

**環境** Auth: Authenticated / Network: Online
**前置條件** 已加入群組帳本，有多位成員
**操作步驟**
1. 切換到群組帳本 → 輸入金額 → 選付款人 → 儲存

**預期結果**
- POST body 含 paidByUserId
- Server Expense.paidByUserId 正確
- PayerChips 顯示

**測試層** Layer 2（curl）

---

## 3. 離線同步（SYNC-001 ~ 005）

### SYNC-001：離線 → 上線自動同步

**環境** Auth: Authenticated / Network: Offline → Online
**前置條件** 離線新增 2 筆開銷
**操作步驟**
1. 關閉飛航模式

**預期結果**
- 網路恢復 → syncOfflineExpenses() 觸發
- POST /api/ledgers/:id/expenses/batch（2 筆）
- CachedExpense.isSynced → true，serverId 填入
- refreshState() → 重建快取
- Log 序列：`network changed` → `syncOfflineExpenses: found 2` → `batch uploaded 2` → `refreshState: start` → `refreshState: received`

**測試層** Layer 3（log）+ Layer 4（整合）

---

### SYNC-002：回前景同步

**環境** Auth: Authenticated / Network: Online
**前置條件** App 在背景一段時間（可能有其他裝置更改資料）
**操作步驟**
1. 切到其他 App → 切回 Life

**預期結果**
- scenePhase=active → syncOfflineExpenses + refreshState
- 資料更新
- Log：`[LifeApp] scenePhase: active, triggering sync + refresh`

**測試層** Layer 3（log）

---

### SYNC-003：多帳本離線開銷分別 batch

**環境** Auth: Authenticated / Network: Offline → Online
**前置條件** 有個人帳本 + 群組帳本，各離線新增 2 筆
**操作步驟**
1. 切換帳本各新增 2 筆 → 關閉飛航模式

**預期結果**
- 按 ledgerServerId 分組，各自呼叫 batch API
- Log：`batch uploaded 2 to ledger X` + `batch uploaded 2 to ledger Y`

**測試層** Layer 3（log）+ Layer 4（整合）

---

### SYNC-004：同步後 Server 資料驗證

**環境** Auth: Authenticated / Network: Online
**前置條件** SYNC-001 完成後
**操作步驟**
1. 查詢 Server DB

**預期結果**
- Expense 表有對應記錄
- 金額、分類、日期正確
- createdByUserId = 當前用戶

**測試層** Layer 2（curl / SQL）

---

### SYNC-005：回前景 — 保留未同步開銷

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 2 筆未同步開銷（isSynced=false）
**操作步驟**
1. 切到背景 → 回前景

**預期結果**
- refreshState → rebuildFromState 保留 unsyncedExpenses
- 未同步開銷仍在列表，isSynced=false
- Log：`[DataManager] rebuildFromState: preserving 2 unsynced expenses`

**測試層** Layer 3（log）+ Layer 4（整合）

---

### SYNC-006：下拉重新整理 — 同步 + 拉取

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 1 筆未同步開銷（離線時新增）
**操作步驟**
1. 恢復網路
2. 在明細列表下拉重新整理

**預期結果**
- syncOfflineExpenses → 上傳未同步開銷
- refreshState → 拉取 Server 最新狀態
- 開銷出現在 Server 端
- Log：`syncOfflineExpenses: found 1` → `refreshState: start` → `refreshState: received`

**測試層** Layer 3（log）+ Layer 4（整合）

---

## 4. 分類管理（CAT-001 ~ 008）

### CAT-001：Auth+Online 新增分類

**環境** Auth: Authenticated / Network: Online
**前置條件** 已登入
**操作步驟**
1. 帳本設定 → 分類管理 → 新增 → 輸入名稱/圖示/顏色 → 儲存

**預期結果**
- POST /api/ledgers/:id/categories → 200
- 分類列表新增一筆（排在「其他」前）

**測試層** Layer 2（curl）

---

### CAT-002：Auth+Online 編輯分類

**環境** Auth: Authenticated / Network: Online
**前置條件** 有自訂分類
**操作步驟**
1. 點分類 → 修改名稱/圖示/顏色 → 儲存

**預期結果**
- PUT /api/categories/:id → 200
- 分類更新

**測試層** Layer 2（curl）

---

### CAT-003：Auth+Online 刪除分類（cascade）

**環境** Auth: Authenticated / Network: Online
**前置條件** 有自訂分類，該分類下有 2 筆開銷 + 1 筆固定開銷
**操作步驟**
1. 刪除該分類

**預期結果**
- DELETE /api/categories/:id → 200
- Server：Expense.categoryId → NULL、RecurringExpense.categoryId → NULL
- App：2 筆開銷歸為「其他」分類
- 分類列表移除該分類

**測試層** Layer 2（curl）+ Layer 4（整合）

---

### CAT-004：Auth+Online 排序分類

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 3+ 個分類
**操作步驟**
1. 長按拖動分類順序

**預期結果**
- PUT /api/ledgers/:id/categories/sort → 200
- 新順序持久化

**測試層** Layer 2（curl）

---

### CAT-005：「其他」分類不可變

**環境** Auth: Authenticated / Network: Online
**前置條件** 已登入
**操作步驟**
1. 嘗試編輯/刪除/拖動「其他」分類

**預期結果**
- 「其他」分類不顯示編輯/刪除按鈕
- 排序時「其他」永遠在最後

**測試層** Layer 3（手動觀察）

---

### CAT-006：Guest 分類管理 → 阻擋

**環境** Auth: Guest
**前置條件** 訪客模式
**操作步驟**
1. 嘗試進入分類管理

**預期結果**
- Alert「登入後可編輯分類」

**測試層** Layer 3（手動觀察）

---

### CAT-007：Auth+Offline 分類管理 → 阻擋

**環境** Auth: Authenticated / Network: Offline
**前置條件** 飛航模式
**操作步驟**
1. 嘗試新增/編輯/刪除分類

**預期結果**
- Alert「目前無法連線，請稍後再試」

**測試層** Layer 3（手動觀察）

---

### CAT-008：Auth+Online 刪除分類 — 非成員 → 403

**環境** Auth: Authenticated / Network: Online
**前置條件** 嘗試刪除不屬於自己帳本的分類
**操作步驟**
1. 直接呼叫 DELETE /api/categories/:id（他人帳本的分類）

**預期結果**
- 403 Forbidden

**測試層** Layer 2（curl）

---

## 5. 帳本管理（LDG-001 ~ 012）

### LDG-001：建立群組帳本

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 帳本設定 → 建立群組帳本 → 輸入名稱 + 選幣別

**預期結果**
- POST /api/ledgers → 200
- 回傳 inviteCode（8 碼+，Hashids 動態計算）
- 自動建立預設分類 + owner member
- 帳本列表新增

**測試層** Layer 2（curl）

---

### LDG-002：用邀請碼加入帳本

**環境** Auth: Authenticated / Network: Online
**前置條件** 有他人建立的群組帳本邀請碼
**操作步驟**
1. 掃碼 / 手動輸入邀請碼

**預期結果**
- POST /api/ledgers/join → 200
- 新增 member 記錄
- 帳本列表顯示新帳本

**測試層** Layer 2（curl）

---

### LDG-003：無效邀請碼

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 輸入不存在的邀請碼

**預期結果**
- 404「邀請碼無效」

**測試層** Layer 2（curl）

---

### LDG-004：更新帳本名稱

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 帳本設定 → 修改名稱 → 儲存

**預期結果**
- PUT /api/ledgers/:id → 200
- 名稱更新

**測試層** Layer 2（curl）

---

### LDG-005：有開銷時變更幣別 → 阻擋

**環境** Auth: Authenticated / Network: Online
**前置條件** 帳本已有開銷
**操作步驟**
1. 嘗試變更幣別

**預期結果**
- 400「帳本已有開銷，無法變更幣別」

**測試層** Layer 2（curl）

---

### LDG-006：無開銷時變更幣別

**環境** Auth: Authenticated / Network: Online
**前置條件** 帳本無開銷
**操作步驟**
1. 變更幣別

**預期結果**
- PUT /api/ledgers/:id → 200
- 幣別更新

**測試層** Layer 2（curl）

---

### LDG-007：退出群組帳本 — 已結清

**環境** Auth: Authenticated / Network: Online
**前置條件** 群組帳本已結清（無未結算開銷）
**操作步驟**
1. 帳本設定 → 退出帳本 → 確認

**預期結果**
- POST /api/ledgers/:id/leave → 200
- member 刪除
- 該成員的 RecurringExpense 刪除
- 帳本從列表消失
- currentLedgerId 切到個人帳本

**測試層** Layer 2（curl）+ Layer 4（整合）

---

### LDG-008：退出群組帳本 — 未結清 → 攔截

**環境** Auth: Authenticated / Network: Online
**前置條件** 群組帳本有未結算開銷
**操作步驟**
1. 嘗試退出

**預期結果**
- 攔截訊息「帳本尚未結清」
- 不允許退出

**測試層** Layer 2（curl）

---

### LDG-009：最後成員退出 → 帳本完全刪除

**環境** Auth: Authenticated / Network: Online
**前置條件** 群組帳本只剩 1 位成員（無未結算開銷）
**操作步驟**
1. 退出帳本

**預期結果**
- Server：Ledger + 所有 Category + Expense + Member + RecurringExpense + Settlement 刪除
- DB 查無此帳本

**測試層** Layer 2（curl）+ Layer 4（整合）

---

### LDG-010：Guest 建立群組帳本 → LoginPrompt

**環境** Auth: Guest
**操作步驟**
1. 嘗試建立群組帳本

**預期結果**
- 彈出 LoginPromptView

**測試層** Layer 3（手動觀察）

---

### LDG-011：Auth+Offline 帳本管理 → 阻擋

**環境** Auth: Authenticated / Network: Offline
**操作步驟**
1. 嘗試建立/更新/退出帳本

**預期結果**
- Alert「目前無法連線，請稍後再試」

**測試層** Layer 3（手動觀察）

---

### LDG-012：帳本排序

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 2+ 個群組帳本
**操作步驟**
1. 長按拖動帳本順序

**預期結果**
- sortOrder 更新
- 重啟後順序保持

**測試層** Layer 3（手動觀察）

---

## 6. 拆帳結算（STL-001 ~ 005）

### STL-001：拆帳計算正確性

**環境** Auth: Authenticated / Network: Online
**前置條件** 群組帳本 3 人，A 付 900、B 付 300、C 付 0
**操作步驟**
1. 查看拆帳區塊

**預期結果**
- 人均 400
- 轉帳：C→A 400、B→A 100（貪婪配對）

**測試層** Layer 3（手動觀察）

---

### STL-002：結清操作

**環境** Auth: Authenticated / Network: Online
**前置條件** 有未結算開銷
**操作步驟**
1. 點「結清」→ 確認

**預期結果**
- POST /api/ledgers/:id/settle → 200
- 所有開銷 isSettled → true
- Settlement 記錄建立
- 拆帳區塊顯示「已結清」

**測試層** Layer 2（curl）+ Layer 4（整合）

---

### STL-003：結算紀錄查看

**環境** Auth: Authenticated / Network: Online
**前置條件** 有結算紀錄
**操作步驟**
1. 查看結算紀錄列表 → 點進詳情

**預期結果**
- 結算時間、操作者正確
- 轉帳明細快照正確

**測試層** Layer 3（手動觀察）

---

### STL-004：已全部結清 — 拆帳區塊不顯示

**環境** Auth: Authenticated / Network: Online
**前置條件** 所有開銷已結清，無新開銷
**操作步驟**
1. 查看群組帳本首頁

**預期結果**
- 無未結算開銷時不顯示拆帳轉帳明細
- 餘額為 0

**測試層** Layer 3（手動觀察）

---

### STL-005：結算後新成員加入

**環境** Auth: Authenticated / Network: Online
**前置條件** 群組帳本已結清
**操作步驟**
1. 新成員用邀請碼加入

**預期結果**
- POST /api/ledgers/join → 200（無未結清攔截）
- 新成員只看到結清後的新開銷

**測試層** Layer 2（curl）

---

## 7. 固定開銷（REC-001 ~ 006）

### REC-001：建立固定開銷

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 固定開銷 → 新增 → 填寫金額/分類/頻率/備註

**預期結果**
- POST /api/ledgers/:id/recurring-expenses → 200
- 列表新增

**測試層** Layer 2（curl）

---

### REC-002：編輯固定開銷

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 點固定開銷 → 修改 → 儲存

**預期結果**
- PUT /api/recurring-expenses/:id → 200

**測試層** Layer 2（curl）

---

### REC-003：刪除固定開銷

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 點固定開銷 → 刪除

**預期結果**
- DELETE /api/recurring-expenses/:id → 200

**測試層** Layer 2（curl）

---

### REC-004：Toggle isEnabled

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 切換固定開銷的啟用/停用

**預期結果**
- PUT → isEnabled 切換
- UI 即時反映

**測試層** Layer 2（curl）

---

### REC-005：Guest 固定開銷 → 阻擋

**環境** Auth: Guest
**操作步驟**
1. 嘗試進入固定開銷管理

**預期結果**
- LoginPromptView

**測試層** Layer 3（手動觀察）

---

### REC-006：Auth+Offline 固定開銷 → 阻擋

**環境** Auth: Authenticated / Network: Offline
**操作步驟**
1. 嘗試新增/編輯/刪除固定開銷

**預期結果**
- Alert「目前無法連線，請稍後再試」

**測試層** Layer 3（手動觀察）

---

## 8. 個人資料（PRF-001 ~ 004）

### PRF-001：更新名稱

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. Tab 2 → 點名稱 → 修改 → 完成

**預期結果**
- PUT /api/auth/me → 200
- DB User.name 更新

**測試層** Layer 2（curl）

---

### PRF-002：更新載具號碼

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. Tab 2 → 載具號碼 → 輸入 → 儲存

**預期結果**
- PUT /api/auth/me → 200
- Code 128 條碼預覽顯示

**測試層** Layer 2（curl）

---

### PRF-003：Auth+Offline 個人資料 → 阻擋

**環境** Auth: Authenticated / Network: Offline
**操作步驟**
1. 嘗試修改名稱或載具

**預期結果**
- Alert「目前無法連線，請稍後再試」

**測試層** Layer 3（手動觀察）

---

### PRF-004：Guest 個人頁面

**環境** Auth: Guest
**操作步驟**
1. Tab 2

**預期結果**
- 顯示 GuestProfileView（品牌展示 + Apple Sign In）
- LOCAL 環境顯示「開發者登入」

**測試層** Layer 3（手動觀察）

---

## 9. 狀態重整（STA-001 ~ 003）

### STA-001：回前景 rebuild

**環境** Auth: Authenticated / Network: Online
**前置條件** 另一裝置新增了開銷
**操作步驟**
1. App 切到背景 → 切回

**預期結果**
- GET /api/state → rebuildFromState
- 新開銷出現在列表
- Log：`[LifeApp] scenePhase: active` → `[ExpenseStore] refreshState: start` → `received N ledgers` → `[DataManager] rebuildFromState: created N ledgers`

**測試層** Layer 3（log）+ Layer 4（整合）

---

### STA-002：多裝置同步

**環境** Auth: Authenticated / Network: Online
**前置條件** 兩台裝置登入同帳號
**操作步驟**
1. 裝置 A 新增開銷
2. 裝置 B 切回前景

**預期結果**
- 裝置 B 顯示新開銷

**測試層** Layer 4（整合）

---

### STA-003：rebuildFromState 保留未同步

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 2 筆未同步開銷
**操作步驟**
1. 觸發 refreshState（回前景）

**預期結果**
- rebuildFromState 暫存 unsyncedData → 清除 → 重建 → 恢復
- 未同步開銷仍在，isSynced=false
- Log：`[DataManager] rebuildFromState: preserving 2 unsynced expenses`

**測試層** Layer 3（log）+ Layer 4（整合）

---

## 10. Watch 連動（WCH-001 ~ 004）

### WCH-001：iPhone → Watch 帳本同步

**環境** Auth: Authenticated / Network: Online
**前置條件** Watch 已配對
**操作步驟**
1. iPhone 新增/修改帳本

**預期結果**
- WatchConnectivity 推送帳本 + 分類資料到 Watch
- Watch 帳本列表更新

**測試層** Layer 3（手動觀察）

---

### WCH-002：Watch 記帳 → iPhone 接收

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. Watch 端完成記帳流程

**預期結果**
- Watch 發送開銷到 iPhone
- PhoneSessionManager 收到 → 呼叫 API 建立 → 更新快取
- iPhone 列表更新

**測試層** Layer 3（手動觀察）

---

### WCH-003：Guest Watch 只顯示個人帳本

**環境** Auth: Guest
**操作步驟**
1. 查看 Watch 帳本列表

**預期結果**
- 只顯示個人帳本
- 群組帳本不顯示

**測試層** Layer 3（手動觀察）

---

### WCH-004：Watch 離線提示

**環境** Auth: Authenticated / Network: Offline
**操作步驟**
1. 查看 Watch 帳本列表

**預期結果**
- 底部顯示 wifi.slash +「離線中」

**測試層** Layer 3（手動觀察）

---

## 11. 邊界條件（EDGE-001 ~ 006）

### EDGE-001：訪客 10 筆備份提醒

**環境** Auth: Guest
**前置條件** 訪客已記 9 筆
**操作步驟**
1. 新增第 10 筆開銷

**預期結果**
- Alert 提醒登入備份
- 提供「登入」→ LoginPromptView 和「稍後」選項

**測試層** Layer 3（手動觀察）

---

### EDGE-002：空狀態顯示

**環境** Auth: Authenticated / Network: Online
**前置條件** 帳本無開銷
**操作步驟**
1. 查看開銷列表

**預期結果**
- 顯示空狀態提示

**測試層** Layer 3（手動觀察）

---

### EDGE-003：多幣別帳本切換

**環境** Auth: Authenticated / Network: Online
**前置條件** 有 TWD 和 USD 帳本
**操作步驟**
1. 切換帳本

**預期結果**
- 金額顯示對應幣別符號
- 統計圖表使用對應幣別

**測試層** Layer 3（手動觀察）

---

### EDGE-004：大金額處理

**環境** Auth: Authenticated / Network: Online
**操作步驟**
1. 輸入大金額（如 9999999）

**預期結果**
- 正確儲存和顯示
- 千分位格式化

**測試層** Layer 3（手動觀察）

---

### EDGE-005：統計圖表

**環境** Auth: Authenticated / Network: Online
**前置條件** 有多個分類的開銷
**操作步驟**
1. 查看統計圖表 → 切換月/年

**預期結果**
- 環形圖 + 分類進度條正確
- 金額加總正確

**測試層** Layer 3（手動觀察）

---

### EDGE-006：帳本切換（LedgerSwitcher）

**環境** Auth: Authenticated / Network: Online
**前置條件** 有個人 + 群組帳本
**操作步驟**
1. 開銷列表頂部橫向滾動切換帳本

**預期結果**
- 開銷列表刷新為對應帳本
- 群組帳本顯示 PayerChips
- 個人帳本不顯示 PayerChips

**測試層** Layer 3（手動觀察）

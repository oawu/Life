# 端對端測試（E2E Tests）

透過 MCP 工具自動化操控 iOS 模擬器 + Docker 後端，執行完整的端對端驗證。

**相關文件**：
- [api-tests.md](api-tests.md) — 獨立 API curl 測試指令集
- [mcp-setup.md](mcp-setup.md) — MCP Server 安裝與設定

---

## 1. 概述

### 測試工具

| 工具 | 用途 |
|------|------|
| **XcodeBuildMCP** | Build/Run App、snapshot_ui（精確座標）、log 擷取 |
| **ios-simulator** | ui_tap / ui_type / ui_swipe / ui_view（截圖）|
| **Docker（PHP/MySQL）** | 後端 API + 資料庫 |
| **curl + jq** | API 驗證、DB 查詢 |

### 三層驗證模型

每個測試依情境組合以下驗證：

| 層 | 方法 | 說明 |
|----|------|------|
| **UI** | `snapshot_ui` / `ui_view` | 確認畫面元素、文字、狀態 |
| **Log** | `start_sim_log_cap` / `stop_sim_log_cap` | 比對預期 log 序列 |
| **DB** | `curl` API 查詢 | 驗證 Server 端資料正確性 |

### 已知限制

1. **中文輸入**：MCP `ui_type` 僅支援 ASCII（`^[\x20-\x7E]+$`），含中文的資料需用 curl 建立
2. **時序**：API 呼叫後需等待 1-3 秒再驗證，用 `wait_for` 或固定等待
3. **Debug 面板位置**：可拖曳，每次操作前需 `snapshot_ui` 定位
4. **計算機座標**：因裝置尺寸而異，每次用 `snapshot_ui` 取得
5. **背景/前景模擬**：用 `stop_app_sim` + `launch_app_sim` 模擬
6. **Watch 測試**：MCP 無法控制 Watch 模擬器，排除在外
7. **捲動**：部分 UI 元素需 `ui_swipe` 才可見，需先 `snapshot_ui` 判斷

---

## 2. 環境準備

### 2.1 DB 重置

```bash
docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php migration -R"
docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php migration"
```

### 2.2 App Build & Install

```
# XcodeBuildMCP
session_show_defaults          # 確認 project/scheme/simulator
build_run_sim                  # Build + Install + Launch
```

> 若 defaults 未設定：
> ```
> session_set_defaults:
>   projectPath: /Users/oa/Workspace/32_Life/ios/Life.xcodeproj
>   scheme: Life Dev
>   simulatorName: iPhone 16
>   bundleId: tw.iwi.life.beta
> ```

### 2.3 curl TOKEN 取得

```bash
BASE=http://local-api-life.iwi.tw

# 主帳號
TOKEN=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test@test.com","isDev":true}' | jq -r '.token')

# 第二帳號（多人測試用）
TOKEN2=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test2@test.com","isDev":true}' | jq -r '.token')

# 第三帳號（拆帳測試用）
TOKEN3=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test3@test.com","isDev":true}' | jq -r '.token')
```

### 2.4 Helper 變數

```bash
# 取得 personal ledger ID
PERSONAL_ID=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .id')

# 取得第一個分類 ID
FIRST_CAT=$(curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .categories[0].id')
```

---

## 3. 共用流程（Procedure）

可複用的操作序列，測試步驟中以 `→ P1` 形式引用。

### P1: Dev 登入（App UI）

> 前提：App 在 Guest 模式，LOCAL 環境

1. `snapshot_ui` — 定位 Tab Bar
2. `ui_tap` — 點 Tab 2（個人頁面）
3. `snapshot_ui` — 確認 GuestProfileView，定位「開發者登入」按鈕
4. `ui_tap` — 點「開發者登入」
5. `snapshot_ui` — 確認出現 email 輸入框
6. `ui_tap` — 點 email 輸入框
7. `ui_type` — 輸入 `test@test.com`
8. `snapshot_ui` — 定位「登入」按鈕
9. `ui_tap` — 點「登入」
10. 等待 2-3 秒（API + state 同步）
11. `snapshot_ui` — 確認已切到 Authenticated 模式（Tab 2 顯示個人資料頁）

### P2: 新增開銷（計算機操作）

> 前提：App 在 AddExpenseView（Tab 1）

**參數**：`amount`（數字按鈕序列）、`categoryIndex`（分類位置）

1. `snapshot_ui` — 定位計算機按鈕
   ```
   計算機佈局：
   [7] [8] [9] [÷]
   [4] [5] [6] [×]
   [1] [2] [3] [-]
   [清除] [0] [=] [+]
   ```
2. 依 `amount` 逐一 `ui_tap` 數字按鈕（例：150 → 點 1、5、0）
3. `snapshot_ui` — 定位分類格
4. `ui_tap` — 點第 `categoryIndex` 個分類（預設分類：早餐=0, 午餐=1, 晚餐=2, ...）
5. `snapshot_ui` — 定位「儲存」按鈕（toolbar trailing）
6. `ui_tap` — 點「儲存」
7. 等待 1 秒
8. `snapshot_ui` 或 `ui_view` — 確認顯示「已儲存 $XXX」+ 打勾動畫

### P3: 切換「模擬斷網」（Debug 面板）

> 前提：Debug 面板可見（DEBUG build）

1. `snapshot_ui` — 定位 Debug 浮動面板（小圓圈按鈕）
2. `ui_tap` — 點擊展開面板
3. `snapshot_ui` — 定位「模擬斷網」Toggle
4. `ui_tap` — 點擊 Toggle 切換
   - ON → 指示燈變紅，狀態文字「離線中」
   - OFF → 指示燈變綠，狀態文字「網路正常」
5. `ui_tap` — 點空白處或 ✕ 收合面板

### P4: 切換「API 故障」（Debug 面板）

> 前提：Debug 面板可見

1. `snapshot_ui` — 定位 Debug 浮動面板
2. `ui_tap` — 點擊展開面板
3. `snapshot_ui` — 定位「API 故障」Toggle
4. `ui_tap` — 點擊 Toggle 切換
   - ON → 指示燈變黃，狀態文字「API 故障」
   - OFF → 指示燈變綠，狀態文字「網路正常」
5. `ui_tap` — 點空白處或 ✕ 收合面板

### P5: 導航到明細列表

> 前提：App 在 AddExpenseView（Tab 1）

1. `snapshot_ui` — 定位「明細」按鈕（toolbar leading）
2. `ui_tap` — 點「明細」
3. `snapshot_ui` — 確認進入 ExpenseListView

### P6: 登出

> 前提：已登入（Authenticated）

1. `snapshot_ui` — 定位 Tab Bar
2. `ui_tap` — 點 Tab 2（個人頁面）
3. `ui_swipe` — 向上滑到底部，露出「登出」按鈕
4. `snapshot_ui` — 定位「登出」按鈕
5. `ui_tap` — 點「登出」
6. `snapshot_ui` — 確認出現 confirmationDialog
7. `ui_tap` — 點確認
8. 等待 1 秒
9. `snapshot_ui` — 確認已切回 Guest 模式

### P7: Log 擷取

> 包裹在需要 log 驗證的測試步驟周圍

**開始**：
```
start_sim_log_cap({ captureConsole: true, subsystemFilter: "app" })
→ 記錄回傳的 logSessionId
```

**結束**：
```
stop_sim_log_cap({ logSessionId: "<id>" })
→ 取回 log 內容，比對預期序列
```

---

## 4. 測試套件

---

### Suite A: 認證流程（6 tests）

---

#### A-1: 全新安裝 → Guest 模式

**前置條件**：DB 已重置、App 剛 build_run_sim（首次安裝）
**依賴**：無

**步驟**
1. → P7 開始 log 擷取
2. `snapshot_ui` — 確認 App 已啟動

**驗證：UI**
- [ ] `snapshot_ui` 確認 Tab 1 為 AddExpenseView（計算機 + 分類格）
- [ ] 頂部 LedgerSwitcher 顯示「個人」

**驗證：Log**（stop_sim_log_cap）
```
[LifeApp] authState changed: launching → guest
```
不應出現：
```
[ExpenseStore] refreshState
[ExpenseStore] initAfterLogin
```

---

#### A-2: Dev 登入（無訪客開銷）

**前置條件**：Auth=Guest, Network=Online, 無訪客開銷
**依賴**：A-1

**步驟**
1. → P7 開始 log 擷取
2. → P1（Dev 登入）

**驗證：UI**
- [ ] `snapshot_ui` 確認 Tab 2 顯示個人資料頁（非 GuestProfileView）
- [ ] Tab 1 仍為 AddExpenseView

**驗證：Log**
```
[LifeApp] authState changed: guest → authenticated
[ExpenseStore] initAfterLogin: uploading 0 guest expenses
```

**驗證：DB**
```bash
# personal ledger 存在
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .name'
# 預期："個人"

# 開銷為空
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses | length'
# 預期：0
```

---

#### A-3: 登出

**前置條件**：Auth=Authenticated
**依賴**：A-2

**步驟**
1. → P7 開始 log 擷取
2. → P6（登出）

**驗證：UI**
- [ ] `snapshot_ui` 確認 Tab 2 為 GuestProfileView（品牌展示 + Apple Sign In）
- [ ] Tab 1 為 AddExpenseView

**驗證：Log**
```
[LifeApp] authState changed: authenticated → guest
[DataManager] clearAllCache
```

---

#### A-4: 訪客 3 筆開銷 → 登入上傳

**前置條件**：Auth=Guest（A-3 登出後）
**依賴**：A-3

**步驟**
1. → P7 開始 log 擷取
2. `ui_tap` — 點 Tab 1 回到 AddExpenseView
3. → P2（新增開銷：amount=100, categoryIndex=0）— 早餐 $100
4. → P2（新增開銷：amount=150, categoryIndex=1）— 午餐 $150
5. → P2（新增開銷：amount=200, categoryIndex=2）— 晚餐 $200
6. → P1（Dev 登入）
7. 等待 3 秒（API init + state 同步）

**驗證：UI**
- [ ] → P5（明細列表），`snapshot_ui` 確認列表有 3 筆開銷

**驗證：Log**
```
[ExpenseStore] initAfterLogin: uploading 3 guest expenses
```

**驗證：DB**
```bash
# 開銷數量
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses | length'
# 預期：3

# 金額
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[].amount] | sort'
# 預期：[100, 150, 200]
```

---

#### A-5: 登出 → 再加 2 筆 → 重新登入

**前置條件**：Auth=Authenticated, DB 已有 3 筆
**依賴**：A-4

**步驟**
1. → P6（登出）
2. → P2（新增開銷：amount=80, categoryIndex=3）
3. → P2（新增開銷：amount=60, categoryIndex=4）
4. → P7 開始 log 擷取
5. → P1（Dev 登入）
6. 等待 3 秒

**驗證：Log**
```
[ExpenseStore] initAfterLogin: uploading 2 guest expenses
```

**驗證：DB**
```bash
# 共 5 筆無重複
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '.ledgers[] | select(.type=="personal") | .expenses | length'
# 預期：5

# 只有 1 本 personal ledger
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal")] | length'
# 預期：1
```

---

#### A-6: 冷啟動（有效 token）

**前置條件**：Auth=Authenticated（A-5 登入後）
**依賴**：A-5

**步驟**
1. `stop_app_sim` — 終止 App
2. → P7 開始 log 擷取
3. `launch_app_sim` — 重新啟動 App
4. 等待 3 秒

**驗證：UI**
- [ ] `snapshot_ui` 確認已進入 Authenticated 模式（Tab 1 AddExpenseView，非 Guest）

**驗證：Log**
```
[LifeApp] authState changed: launching → authenticated
```

---

### Suite B: 訪客開銷 CRUD（4 tests）

> 前提：A-6 完成後，先執行 P6 登出回 Guest 模式

---

#### B-1: Guest 新增開銷

**前置條件**：Auth=Guest
**依賴**：Suite A 完成 + 登出

**步驟**
1. → P7 開始 log 擷取
2. `ui_tap` — Tab 1
3. → P2（新增開銷：amount=250, categoryIndex=0）

**驗證：UI**
- [ ] `ui_view` — 確認顯示「已儲存」+ 打勾動畫

**驗證：Log**
```
[ExpenseStore] addExpense: mode=guest
```

---

#### B-2: 檢視明細列表

**前置條件**：Auth=Guest, 有 1 筆開銷（B-1）
**依賴**：B-1

**步驟**
1. → P5（導航到明細列表）

**驗證：UI**
- [ ] `snapshot_ui` 確認列表有 1 筆開銷，金額 $250

---

#### B-3: 編輯開銷

**前置條件**：在 ExpenseListView，有 1 筆開銷
**依賴**：B-2

**步驟**
1. `snapshot_ui` — 定位開銷 cell
2. `ui_tap` — 點開銷 → 進入詳情頁
3. `snapshot_ui` — 定位「編輯」按鈕
4. `ui_tap` — 點「編輯」→ 開啟編輯 Sheet
5. `snapshot_ui` — 定位計算機「清除」按鈕
6. `ui_tap` — 點「清除」
7. 依序 `ui_tap` — 點 3、0、0（輸入 300）
8. `snapshot_ui` — 定位「儲存」按鈕
9. `ui_tap` — 點「儲存」
10. 等待 1 秒

**驗證：UI**
- [ ] `snapshot_ui` 確認詳情頁金額已更新為 $300

---

#### B-4: 刪除開銷

**前置條件**：在開銷詳情頁
**依賴**：B-3

**步驟**
1. `snapshot_ui` — 定位「刪除」按鈕
2. `ui_tap` — 點「刪除」
3. `snapshot_ui` — 確認出現 confirmationDialog
4. `ui_tap` — 點確認刪除
5. 等待 1 秒

**驗證：UI**
- [ ] `snapshot_ui` 確認回到列表，列表為空（空狀態提示）

---

### Suite C: 已登入開銷 CRUD（5 tests）

> 前提：B-4 完成後，執行 P1 登入

---

#### C-1: 新增開銷（線上）

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：登入後

**步驟**
1. → P7 開始 log 擷取
2. `ui_tap` — Tab 1
3. → P2（新增開銷：amount=350, categoryIndex=0）
4. 等待 2 秒（API 同步）

**驗證：UI**
- [ ] `ui_view` — 確認「已儲存 $350」

**驗證：Log**
```
[ExpenseStore] addExpense: mode=auth, online=true
```

**驗證：DB**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==350)] | length'
# 預期：1
```

---

#### C-2: 編輯已同步開銷

**前置條件**：有 1 筆已同步開銷（C-1）
**依賴**：C-1

**步驟**
1. → P5（明細列表）
2. `snapshot_ui` — 定位 $350 開銷
3. `ui_tap` — 點進詳情
4. `snapshot_ui` — 定位「編輯」
5. `ui_tap` — 點「編輯」
6. 計算機：清除 → 輸入 999
7. `ui_tap` — 點「儲存」
8. 等待 2 秒

**驗證：DB**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==999)] | length'
# 預期：1（350 已更新為 999）
```

---

#### C-3: 刪除已同步開銷

**前置條件**：有 1 筆已同步開銷 $999（C-2）
**依賴**：C-2

**步驟**
1. `snapshot_ui` — 在詳情頁定位「刪除」
2. `ui_tap` — 點「刪除」→ 確認
3. 等待 2 秒

**驗證：DB**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==999)] | length'
# 預期：0
```

---

#### C-4: 新增「其他」分類開銷

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：C-3

**步驟**
1. `ui_tap` — Tab 1
2. `snapshot_ui` — 定位計算機
3. 輸入金額 50
4. `snapshot_ui` — 定位分類格，找到「其他」分類（永遠在最後）
5. 如需翻頁：`ui_swipe` 在分類區域向左滑
6. `ui_tap` — 點「其他」分類
7. `ui_tap` — 點「儲存」
8. 等待 2 秒

**驗證：DB**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==50 and .categoryId==null)] | length'
# 預期：1
```

---

#### C-5: 開銷列表按日期分組

**前置條件**：有多筆開銷（先前測試累積）
**依賴**：C-4

**步驟**
1. → P5（明細列表）

**驗證：UI**
- [ ] `snapshot_ui` 確認列表有日期分組 header（如「今天」或日期字串）
- [ ] 確認開銷按日期分組排列

---

### Suite D: 離線與同步（5 tests）

---

#### D-1: 離線新增開銷

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：Suite C 完成

**步驟**
1. → P3（模擬斷網 ON）
2. → P7 開始 log 擷取
3. `ui_tap` — Tab 1
4. → P2（新增開銷：amount=777, categoryIndex=0）
5. 等待 1 秒

**驗證：UI**
- [ ] `ui_view` — 仍顯示「已儲存 $777」
- [ ] → P5（明細列表），`snapshot_ui` 確認 $777 開銷旁有 `icloud.slash` 圖示

**驗證：Log**
```
[ExpenseStore] addExpense: mode=auth, online=false
```

**驗證：DB**
```bash
# Server 端不應有此筆
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==777)] | length'
# 預期：0
```

---

#### D-2: 離線編輯已同步開銷 → 阻擋

**前置條件**：Auth=Authenticated, Network=Offline（D-1 斷網仍 ON），有已同步開銷
**依賴**：D-1

**步驟**
1. → P5（明細列表）如尚未在列表
2. `snapshot_ui` — 定位一筆**已同步**開銷（無 icloud.slash 圖示）
3. `ui_tap` — 點進詳情
4. `snapshot_ui` — 定位「編輯」
5. `ui_tap` — 點「編輯」

**驗證：UI**
- [ ] `snapshot_ui` 確認出現 alert「無法連線」（或類似離線提示）
- [ ] 開銷未被修改

---

#### D-3: 恢復網路 → 自動同步

**前置條件**：Auth=Authenticated, Network=Offline, 有 1 筆未同步開銷（D-1 的 $777）
**依賴**：D-1

**步驟**
1. `ui_tap` — Tab 1（回到 AddExpenseView）
2. → P7 開始 log 擷取
3. → P3（模擬斷網 OFF — 恢復網路）
4. 等待 5 秒（sync + refreshState）

**驗證：Log**
```
[ExpenseStore] syncOfflineExpenses: found 1 unsynced
[ExpenseStore] syncOfflineExpenses: batch uploaded 1
[ExpenseStore] refreshState: start
[ExpenseStore] refreshState: received
```

**驗證：DB**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq '[.ledgers[] | select(.type=="personal") | .expenses[] | select(.amount==777)] | length'
# 預期：1（已同步到 Server）
```

---

#### D-4: 離線新增 → 編輯未同步開銷 → 允許

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：D-3

**步驟**
1. → P3（模擬斷網 ON）
2. `ui_tap` — Tab 1
3. → P2（新增開銷：amount=111, categoryIndex=0）
4. → P5（明細列表）
5. `snapshot_ui` — 定位 $111 開銷（應有 icloud.slash 圖示）
6. `ui_tap` — 點進詳情
7. `snapshot_ui` — 定位「編輯」
8. `ui_tap` — 點「編輯」
9. 計算機：清除 → 輸入 222
10. `ui_tap` — 點「儲存」

**驗證：UI**
- [ ] 無 alert 阻擋（編輯成功）
- [ ] `snapshot_ui` 確認金額已更新為 $222

---

#### D-5: 離線新增 → 刪除未同步開銷 → 允許

**前置條件**：Auth=Authenticated, Network=Offline, 有 1 筆未同步開銷 $222（D-4）
**依賴**：D-4

**步驟**
1. `snapshot_ui` — 在詳情頁定位「刪除」
2. `ui_tap` — 點「刪除」→ 確認
3. 等待 1 秒
4. → P3（模擬斷網 OFF — 恢復網路）

**驗證：UI**
- [ ] 無 alert 阻擋（刪除成功）
- [ ] 回到列表，$222 已消失

---

### Suite E: API 故障模式（2 tests）

---

#### E-1: API 故障 → 開銷 fallback 離線

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：Suite D 完成（網路已恢復）

**步驟**
1. → P4（API 故障 ON）
2. → P7 開始 log 擷取
3. `ui_tap` — Tab 1
4. → P2（新增開銷：amount=888, categoryIndex=0）
5. 等待 2 秒

**驗證：UI**
- [ ] `ui_view` — 仍顯示「已儲存 $888」（不顯示錯誤）

**驗證：Log**
```
[ExpenseStore] addExpense: mode=auth, online=true
[ExpenseStore] addExpense API failed, falling back to offline
```

---

#### E-2: API 故障 → 分類/帳本操作阻擋

**前置條件**：Auth=Authenticated, API 故障 ON（E-1 延續）
**依賴**：E-1

**步驟**
1. `ui_tap` — Tab 2（個人頁面）
2. `snapshot_ui` — 定位帳本設定或分類管理入口
3. `ui_tap` — 嘗試進入分類管理或執行分類操作

**驗證：UI**
- [ ] `snapshot_ui` 確認出現 alert 錯誤訊息

**清理**
4. → P4（API 故障 OFF）
5. 等待 3 秒（讓 sync 處理 $888 未同步開銷）

---

### Suite F: 分類管理（4 tests）

> 這組測試以 curl 為主（因分類操作需中文名稱，MCP 無法輸入中文）

---

#### F-1: 新增自訂分類

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：Suite E 清理完成

**步驟**
```bash
CAT_ID=$(curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/categories \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"e2e-test-cat","icon":"star","color":"#FF0000"}' | jq -r '.category.id')

echo "CAT_ID=$CAT_ID"
```

**驗證：DB**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.type==\"personal\") | .categories[] | select(.id==$CAT_ID)"
# 預期：{ "id": N, "name": "e2e-test-cat", "icon": "star", "color": "#FF0000" }
```

---

#### F-2: 編輯分類

**前置條件**：F-1 建立的分類
**依賴**：F-1

**步驟**
```bash
curl -s -X PUT $BASE/api/categories/$CAT_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"e2e-updated","icon":"heart","color":"#00FF00"}' | jq .
```

**驗證：DB**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.type==\"personal\") | .categories[] | select(.id==$CAT_ID) | .name"
# 預期："e2e-updated"
```

---

#### F-3: 刪除分類 → 級聯歸「其他」

**前置條件**：F-2 完成，建立一筆用此分類的開銷
**依賴**：F-2

**步驟**
```bash
# 用此分類建立開銷
EXP_FOR_CAT=$(curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"categoryId\":$CAT_ID,\"amount\":999,\"memo\":\"cascade test\"}" | jq -r '.expense.id')

# 刪除分類
curl -s -X DELETE $BASE/api/categories/$CAT_ID \
  -H "Authorization: Bearer $TOKEN" | jq .
# 預期：{ "success": true }
```

**驗證：DB**
```bash
# 開銷的 categoryId → null
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.type==\"personal\") | .expenses[] | select(.id==$EXP_FOR_CAT) | .categoryId"
# 預期：null
```

---

#### F-4: 分類排序

**前置條件**：有多個分類
**依賴**：F-3

**步驟**
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

**驗證：DB**
```bash
# 確認順序已反轉
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.type==\"personal\") | .categories[].id]"
# 預期：與 REVERSED 相同
```

---

### Suite G: 帳本管理（5 tests，curl 為主）

---

#### G-1: 建立群組帳本

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：無（獨立）

**步驟**
```bash
GROUP_RESP=$(curl -s -X POST $BASE/api/ledgers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"e2e-group","currency":"TWD"}')

GROUP_ID=$(echo $GROUP_RESP | jq -r '.ledger.id')
INVITE_CODE=$(echo $GROUP_RESP | jq -r '.ledger.inviteCode')

echo "GROUP_ID=$GROUP_ID, INVITE_CODE=$INVITE_CODE"
```

**驗證：DB**
```bash
# inviteCode 為 6 字元
echo $INVITE_CODE | wc -c
# 預期：7（6 字元 + 換行）

# 有 owner member
curl -s $BASE/api/ledgers/$GROUP_ID/members \
  -H "Authorization: Bearer $TOKEN" | jq '.members[] | select(.role=="owner")'
# 預期：存在

# 有預設分類
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.id==$GROUP_ID) | .categories | length"
# 預期：> 0
```

---

#### G-2: 第二用戶加入

**前置條件**：G-1 建立的群組帳本
**依賴**：G-1

**步驟**
```bash
curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$INVITE_CODE\"}" | jq .
```

**驗證：DB**
```bash
curl -s $BASE/api/ledgers/$GROUP_ID/members \
  -H "Authorization: Bearer $TOKEN" | jq '.members | length'
# 預期：2
```

---

#### G-3: 更新帳本名稱/幣別

**前置條件**：G-1 建立的群組帳本（無開銷）
**依賴**：G-2

**步驟**
```bash
curl -s -X PUT $BASE/api/ledgers/$GROUP_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"e2e-renamed"}' | jq .
```

**驗證：DB**
```bash
curl -s $BASE/api/ledgers/$GROUP_ID \
  -H "Authorization: Bearer $TOKEN" | jq '.ledger.name'
# 預期："e2e-renamed"
```

---

#### G-4: 退出帳本（已結清）

**前置條件**：G-2 第二用戶已加入，帳本無未結算開銷
**依賴**：G-3

**步驟**
```bash
# TOKEN2 退出
curl -s -X POST $BASE/api/ledgers/$GROUP_ID/leave \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' | jq .
# 預期：{ "success": true }
```

**驗證：DB**
```bash
curl -s $BASE/api/ledgers/$GROUP_ID/members \
  -H "Authorization: Bearer $TOKEN" | jq '.members | length'
# 預期：1（只剩 owner）
```

---

#### G-5: 最後成員退出 → 帳本刪除

**前置條件**：群組帳本只剩 1 位成員（G-4 TOKEN2 已退出）
**依賴**：G-4

**步驟**
```bash
# TOKEN 退出（最後成員）
curl -s -X POST $BASE/api/ledgers/$GROUP_ID/leave \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' | jq .
# 預期：{ "success": true }
```

**驗證：DB**
```bash
# 帳本不在 state 中
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.id==$GROUP_ID)] | length"
# 預期：0
```

---

### Suite H: 拆帳結算（3 tests，curl）

---

#### H-1: 3 人拆帳計算

**前置條件**：3 個帳號的 TOKEN
**依賴**：無（獨立）

**步驟**
```bash
# 建立群組帳本
STL_LEDGER=$(curl -s -X POST $BASE/api/ledgers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"e2e-settle","currency":"TWD"}' | jq -r '.ledger.id')

STL_INVITE=$(curl -s $BASE/api/ledgers/$STL_LEDGER \
  -H "Authorization: Bearer $TOKEN" | jq -r '.ledger.inviteCode')

# TOKEN2、TOKEN3 加入
curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$STL_INVITE\"}" > /dev/null

curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN3" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$STL_INVITE\"}" > /dev/null

# 取得 userId
MEMBERS=$(curl -s $BASE/api/ledgers/$STL_LEDGER/members -H "Authorization: Bearer $TOKEN")
USER1_ID=$(echo $MEMBERS | jq '.members[] | select(.isCurrentUser==true) | .userId')

MEMBERS2=$(curl -s $BASE/api/ledgers/$STL_LEDGER/members -H "Authorization: Bearer $TOKEN2")
USER2_ID=$(echo $MEMBERS2 | jq '.members[] | select(.isCurrentUser==true) | .userId')

MEMBERS3=$(curl -s $BASE/api/ledgers/$STL_LEDGER/members -H "Authorization: Bearer $TOKEN3")
USER3_ID=$(echo $MEMBERS3 | jq '.members[] | select(.isCurrentUser==true) | .userId')

# A 付 900、B 付 300、C 付 0
curl -s -X POST $BASE/api/ledgers/$STL_LEDGER/expenses \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":900,\"memo\":\"A paid\",\"paidByUserId\":$USER1_ID}" > /dev/null

curl -s -X POST $BASE/api/ledgers/$STL_LEDGER/expenses \
  -H "Authorization: Bearer $TOKEN2" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":300,\"memo\":\"B paid\",\"paidByUserId\":$USER2_ID}" > /dev/null

# 結算（人均 400：C→A 400、B→A 100）
curl -s -X POST $BASE/api/ledgers/$STL_LEDGER/settle \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"transfers\":[
    {\"fromUserId\":$USER3_ID,\"toUserId\":$USER1_ID,\"amount\":400},
    {\"fromUserId\":$USER2_ID,\"toUserId\":$USER1_ID,\"amount\":100}
  ]}" | jq .
```

**驗證：DB**
```bash
# 所有開銷 isSettled
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.id==$STL_LEDGER) | .expenses[].isSettled] | all"
# 預期：true

# Settlement 紀錄存在
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.id==$STL_LEDGER) | .settlements | length"
# 預期：1
```

---

#### H-2: 結算紀錄 transfers 快照

**前置條件**：H-1 結算完成
**依賴**：H-1

**步驟**
```bash
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.id==$STL_LEDGER) | .settlements[0].transfers"
```

**驗證：DB**
```bash
# transfers JSON 包含 2 筆轉帳
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq ".ledgers[] | select(.id==$STL_LEDGER) | .settlements[0].transfers | length"
# 預期：2

# 驗證金額
curl -s $BASE/api/state \
  -H "Authorization: Bearer $TOKEN" | jq "[.ledgers[] | select(.id==$STL_LEDGER) | .settlements[0].transfers[].amount] | sort"
# 預期：[100, 400]
```

---

#### H-3: 結算後可加入新成員

**前置條件**：H-1 帳本已結清
**依賴**：H-2

**步驟**
```bash
# 新帳號加入
TOKEN4=$(curl -s -X POST $BASE/api/auth/apple/callback \
  -H 'Content-Type: application/json' \
  -d '{"identityToken":"test4@test.com","isDev":true}' | jq -r '.token')

curl -s -X POST $BASE/api/ledgers/join \
  -H "Authorization: Bearer $TOKEN4" \
  -H 'Content-Type: application/json' \
  -d "{\"inviteCode\":\"$STL_INVITE\"}" | jq .
# 預期：200
```

**驗證：DB**
```bash
curl -s $BASE/api/ledgers/$STL_LEDGER/members \
  -H "Authorization: Bearer $TOKEN" | jq '.members | length'
# 預期：4
```

---

### Suite I: 狀態重整（2 tests）

---

#### I-1: 前景重整（含 Server 端新資料）

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：無（獨立）

**步驟**
1. `stop_app_sim` — 終止 App
2. 透過 curl 在 Server 新增一筆開銷：
   ```bash
   curl -s -X POST $BASE/api/ledgers/$PERSONAL_ID/expenses \
     -H "Authorization: Bearer $TOKEN" \
     -H 'Content-Type: application/json' \
     -d "{\"categoryId\":$FIRST_CAT,\"amount\":12345,\"memo\":\"server-side\"}" > /dev/null
   ```
3. → P7 開始 log 擷取
4. `launch_app_sim` — 重新啟動 App
5. 等待 5 秒（auth + refreshState）

**驗證：UI**
- [ ] → P5（明細列表），`snapshot_ui` 確認列表包含 $12,345 開銷

**驗證：Log**
```
[ExpenseStore] refreshState: start
[ExpenseStore] refreshState: received
```

---

#### I-2: 重整保留未同步開銷

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：I-1

**步驟**
1. → P3（模擬斷網 ON）
2. `ui_tap` — Tab 1
3. → P2（新增開銷：amount=55555, categoryIndex=0）
4. → P7 開始 log 擷取
5. `stop_app_sim` — 終止 App
6. → P3（此時 Debug 面板已隨 App 終止消失，模擬斷網自動重置）
7. `launch_app_sim` — 重新啟動 App（網路已恢復）
8. 等待 5 秒（auth + sync + refreshState）

**驗證：Log**
```
[ExpenseStore] syncOfflineExpenses: found 1 unsynced
[DataManager] rebuildFromState
```

**驗證：UI**
- [ ] → P5（明細列表），`snapshot_ui` 確認 $55,555 開銷仍存在

---

### Suite J: 邊界與權限（4 tests）

> 前提：先執行 P6 登出回 Guest 模式

---

#### J-1: 訪客累積 10 筆 → 備份提醒

**前置條件**：Auth=Guest, 無訪客開銷
**依賴**：登出後

**步驟**
1. 重複 → P2 新增開銷 10 次（amount=10,20,30,...,100, categoryIndex=0）
   - 或用簡化方式：快速輸入 10 筆小金額
2. 在第 10 筆儲存後，等待 2 秒

**驗證：UI**
- [ ] `snapshot_ui` 確認出現 alert 提醒登入備份

---

#### J-2: 訪客不可編輯分類

**前置條件**：Auth=Guest
**依賴**：J-1（或任何 Guest 狀態）

**步驟**
1. `ui_tap` — Tab 1
2. `snapshot_ui` — 定位分類區「設定」按鈕
3. `ui_tap` — 點「設定」（分類管理入口）

**驗證：UI**
- [ ] `snapshot_ui` 確認出現 alert「登入後可編輯」（或類似訊息）

---

#### J-3: 訪客不可建立群組帳本

**前置條件**：Auth=Guest
**依賴**：J-2

**步驟**
1. `snapshot_ui` — 定位帳本設定入口（LedgerSwitcher 齒輪圖示）
2. `ui_tap` — 點齒輪
3. `snapshot_ui` — 定位「建立群組帳本」或類似入口
4. `ui_tap` — 點建立

**驗證：UI**
- [ ] `snapshot_ui` 確認出現 LoginPromptView sheet

---

#### J-4: 已登入 + 離線 → 分類操作阻擋

**前置條件**：Auth=Authenticated, Network=Online
**依賴**：無

**步驟**
1. → P1（Dev 登入）— 若尚未登入
2. → P3（模擬斷網 ON）
3. 嘗試進入分類管理並操作

**驗證：UI**
- [ ] `snapshot_ui` 確認出現 alert「無法連線」（或類似離線提示）

**清理**
4. → P3（模擬斷網 OFF）

---

## 5. 執行順序與相依性

```
[DB Reset + Fresh Install (build_run_sim)]
    │
    ▼
Suite A: 認證流程（A-1 → A-6 依序）
    │
    ├─ A-6 後登出 ──→ Suite B: 訪客 CRUD（B-1 → B-4）
    │                      │
    │                      ▼
    │               B-4 後登入 ──→ Suite C: 已登入 CRUD（C-1 → C-5）
    │                                  │
    │                                  ▼
    │                             Suite D: 離線與同步（D-1 → D-5）
    │                                  │
    │                                  ▼
    │                             Suite E: API 故障（E-1 → E-2）
    │                                  │
    │                                  ▼
    │                             Suite F: 分類管理（F-1 → F-4，curl）
    │
    ├─ 獨立（curl）──→ Suite G: 帳本管理（G-1 → G-5）
    │
    ├─ 獨立（curl）──→ Suite H: 拆帳結算（H-1 → H-3）
    │
    ├─ 獨立 ──→ Suite I: 狀態重整（I-1 → I-2）
    │
    ▼
[登出回 Guest]
    │
    ▼
Suite J: 邊界與權限（J-1 → J-4）
```

**並行提示**：Suite G、H 為純 curl 測試，可與 Suite D/E/F 並行執行。

---

## 6. 結果記錄模板

| Suite | ID | 名稱 | 日期 | 結果 | 備註 |
|-------|----|------|------|------|------|
| A | A-1 | 全新安裝 → Guest | | | |
| A | A-2 | Dev 登入（無訪客開銷） | | | |
| A | A-3 | 登出 | | | |
| A | A-4 | 訪客 3 筆 → 登入上傳 | | | |
| A | A-5 | 登出 → 再加 2 筆 → 重新登入 | | | |
| A | A-6 | 冷啟動（有效 token） | | | |
| B | B-1 | Guest 新增開銷 | | | |
| B | B-2 | 檢視明細列表 | | | |
| B | B-3 | 編輯開銷 | | | |
| B | B-4 | 刪除開銷 | | | |
| C | C-1 | 新增開銷（線上） | | | |
| C | C-2 | 編輯已同步開銷 | | | |
| C | C-3 | 刪除已同步開銷 | | | |
| C | C-4 | 新增「其他」分類開銷 | | | |
| C | C-5 | 開銷列表按日期分組 | | | |
| D | D-1 | 離線新增開銷 | | | |
| D | D-2 | 離線編輯已同步開銷 → 阻擋 | | | |
| D | D-3 | 恢復網路 → 自動同步 | | | |
| D | D-4 | 離線編輯未同步開銷 → 允許 | | | |
| D | D-5 | 離線刪除未同步開銷 → 允許 | | | |
| E | E-1 | API 故障 → fallback 離線 | | | |
| E | E-2 | API 故障 → 操作阻擋 | | | |
| F | F-1 | 新增自訂分類 | | | |
| F | F-2 | 編輯分類 | | | |
| F | F-3 | 刪除分類 → 級聯歸「其他」 | | | |
| F | F-4 | 分類排序 | | | |
| G | G-1 | 建立群組帳本 | | | |
| G | G-2 | 第二用戶加入 | | | |
| G | G-3 | 更新帳本名稱 | | | |
| G | G-4 | 退出帳本（已結清） | | | |
| G | G-5 | 最後成員退出 → 帳本刪除 | | | |
| H | H-1 | 3 人拆帳計算 | | | |
| H | H-2 | 結算紀錄 transfers 快照 | | | |
| H | H-3 | 結算後可加入新成員 | | | |
| I | I-1 | 前景重整（含 Server 端新資料） | | | |
| I | I-2 | 重整保留未同步開銷 | | | |
| J | J-1 | 訪客累積 10 筆 → 備份提醒 | | | |
| J | J-2 | 訪客不可編輯分類 | | | |
| J | J-3 | 訪客不可建立群組帳本 | | | |
| J | J-4 | 已登入 + 離線 → 分類操作阻擋 | | | |

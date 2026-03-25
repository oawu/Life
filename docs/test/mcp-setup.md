# iOS 模擬器自動化測試（MCP Setup）

透過 MCP Server 讓 Claude Code 直接操控 iOS 模擬器，執行 UI 自動化測試。

---

## 架構

```
Claude Code
├── ios-simulator MCP ─── Facebook IDB ─── iOS Simulator（UI 互動）
└── XcodeBuildMCP ──────── xcodebuild ──── iOS Simulator（Build/Run/Log/UI Snapshot）
```

---

## 已安裝的 MCP Server

### 1. ios-simulator（UI 互動）

- **來源**：[joshuayoes/ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp)
- **用途**：tap / type / swipe / screenshot / accessibility describe

**安裝指令**：
```bash
# 1. 安裝 Facebook IDB（依賴）
brew install facebook/homebrew-fb/idb-companion
pip3 install fb-idb

# 2. 確認 idb 路徑
which idb  # 若不在 PATH，通常在 ~/Library/Python/3.9/bin/idb

# 3. 加入 Claude Code MCP（指定 idb 路徑）
claude mcp add ios-simulator \
  -e IOS_SIMULATOR_MCP_IDB_PATH=$HOME/Library/Python/3.9/bin/idb \
  -- npx -y ios-simulator-mcp
```

**提供的工具**：

| 工具 | 功能 |
|------|------|
| `get_booted_sim_id` | 取得已啟動的模擬器 UUID |
| `open_simulator` | 開啟 Simulator.app |
| `ui_describe_all` | 列出所有 accessibility 元素 |
| `ui_describe_point` | 查詢指定座標的元素 |
| `ui_tap` | 點擊座標 |
| `ui_type` | 輸入文字（僅 ASCII） |
| `ui_swipe` | 滑動 |
| `ui_view` | 截圖（壓縮 JPEG，直接回傳） |
| `screenshot` | 儲存截圖到檔案 |
| `install_app` | 安裝 .app / .ipa |
| `launch_app` | 啟動 App（by bundle ID） |

### 2. XcodeBuildMCP（Build + Log + UI Snapshot）

- **來源**：[getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)
- **用途**：build / run / test / log capture / UI hierarchy snapshot

**安裝指令**：
```bash
claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp
```

**常用工具**：

| 工具 | 功能 |
|------|------|
| `session_show_defaults` | 查看當前 session 設定 |
| `session_set_defaults` | 設定 project / scheme / simulator / bundleId |
| `build_run_sim` | Build + Install + Launch（一步到位） |
| `snapshot_ui` | 取得完整 UI hierarchy（含精確座標） |
| `start_sim_log_cap` | 開始擷取 App log |
| `stop_sim_log_cap` | 停止並回傳 log 內容 |
| `screenshot` | 截圖（path 或 base64） |

---

## 設定（本專案）

MCP 設定存在 `/Users/oa/.claude.json`（project scope）：

```json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"]
    },
    "ios-simulator": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "ios-simulator-mcp"],
      "env": {
        "IOS_SIMULATOR_MCP_IDB_PATH": "/Users/oa/Library/Python/3.9/bin/idb"
      }
    }
  }
}
```

### Session Defaults

每次啟動 Claude Code 後，需設定 XcodeBuildMCP 的 session defaults：

```
session_set_defaults:
  projectPath: /Users/oa/Workspace/32_Life/ios/Life.xcodeproj
  scheme: Life Dev
  simulatorName: iPhone 16
  bundleId: tw.iwi.life.beta
```

---

## 測試流程

### 完整端到端測試步驟

```
1. Build & Run App
   → build_run_sim（XcodeBuildMCP）

2. 開始擷取 Log
   → start_sim_log_cap({ captureConsole: true })

3. 取得 UI 元素座標
   → snapshot_ui（XcodeBuildMCP，回傳完整 accessibility hierarchy + 精確座標）

4. 操作 UI
   → ui_tap(x, y)      — 點擊按鈕/分類
   → ui_type(text)      — 輸入文字
   → ui_swipe(...)      — 滑動列表

5. 截圖驗證畫面
   → ui_view（ios-simulator，回傳壓縮圖片）

6. 停止 Log 擷取 + 驗證
   → stop_sim_log_cap({ logSessionId: "..." })
   → 比對預期 log 序列（見 app-log-tests.md）

7. 後端 API 驗證
   → curl 指令查詢 Server 資料（見 api-tests.md）
```

### 工具分工

| 任務 | 用哪個 MCP |
|------|-----------|
| Build & Run | XcodeBuildMCP |
| 取得 UI 元素座標 | XcodeBuildMCP（`snapshot_ui`，有完整 hierarchy） |
| 點擊/輸入/滑動 | ios-simulator（`ui_tap` / `ui_type` / `ui_swipe`） |
| 截圖看畫面 | ios-simulator（`ui_view`，直接回傳圖片） |
| 擷取 App Log | XcodeBuildMCP（`start/stop_sim_log_cap`） |

> **注意**：`ios-simulator` 的 `ui_describe_all` 在 SwiftUI App 可能回傳空結果，
> 改用 XcodeBuildMCP 的 `snapshot_ui` 可取得完整且精確的 UI hierarchy。

---

## 網路情境測試（Debug Flags）

透過 `#if DEBUG` flags 模擬網路異常，不需要關閉真實網路或 Docker。

| Flag | 位置 | 效果 |
|------|------|------|
| `NetworkMonitor.forceOffline` | NetworkMonitor.swift | `isOnline` 強制為 `false`，模擬**沒有網路** |
| `APIClient.shared.forceAPIFailure` | APIClient.swift | 所有 API 呼叫拋 `NSURLErrorCannotConnectToHost`，模擬**網路通但 API 不可達** |

### 測試情境對應

| 情境 | forceOffline | forceAPIFailure | App 行為 |
|------|-------------|----------------|----------|
| 正常 | false | false | API call → 成功 |
| 沒網路（EXP-008） | true | - | `isOnline=false` → 直接本地儲存 |
| API 不通（EXP-013） | false | true | `isOnline=true` → API 失敗 → fallback 離線 |

---

## 疑難排解

### MCP 啟動失敗

```bash
# 檢查 npm cache（常見問題）
npm cache verify

# 如有權限問題
sudo chown -R $(whoami) ~/.npm
npm cache clean --force
```

### idb 不在 PATH

```bash
# 加入 zshrc
echo 'export PATH="$HOME/Library/Python/3.9/bin:$PATH"' >> ~/.zshrc

# 或透過 MCP 環境變數指定
claude mcp add ios-simulator \
  -e IOS_SIMULATOR_MCP_IDB_PATH=$HOME/Library/Python/3.9/bin/idb \
  -- npx -y ios-simulator-mcp
```

### ui_describe_all 回傳空

SwiftUI App 的 accessibility tree 可能不完整，改用：
- `snapshot_ui`（XcodeBuildMCP）— 精確座標 + 完整 hierarchy
- `ui_view`（ios-simulator）— 截圖人眼判斷

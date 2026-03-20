# Serve 命令架構文件

本文件詳細說明 `serve` 命令的流程、架構與各模組的運作方式，供日後維護參考。

---

## 目錄

1. [概述](#概述)
2. [命令選項](#命令選項)
3. [啟動流程](#啟動流程)
4. [模組架構](#模組架構)
   - [Server 模組](#server-模組)
   - [Watcher 模組](#watcher-模組)
   - [Model 模組](#model-模組)
5. [檔案路徑解析](#檔案路徑解析)
6. [熱重載機制](#熱重載機制)
7. [關閉流程](#關閉流程)

---

## 概述

`serve` 命令用於啟動開發伺服器，提供以下功能：

- HTTP 伺服器（預設 port 8000）
- WebSocket 熱重載
- SCSS 即時編譯
- Icon 即時編譯
- Handlebars 模板渲染
- Model 資料注入

---

## 命令選項

| 選項 | 預設值 | 說明 |
|------|--------|------|
| `--port <port>` | `8000` | 指定 HTTP 伺服器端口 |
| `--env <env>` | `dev` | 環境設定 (`dev`/`beta`/`prod`) |
| `--minify` | `false` | 是否壓縮 CSS/JS/HTML |
| `--merge` | `false` | 是否合併 CSS/JS 至 HTML |
| `--host <host>` | `127.0.0.1` | 指定伺服器 Host |

### Docker 環境偵測

系統會自動偵測是否在 Docker 容器內執行：

```typescript
function isRunningInDocker(): boolean {
  // 方法 1: 檢查 /.dockerenv 檔案
  if (fs.existsSync('/.dockerenv')) return true

  // 方法 2: 檢查 /proc/1/cgroup 是否包含 docker 或 kubepods
  if (fs.existsSync('/proc/1/cgroup')) {
    const cgroup = fs.readFileSync('/proc/1/cgroup', 'utf8')
    if (cgroup.includes('docker') || cgroup.includes('kubepods')) return true
  }

  return false
}
```

若偵測到 Docker 環境，會自動將 host 設為 `0.0.0.0` 以允許外部連線。

---

## 啟動流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        serve 命令啟動                            │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. 載入配置 (resolveConfig)                                      │
│    - 讀取 lalilo.config.ts                                       │
│    - 合併命令列選項                                               │
│    - 設定 baseUrl、env、minify、merge                            │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 清空 CSS 目錄                                                 │
│    - emptyDir(config.runtime.cssDir)                            │
│    - CSS 目錄固定為 cmd/node_modules/_/css                       │
│    - 移除舊的編譯產物                                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 編譯 Icon                                                     │
│    - 掃描 icon/ 目錄下所有 style.css                             │
│    - 使用 p-limit(10) 控制並行數                                  │
│    - 輸出至 cmd/node_modules/_/icon/ 目錄                         │
│    - 顯示進度：正在編譯 Icon(n/total)...                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. 編譯 SCSS                                                     │
│    - 掃描 scss/ 目錄下所有 .scss（排除 _ 開頭）                    │
│    - 使用 p-limit(10) 控制並行數                                  │
│    - 輸出至 cmd/node_modules/_/css/ 目錄                         │
│    - 顯示進度：正在編譯 SCSS(n/total)...                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. 啟動檔案監聽 (createWatcher)                                   │
│    - 使用 chokidar 監聽 src/ 目錄                                 │
│    - 監聽 add、change、unlink 事件                                │
│    - 設定 awaitWriteFinish 防止重複觸發                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. 啟動 HTTP 伺服器 (createDevServer)                            │
│    - 建立 http.Server                                            │
│    - 建立 Socket.io 伺服器                                        │
│    - 監聽指定 port 和 host                                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. 連接 Watcher 和 Server                                        │
│    - watcher.onReload → server.reload()                         │
│    - watcher.ready(true) 開始處理檔案事件                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. 就緒                                                          │
│    - 顯示啟動耗時                                                 │
│    - 顯示伺服器網址                                               │
│    - 進入「開發紀錄」模式                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 模組架構

### Server 模組

**檔案位置：** `src/core/server/index.ts`

#### 介面定義

```typescript
export interface DevServer {
  start(): Promise<void>   // 啟動伺服器
  stop(): Promise<void>    // 停止伺服器
  reload(): void           // 發送重載訊號
  readonly url: string     // 伺服器 URL
}
```

#### 核心功能

1. **HTTP 請求處理** (`handleRequest`)
   - 解析 URL 路徑
   - 呼叫 `resolveFile` 取得檔案內容
   - 發送回應或 404 頁面

2. **檔案路徑解析** (`resolveFile`)
   - 根據 URL 路徑尋找對應檔案
   - 支援 HTML、靜態檔案

3. **HTML 檔案處理** (`tryHtmlFile`)
   - 讀取 HTML 模板
   - 載入對應的 Model
   - 使用 Handlebars 編譯
   - 注入 WebSocket 重載腳本

4. **靜態檔案處理** (`readStaticFile`)
   - 自動判斷 Content-Type
   - UTF-8 檔案：`.html`、`.css`、`.js`、`.json`、`.txt`、`.xml`、`.svg`
   - 其他檔案以 binary 方式讀取
   - **JS 檔案 `__tmpl__` 處理**：若 JS 檔案包含 `__tmpl__: 'name'`，自動注入模板內容

5. **WebSocket 重載**
   - 使用 Socket.io 建立 WebSocket 連線
   - `reload()` 方法發送 `'reload'` 事件

#### 404 頁面

支援自訂 404 頁面，透過 `config.yaml` 的 `serve.notFound` 設定：

```yaml
serve:
  notFound: 404.html   # 相對於 html 目錄
```

| 情境 | 行為 |
|------|------|
| `notFound` 有值且檔案存在 | 走完整 HTML 渲染流程（Model → Handlebars → reload script 注入），status 404 |
| `notFound` 有值但檔案不存在 | fallback 至內建 404 頁面 |
| `notFound` 為空字串或未設定 | 使用內建 404 頁面（程式碼編輯器風格） |

---

### Watcher 模組

**檔案位置：** `src/core/watcher/index.ts`

#### 介面定義

```typescript
export interface FileWatcher {
  start(): Promise<void>                              // 啟動監聽
  stop(): Promise<void>                               // 停止監聽
  ready(ready: boolean): void                         // 設定就緒狀態
  onReload(callback: (events: WatchEvent[]) => void): void  // 註冊重載回調
}
```

#### 核心功能

1. **檔案監聽設定**

```typescript
watcher = chokidar.watch(config.source.path, {
  persistent: true,
  ignoreInitial: true,        // 忽略初始掃描
  awaitWriteFinish: {
    stabilityThreshold: 100,  // 等待檔案寫入完成
    pollInterval: 100,
  },
})
```

2. **事件處理** (`handleFileEvent`)

根據檔案類型進行不同處理：

| 條件 | 處理方式 |
|------|----------|
| `scss/*.scss`（非 `_` 開頭） | 呼叫 `handleScssChange` |
| `icon/**/style.css` | 呼叫 `handleIconChange` |
| 其他監聽的副檔名 | 加入 `pendingEvents` 並觸發重載 |

3. **SCSS 變更處理** (`handleScssChange`)

- `add`/`change`：編譯 SCSS → CSS
- `unlink`：刪除對應的 CSS 檔案

**SCSS `@import` 路徑支援：**

| 寫法 | 解析結果 |
|------|----------|
| `@import "./_01-Var"` | 相對於當前檔案 |
| `@import "../_01-Var"` | 相對於當前檔案的上層 |
| `@import "/_01-Var"` | `src/scss/_01-Var.scss`（相對於 scss 根目錄） |
| `@import "@/CSS3/xxx"` | `@oawu/scss` 內建的 Libs 目錄 |
| `@import "Lalilo"` | `@oawu/scss` 內建的快取模組 |

使用範例：

```scss
// src/scss/page/a.scss
@import "/_01-Var";     // → src/scss/_01-Var.scss
@import "/_02-Lib";     // → src/scss/_02-Lib.scss
@import "@/CSS3/Font";  // → @oawu/scss 內建
```

4. **Icon 變更處理** (`handleIconChange`)

- `add`/`change`：編譯 Icon → CSS（輸出至 `cmd/node_modules/_/icon/`）
- `unlink`：刪除對應的 CSS 檔案

**命名規則：**
- `src/icon/icomoon/style.css` → `icon.css`（font-family: `'icon'`）
- `src/icon/aaa/style.css` → `aaa.css`（font-family: `'icon-aaa'`）

5. **重載防抖**

```typescript
const RELOAD_DELAY = 300  // 毫秒

function triggerReload(): void {
  if (reloadTimer) clearTimeout(reloadTimer)

  reloadTimer = setTimeout(() => {
    if (reloadCallback && pendingEvents.length > 0) {
      reloadCallback([...pendingEvents])
      pendingEvents = []
    }
  }, RELOAD_DELAY)
}
```

---

### Model 模組

**檔案位置：** `src/core/model/index.ts`

#### Model Context 介面

```typescript
export interface ModelContext {
  config: FullConfig                        // 完整配置物件
  Asset: () => Asset                        // Asset 建構函數
  jsEnv: string                             // JavaScript 環境變數
  require: (relativePath: string) => unknown // 載入相對路徑模組
}
```

#### `require` 函數說明

由於 Model 檔案會被複製到 `cmd/node_modules/_/model_tmp/` 執行，原生的 `require` 無法正確解析相對路徑。因此 Context 提供了特殊的 `require` 函數：

```typescript
require: (requirePath: string) => {
  let absolutePath: string
  if (requirePath.startsWith('/')) {
    // / 開頭：相對於 model 根目錄 (src/model/)
    absolutePath = path.join(config.source.dirs.model, requirePath.slice(1))
  } else {
    // 相對路徑：相對於當前 model 檔案
    absolutePath = path.resolve(modelDir, requirePath)
  }
  // 清除快取確保每次重新載入
  delete require.cache[require.resolve(absolutePath)]
  return require(absolutePath)
}
```

**路徑解析規則：**

| 寫法 | 解析結果 |
|------|----------|
| `require('./_base.js')` | 相對於當前檔案 |
| `require('../_base.js')` | 相對於當前檔案的上層 |
| `require('/_base.js')` | `src/model/_base.js`（相對於 model 根目錄） |

**使用範例：**

```javascript
// src/model/page/a.js
module.exports = ({ require }) => {
  // 以下兩種寫法等效
  const base = require('../_base.js')  // 相對路徑
  const base = require('/_base.js')    // / 開頭，相對於 src/model/

  return { /* ... */ }
}
```

這讓深層目錄的 Model 可以更簡潔地載入根目錄的共用模組。

#### 載入流程

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 檢查 Model 檔案是否存在                                        │
│    - 路徑：src/model/{page}.js                                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 讀取 Model 內容並計算 MD5 Hash                                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 複製到暫存目錄                                                 │
│    - 路徑：cmd/node_modules/_/model_tmp/{hash}.cjs              │
│    - 使用 .cjs 副檔名確保 CommonJS 格式                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. 使用 require() 載入模組                                        │
│    - 先清除 require.cache                                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. 建立 ModelContext                                             │
│    - config: 完整配置                                            │
│    - Asset: () => createAsset(config)                           │
│    - jsEnv: generateJsEnv(config)                               │
│    - require: 可載入相對路徑模組的函數                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. 執行 Model                                                    │
│    - 若是函數：modelExport(ctx)                                  │
│    - 若是物件：直接使用                                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. 解析 Model 資料 (resolveModelData)                            │
│    - Asset 實例 → 呼叫 toString()                                │
│    - 函數 → 執行並遞迴解析                                        │
│    - Promise → await 並遞迴解析                                   │
│    - 陣列/物件 → 遞迴處理每個元素                                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. 清理暫存檔                                                     │
│    - fs.unlinkSync(tmpFile)                                     │
└─────────────────────────────────────────────────────────────────┘
```

#### Model 檔案格式

**推薦格式（使用共用模組）：**

```
src/model/
├── _base.js      # 共用配置（_ 開頭不會被當作頁面 Model）
├── index.js      # 首頁
└── page.js       # 其他頁面
```

**`_base.js` - 共用配置：**

```javascript
module.exports = {
  title: 'Lalilo',

  // 共用的 Icon 資源
  coreIcon: ['icon'],

  // 共用的 SCSS 資源
  coreScss: [
    '_01-Core/01-Elements',
    '_01-Core/02-Vars',
    // ...
  ],

  // 共用的 JS 資源
  coreJs: [
    'https://unpkg.com/vue@3/dist/vue.global.js',
    '_01-Core/01-Helper.js',
    // ...
  ],

  // 建立包含共用資源的 Asset
  createAsset(Asset, options = {}) {
    const asset = Asset()

    this.coreIcon.forEach(icon => asset.icon(icon))
    this.coreScss.forEach(scss => asset.scss(scss))
    if (options.scss) {
      const scssList = Array.isArray(options.scss) ? options.scss : [options.scss]
      scssList.forEach(scss => asset.scss(scss))
    }

    this.coreJs.forEach(js => asset.js(js))
    if (options.js) {
      const jsList = Array.isArray(options.js) ? options.js : [options.js]
      jsList.forEach(js => asset.js(js))
    }

    return asset
  },
}
```

**`index.js` - 使用共用模組：**

```javascript
module.exports = ({ Asset, jsEnv, require }) => {
  const base = require('./_base.js')

  return {
    title: base.title,
    jsEnv,
    asset: () => base.createAsset(Asset, {
      scss: 'index',
      js: 'index.js',
    }),
  }
}
```

**`page.js` - 頁面專屬配置：**

```javascript
module.exports = ({ Asset, jsEnv, require }) => {
  const base = require('./_base.js')

  return {
    title: base.title + ' - Page',
    jsEnv,
    asset: () => base.createAsset(Asset, {
      scss: 'page',
      js: 'page.js',
    }),
  }
}
```

**簡單格式（不使用共用模組）：**

```javascript
module.exports = ({ Asset, jsEnv }) => ({
  title: 'Lalilo',
  jsEnv,
  asset: () => Asset()
    .icon('icon')
    .scss('index')
    .js('index.js'),
})
```

**舊格式（物件導出，相容但不推薦）：**

```javascript
module.exports = {
  title: 'Lalilo',
  // ...
}
```

#### 錯誤處理

當 Model 載入失敗時，會顯示：

- 檔案路徑
- 錯誤發生行號（從 stack trace 提取）
- 錯誤訊息

---

## 檔案路徑解析

Server 的 `resolveFile` 函數負責將 URL 路徑對應到實際檔案：

| URL 路徑 | 對應 HTML 檔案 | 對應 Model 檔案 |
|----------|----------------|-----------------|
| `/` | `html/index.html` | `model/index.js` |
| `/about` | `html/about.html` 或 `html/about/index.html` | `model/about.js` 或 `model/about/index.js` |
| `/about.html` | `html/about.html` | `model/about.js` |
| `/page/sub` | `html/page/sub.html` 或 `html/page/sub/index.html` | `model/page/sub.js` 或 `model/page/sub/index.js` |

### 靜態檔案

非 HTML 檔案的查找順序：

1. `src/html/` 目錄
2. `src/` 目錄

---

## 熱重載機制

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│    chokidar      │     │     Watcher      │     │     Server       │
│   (檔案系統)      │     │                  │     │                  │
└────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                        │                        │
         │  檔案變更事件           │                        │
         │─────────────────────>│                        │
         │                        │                        │
         │                        │  處理檔案              │
         │                        │  (SCSS/Icon 編譯)      │
         │                        │                        │
         │                        │  觸發重載（防抖 300ms） │
         │                        │─────────────────────>│
         │                        │                        │
         │                        │                        │  io.emit('reload')
         │                        │                        │────────────────────>
         │                        │                        │                    │
         │                        │                        │                    ▼
         │                        │                        │              ┌──────────┐
         │                        │                        │              │  瀏覽器   │
         │                        │                        │              │ WebSocket │
         │                        │                        │              │  Client   │
         │                        │                        │              └──────────┘
```

### 瀏覽器端腳本

HTML 頁面會自動注入以下 WebSocket 客戶端腳本：

```html
<script src="/socket.io/socket.io.js"></script>
<script>
  const socket = io()
  socket.on('reload', () => window.location.reload())
</script>
```

---

## 關閉流程

```
┌─────────────────────────────────────────────────────────────────┐
│ 收到 SIGINT (Ctrl+C) 或 SIGTERM 訊號                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 檢查是否已在關閉中                                                │
│ - 若是：強制退出 (process.exit(1))                               │
│ - 若否：設定 isClosing = true                                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 顯示「正在關閉...（再按一次強制退出）」                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 並行執行關閉程序（設定 3 秒超時）                                  │
├─────────────────────────────────────────────────────────────────┤
│ watcher.stop()                                                  │
│ - 清除 reloadTimer                                              │
│ - 呼叫 chokidar.close()                                         │
│ - 設定 isReady = false                                          │
├─────────────────────────────────────────────────────────────────┤
│ server.stop()                                                   │
│ - io.disconnectSockets(true)  斷開所有 WebSocket 連線            │
│ - io.close()                  關閉 Socket.io                     │
│ - httpServer.closeAllConnections()  強制關閉 HTTP 連線           │
│ - httpServer.close()          關閉 HTTP 伺服器                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ process.exit(0)                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 重要實作細節

1. **雙擊 Ctrl+C 強制退出**：第二次按下 Ctrl+C 會立即退出，防止卡住

2. **3 秒超時**：關閉程序若超過 3 秒會自動退出

3. **強制斷開連線**：
   - `io.disconnectSockets(true)`：立即斷開所有 Socket.io 連線
   - `httpServer.closeAllConnections()`：強制關閉所有 HTTP 連線（Node.js 18.2+）

---

## 目錄結構

```
cmd/
├── config.yaml                 # 預設配置（可自訂）
├── src/
│   ├── cli/
│   │   └── commands/
│   │       └── serve.ts        # serve 命令入口
│   ├── core/
│   │   ├── server/
│   │   │   └── index.ts        # HTTP 伺服器 + WebSocket
│   │   ├── watcher/
│   │   │   └── index.ts        # 檔案監聽器
│   │   ├── model/
│   │   │   └── index.ts        # Model 載入器
│   │   ├── compiler/
│   │   │   ├── scss.ts         # SCSS 編譯器
│   │   │   ├── icon.ts         # Icon 編譯器（輸出 CSS）
│   │   │   └── html.ts         # HTML 處理（注入重載腳本）
│   │   ├── asset/
│   │   │   └── index.ts        # Asset 資源管理（icon/scss/js）
│   │   └── config/
│   │       └── index.ts        # 配置解析
│   ├── utils/
│   │   ├── logger.ts           # 日誌工具（含 loading 效果）
│   │   ├── fs.ts               # 檔案系統工具
│   │   └── errors.ts           # 錯誤處理
│   └── types/
│       └── index.ts            # TypeScript 型別定義
└── node_modules/
    └── _/
        ├── css/                # SCSS 編譯後的 CSS
        ├── icon/               # Icon 編譯後的 CSS
        └── model_tmp/          # Model 暫存目錄（自動清理）

src/
├── model/
│   ├── _base.js                # 共用配置（coreIcon/coreScss/coreJs）
│   ├── index.js                # 首頁 Model
│   └── page.js                 # 其他頁面 Model
└── ...
```

---

## 相關檔案

| 檔案 | 說明 |
|------|------|
| `cmd/config.yaml` | 預設配置（可自訂 port、host 等） |
| `cmd/src/cli/commands/serve.ts` | 命令入口，處理選項、啟動流程 |
| `cmd/src/core/server/index.ts` | HTTP 伺服器、WebSocket、檔案路徑解析 |
| `cmd/src/core/watcher/index.ts` | 檔案監聽、SCSS/Icon 編譯觸發 |
| `cmd/src/core/model/index.ts` | Model 載入、執行、資料解析 |
| `cmd/src/core/compiler/scss.ts` | SCSS 編譯 |
| `cmd/src/core/compiler/icon.ts` | Icon 編譯 |
| `cmd/src/core/compiler/html.ts` | HTML 處理、注入重載腳本 |
| `cmd/src/core/compiler/tmpl.ts` | JS 模板注入處理（`__tmpl__`） |
| `cmd/src/core/compiler/el3.ts` | El3 語法編譯器 |
| `cmd/src/utils/logger.ts` | 日誌輸出、loading 效果 |
| `src/model/_base.js` | Model 共用配置（CSS/JS 資源列表） |
| `src/model/index.js` | 首頁 Model |
| `src/model/page.js` | 其他頁面 Model |

---

## 維護注意事項

1. **Model 暫存目錄**：`node_modules/_/model_tmp` 目錄會自動建立和清理，不需手動管理

2. **並行編譯**：SCSS 和 Icon 編譯使用 `p-limit(10)` 控制並行數，避免系統資源耗盡

3. **Docker 環境**：自動偵測 Docker 並調整 host 設定

4. **關閉卡住問題**：若遇到關閉卡住，已實作：
   - 雙擊 Ctrl+C 強制退出
   - 3 秒超時自動退出
   - 強制斷開所有連線

5. **重載防抖**：檔案變更後等待 300ms 再觸發重載，避免連續變更造成多次重載

6. **Model 共用模組**：
   - `_base.js` 使用 `_` 開頭命名，不會被視為頁面 Model
   - 使用 Context 提供的 `require` 函數載入，而非原生 `require`
   - 共用資源（coreIcon/coreScss/coreJs）集中在 `_base.js` 管理，方便維護

7. **Asset 方法**：
   - `.icon('name')` - 載入 Icon CSS（`cmd/node_modules/_/icon/{name}.css`）
   - `.scss('path')` - 載入 SCSS（支援 `'index'`、`'index.scss'`、`'index.css'` 格式）
   - `.js('path')` - 載入 JavaScript

8. **`__tmpl__` 模板注入**：
   - JS 檔案中的 `__tmpl__: 'name'` 會自動替換為 `template: \`...\``
   - 模板檔案查找路徑：`src/tmpl/{name}.html` 或 `src/tmpl/{name}.el3`
   - 優先級：`.html` > `.el3`
   - El3 為類 Pug 的縮進式 HTML 語法
   - 若找不到對應模板，該行會被移除

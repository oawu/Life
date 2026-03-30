# Worker 模組說明

---

## Core 模組

### config.js

讀取 backend PHP 設定檔，與 PHP `Config::get()` 行為一致。

```javascript
const config = require('./core/config')

config.env()                    // 'Local' | 'Development' | 'Beta' | 'Production'
config.getConfig('Worker')      // 解析 Worker.php → { host, port, cliToken, cliDir }
config.getMySqlConfig()         // 解析 MySql.php → { host, user, password, database }
config.getKey()                 // 解析 _Key.php → KEY 字串

config.BACKEND_DIR              // backend 絕對路徑
config.WORK_DIR                 // work 絕對路徑
config.CONCURRENCY              // 3（Job 並發數）
config.TIMEOUT                  // 300（Job 超時秒數）
config.POLL_INTERVAL            // 3000（Job 輪詢間隔 ms）
config.MAX_RETRY                // 3（Job 最大重試次數）
```

### db.js

MySQL 連線池（mysql2/promise），最多 5 條連線，自動設定 UTC+8 時區。

```javascript
const db = require('./core/db')

const rows = await db.query('SELECT * FROM User WHERE id = ?', [1])
const result = await db.execute('UPDATE User SET name = ? WHERE id = ?', ['test', 1])
await db.close()
```

### dispatcher.js

Job 調度引擎。從 `Job` 表取出 pending/failed jobs，交給對應 processor 執行。

- **並發控制**：p-limit 限制同時執行數（預設 3）
- **Stale 清理**：啟動時將 processing 狀態的 jobs 重設為 pending
- **輪詢 + 通知**：每 3 秒輪詢 + POST /notify 即時觸發
- **超時保護**：每個 Job 最長 300 秒
- **重試機制**：失敗後 retryCount < MAX_RETRY 可重試
- **記憶體監控**：每 60 秒記錄 RSS/heap 狀態

```javascript
const dispatcher = require('./core/dispatcher')

await dispatcher.start()    // 啟動（含 stale 清理 + 初始派發）
dispatcher.notify()         // 收到通知，立即派發
dispatcher.status()         // { running, activeJobs, pendingJobs, totalProcessed, system }
dispatcher.stop()           // 停止
```

### logger.js

分類日誌，非同步佇列寫入。

```javascript
const logger = require('./core/logger')

const log = logger.create('main')     // 建立 main 分類 logger
log.info('message')                   // [HH:mm:ss] [INFO] message
log.warn('message')                   // [HH:mm:ss] [WARN] message
log.error('message')                  // [HH:mm:ss] [ERROR] message

await logger.waitFinish()             // 等待佇列寫入完成（關閉時用）
```

分類與目錄對應：

| 分類 | 目錄 |
|------|------|
| `main` | `File/Log/Worker/App/` |
| `request` | `File/Log/Worker/Request/` |

### queue.js

Named Queue，每個名稱對應一個 p-limit(1) 序列化佇列。

```javascript
const queue = require('./core/queue')

const limit = queue.get('my-queue')   // 取得（lazy init）
await limit(() => doWork())           // 序列化執行
queue.names()                         // 所有 queue 名稱
queue.stats()                         // { 'my-queue': { active: 0, pending: 0 } }
```

### router.js

HTTP 路由引擎。

```javascript
const router = require('./core/router')

router.setAuthToken('my-token')

router.route('GET', '/status', handler)
router.route('POST', '/exec/cli', handler, { auth: true })

// 在 http.createServer 中使用
const server = http.createServer((req, res) => router.handle(req, res))
```

特性：
- JSON body 解析（1MB 上限）
- Bearer Token 驗證
- 統一錯誤處理（非 Production 輸出 stack）
- 請求日誌（方法、路徑、狀態碼、耗時）

### system-monitor.js

CPU/記憶體監控，每 2 秒取樣 CPU。

```javascript
const monitor = require('./core/system-monitor')

monitor.start()
monitor.snapshot()   // { cpu, memory, process, uptime }
monitor.stop()
```

### time.js

UTC+8 時間工具。

```javascript
const time = require('./core/time')

time.today()        // '20260331'（Logger 檔名）
time.todayDash()    // '2026-03-31'（Scheduler 日期）
time.timeStr()      // '14:30:00'（Logger 時間）
time.datetime()     // '2026-03-31 14:30:00'（MySQL datetime）
time.hourMinute()   // { hour: 14, minute: 30 }（Scheduler 比對）
```

---

## Services

### exec-cli.js

CLI 命令執行服務。

```javascript
const execCli = require('./services/exec-cli')

// 直接執行
const result = await execCli.exec({ cmd: 'php Public/index.php test/worker' })

// Named Queue 序列化
const result = await execCli.exec({ cmd: '...', queue: 'my-queue' })

// Debounce（3 秒內同命令只執行最後一次）
const result = await execCli.exec({ cmd: '...', delay: 3 })

// 自訂超時（秒）
const result = await execCli.exec({ cmd: '...', timeout: 60 })

// 回傳格式
// { ok: true/false, cmd, exitCode, stdout, stderr, error? }

// Graceful shutdown
execCli.killAll()
```

特性：
- 預設超時 10 分鐘，最大 buffer 10MB
- Debounce 機制：同命令去重
- Named Queue：同 queue 內序列化
- 工作目錄：讀取 `Worker.php` 的 `cliDir`，空值 = BACKEND_DIR
- 環境變數注入 `WORKER_TOKEN`

### scheduler.js

定時排程服務，每 60 秒檢查一次。

```javascript
const scheduler = require('./services/scheduler')

scheduler.start()   // 啟動
scheduler.stop()    // 停止
```

任務定義格式（目前為空，未來擴充）：

```javascript
const TASKS = [
  { name: 'task-name', hour: 1, minute: 0, cmd: 'php Public/index.php some/route' },
]
```

- 每個任務每天只執行一次（防重複）
- 執行結果記錄到 main logger

---

## Controllers

### worker.js

| 路由 | 說明 |
|------|------|
| `POST /worker/notify` | 觸發 Dispatcher 立即檢查 Job 表 |
| `GET /worker/status` | 回傳 Dispatcher 狀態快照 |

### exec.js

| 路由 | 說明 |
|------|------|
| `POST /exec/cli` | 執行 CLI 命令（需 Bearer auth） |

Body 參數：

| 欄位 | 必填 | 說明 |
|------|------|------|
| `cmd` | ✓ | 要執行的命令 |
| `queue` | ✗ | Named Queue 名稱 |
| `delay` | ✗ | 延遲秒數（debounce） |
| `timeout` | ✗ | 超時秒數 |

---

## Routes

### main.js

路由註冊表，在 `index.js` 啟動時呼叫 `routes.register()`。

| Method | Path | Auth | Controller |
|--------|------|------|------------|
| POST | `/worker/notify` | ✗ | `worker.notify` |
| GET | `/worker/status` | ✗ | `worker.status` |
| POST | `/exec/cli` | ✓ | `exec.cli` |

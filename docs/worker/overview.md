# Worker 架構總覽

Life Worker 是一個 Node.js 常駐服務，負責：

- **CLI 執行**：後端透過 HTTP 觸發 PHP CLI 命令
- **排程任務**：定時執行背景工作
- **Job 調度**：非同步任務處理（未來擴充）

---

## 目錄結構

```
worker/
├── package.json                 # 依賴：mysql2, p-limit
├── ecosystem.config.js          # pm2 設定（讀 backend _Env.php）
└── src/
    ├── index.js                 # HTTP server + 生命週期
    ├── core/
    │   ├── config.js            # 讀取 backend PHP 設定
    │   ├── db.js                # MySQL 連線池
    │   ├── dispatcher.js        # Job 調度引擎
    │   ├── logger.js            # 分類日誌
    │   ├── queue.js             # Named Queue（p-limit 序列化）
    │   ├── router.js            # HTTP 路由引擎
    │   ├── system-monitor.js    # CPU/記憶體監控
    │   └── time.js              # UTC+8 時間工具
    ├── services/
    │   ├── exec-cli.js          # CLI 執行（debounce/queue/timeout）
    │   └── scheduler.js         # 每分鐘定時排程
    ├── controllers/
    │   ├── worker.js            # POST /worker/notify + GET /worker/status
    │   └── exec.js              # POST /exec/cli
    └── routes/
        └── main.js              # 路由定義表
```

---

## 觸發流程

### PHP → Worker CLI 執行

```
PHP Controller
  → Worker::cli()->maple('some/route')->exec()
  → HTTP POST /exec/cli (Bearer auth)
  → Worker 收到請求
  → exec-cli.js 執行 child_process.exec()
  → 回傳 { ok, cmd, exitCode, stdout, stderr }
```

### PHP → Worker Notify（Job 觸發）

```
PHP Controller
  → Worker::notify()
  → HTTP POST /worker/notify (fire-and-forget)
  → Dispatcher 立即檢查 Job 表
  → 取出 pending/failed jobs → 執行 processor
```

### 排程任務

```
Scheduler（每 60 秒檢查）
  → 比對 hour/minute
  → 同日同任務只執行一次
  → exec-cli.js 執行 CLI 命令
```

---

## HTTP 端點

| Method | Path | Auth | 說明 |
|--------|------|------|------|
| POST | `/worker/notify` | ✗ | 觸發 Job Dispatcher 立即派發 |
| GET | `/worker/status` | ✗ | 回傳 Dispatcher 狀態 |
| POST | `/exec/cli` | ✓ | 執行 CLI 命令 |

---

## Config 共享機制

Worker 與 PHP 後端共享設定檔：

1. **環境判斷**：Worker 啟動時讀取 `backend/System/_Env.php` 取得 ENVIRONMENT
2. **設定讀取**：`config.getConfig('Worker')` 解析 `backend/Config/Worker.php`（或環境覆蓋）
3. **MySQL 設定**：`config.getMySqlConfig()` 解析 `backend/Config/MySql.php`

### Worker.php 設定

```php
return [
  'host'     => '127.0.0.1',   // Worker HTTP host
  'port'     => 8700,           // Worker HTTP port
  'cliToken' => '',             // Bearer Token（CLI 驗證）
  'cliDir'   => '',             // CLI 工作目錄（空 = BACKEND_DIR）
];
```

---

## PHP Lib 使用

### Worker::status()

```php
$status = Worker::status();  // GET /worker/status → array | null
```

### Worker::notify()

```php
Worker::notify();  // POST /worker/notify (fire-and-forget)
```

### Worker::cli()

```php
// 同步執行，等待回應
$result = Worker::cli()
  ->maple('some/route')        // php Public/index.php some/route
  ->queue('my-queue')          // Named Queue 序列化
  ->delay(3)                   // 延遲 3 秒（debounce）
  ->timeout(60)                // 超時 60 秒
  ->exec();                    // 回傳 ['code' => int, 'response' => string]

// Fire-and-forget，不等回應
Worker::cli()
  ->maple('some/route')
  ->fire();
```

---

## 日誌

日誌存放在 `backend/File/Log/Worker/` 下：

| 分類 | 目錄 | 內容 |
|------|------|------|
| main | `App/` | 啟動、關閉、Job 處理、排程執行 |
| request | `Request/` | HTTP 請求記錄（方法、路徑、狀態碼、耗時） |

格式：`[HH:mm:ss] [LEVEL] message`

每日自動建新檔：`YYYYMMDD.log`

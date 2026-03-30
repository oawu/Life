# Worker 安裝與部署

---

## 前置需求

- **Node.js** 18+
- **pm2**：`npm install -g pm2`
- **MySQL**：與後端共用同一個資料庫

---

## Local 安裝（Docker 環境）

### 1. 安裝依賴

```bash
cd worker
npm install
```

### 2. 確認後端設定

確保 `backend/System/_Env.php` 和 `backend/Config/Local/MySql.php` 已存在（`php Maple.php init Local`）。

### 3. 設定 Worker Config

建立 `backend/Config/Local/Worker.php`（可選）：

```php
<?php

return [
  'host'     => '127.0.0.1',
  'port'     => 8700,
  'cliToken' => 'your-secret-token',
  'cliDir'   => '',
];
```

### 4. 啟動

```bash
# 開發模式（自動重啟）
cd worker
npm run dev

# 或使用 pm2
pm2 start ecosystem.config.js
```

### 5. 驗證

```bash
# 檢查狀態
curl http://127.0.0.1:8700/worker/status

# 透過 PHP CLI 測試
docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Public/index.php test/worker"
```

---

## Production 部署

### 1. 安裝依賴

```bash
cd worker
npm install --production
```

### 2. 啟動

```bash
pm2 start ecosystem.config.js
pm2 save
```

### 3. 開機自啟動

```bash
pm2 startup
pm2 save
```

---

## pm2 管理指令

```bash
# 啟動
pm2 start ecosystem.config.js

# 檢視狀態
pm2 status

# 檢視日誌
pm2 logs life-worker          # 即時日誌
pm2 logs life-worker --lines 100  # 最近 100 行

# 重啟
pm2 restart life-worker

# 停止
pm2 stop life-worker

# 刪除
pm2 delete life-worker
```

---

## 日誌位置

| 日誌 | 路徑 |
|------|------|
| pm2 日誌 | `backend/File/Log/Worker/Pm2.log` |
| App 日誌 | `backend/File/Log/Worker/App/YYYYMMDD.log` |
| Request 日誌 | `backend/File/Log/Worker/Request/YYYYMMDD.log` |

---

## 疑難排解

### Worker 無法啟動

1. 檢查 Node.js 版本：`node -v`（需 18+）
2. 檢查 `backend/System/_Env.php` 是否存在
3. 檢查 MySQL 連線設定是否正確
4. 查看 pm2 日誌：`pm2 logs life-worker`

### PHP 連不上 Worker

1. 確認 Worker 正在運行：`pm2 status`
2. 確認 port 正確：`curl http://127.0.0.1:8700/worker/status`
3. 確認 `backend/Config/Worker.php`（或環境覆蓋）的 host/port 設定

### CLI 執行失敗

1. 確認 `cliToken` 設定一致（Worker config 與 PHP config 須相同）
2. 確認 `cliDir` 指向正確的 backend 目錄
3. 檢查 App 日誌：`backend/File/Log/Worker/App/`

### Port 衝突

Life Worker 使用 port `8700`。若與其他服務衝突，修改 `backend/Config/Worker.php` 的 `port` 值。

# 更新 Postman Collection

根據目前的路由，更新 Postman Collection 與 README。

## 檔案位置

| 檔案 | 用途 |
|------|------|
| `docs/postman/Life-API.postman_collection.json` | API Collection |
| `docs/postman/Life-Worker.postman_collection.json` | Worker Collection |
| `docs/postman/Life-Local.postman_environment.json` | 環境變數（API + Worker 共用） |
| `docs/postman/README.md` | 文件說明（涵蓋 API + Worker） |

## 步驟

### API Collection

1. 讀取 `backend/Router/Main.php` 取得所有 API 路由
2. 讀取現有的 API Collection JSON，比對缺少的 API
3. 為新 API 新增 Request 項目
4. 同步更新 `docs/postman/README.md` 的 API Collection 結構表格
5. 若有新的環境變數需求，同步更新 Environment 檔案

### Worker Collection

1. 讀取 `worker/src/routes/main.js` 取得所有 Worker 路由
2. 讀取現有的 Worker Collection JSON，比對缺少的端點
3. 為新端點新增 Request 項目
4. 同步更新 `docs/postman/README.md` 的 Worker Collection 結構表格
5. 若有新的環境變數需求，同步更新 Environment 檔案

## Collection 結構規則

### 資料夾分組

- **API Collection**：依 Controller 命名空間分組（如 Auth、Album、Photo），每個資料夾對應 `Router/Main.php` 中的一組路由。
- **Worker Collection**：依 Controller 分組（Worker、Exec、Notify），每個資料夾對應 `routes/main.js` 中的一組路由。同一 API 有多種使用情境時，分別建立 Request。

### Request 命名格式

```
{序號} | {🔐 }{名稱}
```

- 序號：兩位數字，同資料夾內遞增（01、02、03...）
- 🔐：需要認證的 API 加上此標記
- 名稱：簡短描述 API 功能

### 認證設定

需認證的 Request 加上 auth 區塊：

#### API Collection（使用 `{{--token}}`）

```json
"auth": {
  "type": "bearer",
  "bearer": [
    {
      "key": "token",
      "value": "{{--token}}",
      "type": "string"
    }
  ]
}
```

#### Worker Collection（使用 `{{--cli-token}}`）

```json
"auth": {
  "type": "bearer",
  "bearer": [
    {
      "key": "token",
      "value": "{{--cli-token}}",
      "type": "string"
    }
  ]
}
```

### URL 格式

#### API Collection

```json
"url": {
  "raw": "{{baseurl}}api/auth/me",
  "host": ["{{baseurl}}api"],
  "path": ["auth", "me"]
}
```

- `host` 固定為 `["{{baseurl}}api"]`
- `path` 為 `api/` 之後的路徑段，拆成陣列
- 路徑參數使用環境變數（如 `{{--album-id}}`），不要硬編碼 ID

#### Worker Collection

```json
"url": {
  "raw": "{{workerurl}}exec/cli",
  "host": ["{{workerurl}}exec"],
  "path": ["cli"]
}
```

- `host` 為 `["{{workerurl}}" + 第一段路徑]`
- `path` 為第一段之後的路徑段，拆成陣列
- Worker 認證使用 `{{--cli-token}}`（非 `{{--token}}`）

### Body 格式

POST/PUT/PATCH 請求使用 raw JSON：

```json
"body": {
  "mode": "raw",
  "raw": "{\n    \"key\": \"value\"\n}",
  "options": {
    "raw": {
      "language": "json"
    }
  }
}
```

- JSON 內容使用 4 格空白縮排
- 填入合理的測試資料
- 引用其他 API 回傳的 ID 時，使用環境變數（如 `{{--folder-id}}`）

### GET 請求

GET 請求加上 `disableBodyPruning` 和空 body：

```json
"protocolProfileBehavior": {
  "disableBodyPruning": true
},
"request": {
  "method": "GET",
  "body": {
    "mode": "raw",
    "raw": "",
    "options": { "raw": { "language": "json" } }
  }
}
```

### Test Script（自動存環境變數）

建立類 API（回傳新資源）需加上 Test Script，自動將回傳的 ID 存入環境變數，供後續 API 引用。

#### 變數命名規則

- 變數名稱以 `--` 前綴 + 資源名稱 + `-id` 組成
- 例：`--token`、`--album-id`、`--folder-id`、`--photo-id`

#### 登入類（回傳 token）

```json
"event": [
  {
    "listen": "test",
    "script": {
      "exec": [
        "var data = JSON.parse(responseBody)",
        "",
        "if (data && data.token)",
        "    postman.setEnvironmentVariable(\"--token\", data.token)",
        "else",
        "    throw Error('格式錯誤！')"
      ],
      "type": "text/javascript"
    }
  }
]
```

#### 建立類（回傳資源 ID）

根據資源類型存入對應變數：

```json
"event": [
  {
    "listen": "test",
    "script": {
      "exec": [
        "var data = JSON.parse(responseBody)",
        "",
        "if (data && data.resource && data.resource.id)",
        "    postman.setEnvironmentVariable(\"--resource-id\", data.resource.id)",
        "else",
        "    throw Error('格式錯誤！')"
      ],
      "type": "text/javascript"
    }
  }
]
```

### 同一 API 多種情境

若同一 API 有多種使用情境（如不同 type、有無 parentId），分別建立 Request，命名區分用途。

## README 更新規則

`docs/postman/README.md` 的 Collection 結構表格需同步更新：

```markdown
### {資料夾名稱}

| # | 名稱 | 方法 | 路由 | 認證 | 說明 |
|---|------|------|------|------|------|
| 01 | 名稱 | POST | `/api/...` | Bearer | 說明 |
```

- 路由中的路徑參數使用環境變數格式（如 `/api/album/{{--album-id}}`）
- 說明欄標注自動存入的環境變數（如「自動存 `--album-id`」）

## 注意事項

- 保持 JSON 格式整齊（2 格縮排）
- `raw` 內的 JSON 字串使用 `\n` 和 4 格空白 `    ` 縮排
- 新增環境變數時，同步更新 Environment 和 README 環境變數表格

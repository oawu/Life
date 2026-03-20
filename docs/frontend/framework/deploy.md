# Deploy 部署系統文件

> 本文件詳細說明 Lalilo 的部署系統架構、流程與實作細節，供後續維護與開發參考。

---

## 目錄

1. [概述](#概述)
2. [命令列介面](#命令列介面)
3. [GitHub Pages 部署流程](#github-pages-部署流程)
4. [AWS S3 部署流程](#aws-s3-部署流程)
5. [核心函數說明](#核心函數說明)
6. [資料結構](#資料結構)
7. [錯誤處理](#錯誤處理)
8. [效能優化](#效能優化)

> **相關文件**：若要串聯 build + deploy 流程，請參考 [Flow 流程系統文件](./flow.md)

---

## 概述

部署系統支援兩種目標：

| 目標 | 說明 | 適用場景 |
|------|------|----------|
| **GitHub Pages** | 透過 Git 推送至 GitHub Pages | 個人專案、開源專案、靜態網站 |
| **AWS S3** | 上傳至 S3 Bucket 並支援增量更新 | 企業網站、需要 CDN 的專案 |

---

## 命令列介面

### 基本指令

```bash
# 執行部署
npm run deploy -- [選項]
```

### 選項參數

#### 通用選項

| 選項 | 說明 | 預設值 |
|------|------|--------|
| `--goal <goal>` | 部署目標 (`github` 或 `s3`) | **必填** |
| `--env <env>` | 環境 (`dev`/`beta`/`prod`) | `prod` |
| `--url <url>` | 基礎 URL | (自動生成或必填) |
| `--prefix <prefix>` | 前綴路徑 | `''` |

#### GitHub 專用選項

| 選項 | 說明 | 預設值 |
|------|------|--------|
| `--gh-account <account>` | GitHub 帳號 | **必填** |
| `--gh-repository <repository>` | GitHub 儲存庫 | **必填** |
| `--gh-branch <branch>` | 部署分支 | `gh-pages` |
| `--gh-message <message>` | Commit 訊息 | `🚀 部署！` |

#### S3 專用選項

| 選項 | 說明 | 預設值 |
|------|------|--------|
| `--s3-bucket <bucket>` | S3 Bucket 名稱 | **必填** |
| `--s3-access <access>` | AWS Access Key ID | **必填** |
| `--s3-secret <secret>` | AWS Secret Access Key | **必填** |
| `--s3-region <region>` | AWS Region | **必填** |

### 使用範例

```bash
# 部署到 GitHub Pages
npm run deploy -- --goal github --gh-account myaccount --gh-repository myrepo

# 部署到 AWS S3
npm run deploy -- --goal s3 \
  --url https://example.com/ \
  --s3-bucket my-bucket \
  --s3-access AKIAXXXXXXXX \
  --s3-secret xxxxxxxx \
  --s3-region ap-northeast-1

# 帶前綴的部署
npm run deploy -- --goal github \
  --gh-account myaccount \
  --gh-repository myrepo \
  --prefix v2
```

---

## GitHub Pages 部署流程

### 流程圖

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Pages 部署流程                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 建立暫存目錄                                                  │
│     └── fs.mkdtemp() 在系統 temp 目錄建立                         │
│                                                                 │
│  2. 清空暫存目錄                                                  │
│     └── fs.emptyDir() 確保目錄乾淨                                │
│                                                                 │
│  3. 掃描本地檔案                                                  │
│     └── filterLocalFiles() 過濾忽略檔案                           │
│                                                                 │
│  4. 複製檔案至暫存目錄                                             │
│     └── pLimit(20) 並行複製，保留目錄結構                          │
│                                                                 │
│  5. 初始化 Git                                                   │
│     └── git init                                                │
│                                                                 │
│  6. 取得目前分支                                                  │
│     └── git branch --show-current                               │
│                                                                 │
│  7. Git Add                                                     │
│     └── git add --all                                           │
│                                                                 │
│  8. Git Commit                                                  │
│     └── git commit --message "..."                              │
│                                                                 │
│  9. Git Push                                                    │
│     └── git push --force git@github.com:{account}/{repo}.git    │
│                                                                 │
│  10. 移除暫存目錄                                                 │
│      └── fs.remove() 清理暫存檔案                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 詳細步驟說明

#### 步驟 1: 建立暫存目錄

```typescript
const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'lalilo-github-'))
const tmpDirPath = path.normalize(tmpDir + path.sep)
```

- 使用系統暫存目錄，避免污染專案目錄
- 目錄名稱格式：`lalilo-github-XXXXXX`

#### 步驟 2: 清空暫存目錄

```typescript
await fs.emptyDir(tmpDirPath)
```

- 確保暫存目錄為空，避免殘留檔案影響部署

#### 步驟 3: 掃描本地檔案

```typescript
const files = await filterLocalFiles(distDir, { ignoreNames, ignoreExts, ignoreDirs })
```

- 掃描 `dist/` 目錄下所有檔案
- 過濾掉指定的忽略檔案、副檔名、目錄
- 預設忽略：`.DS_Store`, `Thumbs.db`, `.gitignore`, `.git/`

#### 步驟 4: 複製檔案至暫存目錄

```typescript
const destPath = path.join(tmpDirPath, pathPrefix, file.relativePath)
await fs.ensureDir(path.dirname(destPath))
await fs.copyFile(file.fullPath, destPath)
```

- 使用 `pLimit(20)` 控制並行數量
- 保留完整目錄結構
- 若有 `prefix`，檔案會放在對應子目錄

#### 步驟 5-9: Git 操作

```bash
git init
git branch --show-current
git add --all
git commit --message "🚀 部署！"
git push --force git@github.com:{account}/{repo}.git {localBranch}:{branch}
```

- 使用 `--force` 強制推送，覆蓋遠端分支
- 若無檔案，使用 `--allow-empty` 建立空提交

#### 步驟 10: 清理

```typescript
await fs.remove(tmpDirPath)
```

- 使用 `finally` 區塊確保即使發生錯誤也會清理

### baseUrl 自動生成

當未指定 `--url` 時，GitHub 部署會自動生成 baseUrl：

```typescript
baseUrl = `https://${account}.github.io/${repository}/${urlPrefix}`
```

---

## AWS S3 部署流程

### 流程圖

```
┌─────────────────────────────────────────────────────────────────┐
│                      AWS S3 部署流程                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 初始化 S3 Client                                             │
│     └── 設定 credentials, region, NodeHttpHandler               │
│                                                                 │
│  2. 檢查 Bucket 權限                                             │
│     └── ListBucketsCommand 確認有權限存取                         │
│                                                                 │
│  3. 掃描本地檔案並計算 Hash                                        │
│     └── pLimit(20) 並行計算 MD5                                  │
│                                                                 │
│  4. 取得 S3 上的檔案                                              │
│     └── ListObjectsV2Command (處理分頁)                          │
│                                                                 │
│  5. 過濾需上傳的檔案                                              │
│     └── 本地有但 S3 沒有，或 Hash 不同                             │
│                                                                 │
│  6. 過濾需刪除的檔案                                              │
│     └── S3 有但本地沒有（排除忽略目錄）                            │
│                                                                 │
│  7. 上傳檔案至 S3                                                 │
│     └── pLimit(100) 並行上傳                                     │
│                                                                 │
│  8. 刪除 S3 上的檔案                                              │
│     └── pLimit(100) 並行刪除                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 詳細步驟說明

#### 步驟 1: 初始化 S3 Client

```typescript
const client = new S3Client({
  region,
  credentials: {
    accessKeyId: access,
    secretAccessKey: secret,
  },
  requestHandler: new NodeHttpHandler({
    connectionTimeout: 3000,
    socketTimeout: 0,
    httpAgent: new http.Agent({ maxSockets: 200, keepAlive: true }),
    httpsAgent: new https.Agent({ maxSockets: 200, keepAlive: true }),
  }),
})
```

**效能優化重點：**
- `maxSockets: 200`: 允許同時建立 200 個 TCP 連線
- `keepAlive: true`: 保持連線，減少 TCP 握手時間
- `socketTimeout: 0`: 不限制 socket 超時

#### 步驟 2: 檢查 Bucket 權限

```typescript
const [bucketsResult, bucketsError] = await tryAsync(
  () => client.send(new ListBucketsCommand({}))
)
```

- 取得帳號下所有 Bucket 列表
- 確認指定的 Bucket 存在且有權限

#### 步驟 3: 掃描本地檔案並計算 Hash

```typescript
const localFiles: LocalFile[] = await Promise.all(
  localFileInfos.map(file => limit!(async () => {
    const hash = await computeFileHash(file.fullPath)
    const key = `${urlPrefix}${file.relativePath.split(path.sep).join('/')}`
    const contentType = mime.lookup(file.fullPath) || 'application/octet-stream'
    return { src: file.fullPath, key, hash, contentType }
  }))
)
```

- 使用 MD5 計算檔案 hash
- hash 格式：`"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"` (含引號，與 S3 ETag 格式一致)
- S3 Key 使用 `/` 作為路徑分隔符

#### 步驟 4: 取得 S3 上的檔案

```typescript
async function listS3Files(client, ListObjectsV2Command, bucket, prefix): Promise<S3File[]>
```

- 使用 `ListObjectsV2Command` 取得檔案列表
- 處理分頁 (ContinuationToken)
- 取得每個檔案的 Key 和 ETag (hash)

#### 步驟 5: 過濾需上傳的檔案

```typescript
const filesToUpload = localFiles.filter(localFile => {
  const s3File = s3Files.find(s3 => s3.key === localFile.key)
  return !s3File || s3File.hash !== localFile.hash
})
```

**上傳條件：**
- 本地有但 S3 沒有（新檔案）
- Hash 不同（檔案已修改）

#### 步驟 6: 過濾需刪除的檔案

```typescript
const filesToDelete = s3Files.filter(s3File => {
  // 檢查是否在忽略目錄中
  const isInIgnoreDir = ignoreDirs.some(dir => {
    const normalizedDir = dir.split('/').filter(v => v !== '').join('/') + '/'
    return s3File.key.startsWith(urlPrefix + normalizedDir)
  })

  if (isInIgnoreDir) return false
  return !localFiles.find(local => local.key === s3File.key)
})
```

**刪除條件：**
- S3 有但本地沒有
- 不在忽略目錄中

#### 步驟 7: 上傳檔案

```typescript
await client.send(new PutObjectCommand({
  ...putOptions,
  Bucket: bucket,
  Key: file.key,
  Body: body,
  ContentType: file.contentType,
}))
```

- 使用 `pLimit(100)` 控制並行上傳數量
- 支援自訂 `putOptions`（如 CacheControl, ACL 等）

#### 步驟 8: 刪除檔案

```typescript
await client.send(new DeleteObjectCommand({
  Bucket: bucket,
  Key: file.key,
}))
```

- 使用 `pLimit(100)` 控制並行刪除數量

---

## 核心函數說明

### `normalizeUrlPrefix(prefix: string): string`

標準化 prefix 為 URL 路徑格式（使用 `/`）。

```typescript
normalizeUrlPrefix('v2')      // => 'v2/'
normalizeUrlPrefix('a/b')     // => 'a/b/'
normalizeUrlPrefix('a\\b')    // => 'a/b/'
normalizeUrlPrefix('')        // => ''
```

### `normalizePathPrefix(prefix: string): string`

標準化 prefix 為檔案路徑格式（使用 `path.sep`）。

```typescript
// macOS/Linux
normalizePathPrefix('v2')     // => 'v2'
normalizePathPrefix('a/b')    // => 'a/b'

// Windows
normalizePathPrefix('a/b')    // => 'a\\b'
```

### `filterLocalFiles(distDir, options): Promise<FileInfo[]>`

掃描並過濾本地檔案。

**參數：**
- `distDir`: 來源目錄
- `options.ignoreNames`: 忽略的檔案名稱
- `options.ignoreExts`: 忽略的副檔名
- `options.ignoreDirs`: 忽略的目錄

**預設忽略：**
- 檔案：`.DS_Store`, `Thumbs.db`, `.gitignore`
- 目錄：`.git`

### `computeFileHash(filePath: string): Promise<string>`

計算檔案的 MD5 hash。

```typescript
const hash = await computeFileHash('/path/to/file.js')
// => '"d41d8cd98f00b204e9800998ecf8427e"'
```

- 使用 stream 處理，支援大檔案
- 回傳格式含引號，與 S3 ETag 格式一致

### `listS3Files(client, ListObjectsV2Command, bucket, prefix): Promise<S3File[]>`

取得 S3 上的所有檔案列表。

- 自動處理分頁（ListObjectsV2 每次最多回傳 1000 個）
- 回傳 Key 和 ETag (hash)

---

## 資料結構

### LocalFile

```typescript
interface LocalFile {
  src: string          // 本地檔案完整路徑
  key: string          // S3 Key（含 prefix）
  hash: string         // MD5 hash
  contentType: string  // MIME type
}
```

### S3File

```typescript
interface S3File {
  key: string   // S3 Key
  hash: string  // ETag (MD5 hash)
}
```

---

## 錯誤處理

### DeployError

專用的部署錯誤類別，位於 `src/utils/errors.ts`。

**常見錯誤情境：**

| 情境 | 錯誤訊息 |
|------|----------|
| 未指定 goal | `必須指定 --goal 選項（github 或 s3）` |
| 無效的 goal | `無效的部署目標: xxx，請使用 github 或 s3` |
| dist 目錄不存在 | `輸出目錄不存在: dist，請先執行 build 指令` |
| 缺少 GitHub 帳號 | `GitHub 部署必須指定帳號` |
| 缺少 S3 參數 | `請提供 S3 Bucket、Access Key、Secret Key 和 region` |
| 無 Bucket 權限 | `沒有 xxx 此 Bucket 權限！` |

### tryAsync

安全的 async 函數包裝器，回傳 `[result, error]` 格式。

```typescript
const [result, error] = await tryAsync(() => someAsyncOperation())
if (error) {
  throw new DeployError('操作失敗', error)
}
```

---

## 效能優化

### 並行處理 (pLimit)

| 操作 | 並行數量 | 說明 |
|------|----------|------|
| 檔案複製 (GitHub) | 20 | I/O bound |
| Hash 計算 (S3) | 20 | CPU bound |
| 檔案上傳 (S3) | 100 | Network bound |
| 檔案刪除 (S3) | 100 | Network bound |

### TCP 連線優化

```typescript
new NodeHttpHandler({
  connectionTimeout: 3000,
  socketTimeout: 0,
  httpAgent: new http.Agent({ maxSockets: 200, keepAlive: true }),
  httpsAgent: new https.Agent({ maxSockets: 200, keepAlive: true }),
})
```

- `maxSockets: 200`: 允許 200 個並行 TCP 連線
- `keepAlive: true`: 重用 TCP 連線，減少握手時間
- `socketTimeout: 0`: 不限制 socket 超時，避免大檔案上傳逾時

### 增量更新

S3 部署使用 MD5 hash 比對，只上傳有變動的檔案：

1. 計算本地檔案 hash
2. 取得 S3 檔案 ETag (即 MD5)
3. 比對後只上傳不同的檔案
4. 刪除 S3 上多餘的檔案

這大幅減少了重複上傳的時間和流量。

---

## 檔案結構

```
cmd/
├── config.yaml                   # 框架預設配置（含部署預設值）
├── src/
│   ├── cli/
│   │   ├── index.ts              # CLI 入口
│   │   └── commands/
│   │       └── deploy.ts         # 部署指令（本文件主要說明）
│   ├── core/
│   │   └── config/
│   │       └── index.ts          # 配置載入
│   ├── types/
│   │   └── index.ts              # 型別定義
│   └── utils/
│       ├── errors.ts             # 錯誤處理
│       ├── fs.ts                 # 檔案系統工具
│       └── logger.ts             # 日誌工具
└── deploy.md                     # 本文件
```

---

## 相依套件

| 套件 | 用途 |
|------|------|
| `@aws-sdk/client-s3` | S3 操作 |
| `@smithy/node-http-handler` | HTTP 連線優化 |
| `p-limit` | 並行控制 |
| `fs-extra` | 檔案系統擴充 |
| `mime-types` | MIME type 判斷 |
| `commander` | CLI 參數解析 |

---

## 安全注意事項

1. **Force Push**：GitHub 部署使用 `--force`，會覆蓋遠端分支歷史

2. **S3 權限**：確保 IAM 使用者有以下權限：
   - `s3:ListBucket`
   - `s3:GetObject`
   - `s3:PutObject`
   - `s3:DeleteObject`

3. **敏感資訊**：命令列參數可能包含 AWS 金鑰等敏感資料，建議使用配置檔或環境變數

---

## 相關文件

- [Flow 流程系統文件](./flow.md) - 串聯 build + deploy 的自動化流程

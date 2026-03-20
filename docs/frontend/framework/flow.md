# Flow 流程系統文件

> 本文件詳細說明 Lalilo 的 Flow 流程系統，用於串聯 `build` 和 `deploy` 命令執行。

---

## 目錄

1. [概述](#概述)
2. [命令列介面](#命令列介面)
3. [配置檔格式](#配置檔格式)
4. [環境變數支援](#環境變數支援)
5. [執行流程](#執行流程)
6. [核心函數說明](#核心函數說明)
7. [資料結構](#資料結構)
8. [完整範例](#完整範例)
9. [安全注意事項](#安全注意事項)

---

## 概述

Flow 系統允許透過 YAML/JSON 配置檔定義部署流程，將 `build` 和 `deploy` 命令串聯執行，適用於：

- 多環境部署（prod、beta、staging）
- CI/CD 自動化流程
- 標準化部署配置

---

## 命令列介面

### 基本指令

```bash
npm run flow -- --name <flow名稱> [選項]
```

### 選項參數

| 選項 | 說明 | 預設值 |
|------|------|--------|
| `--name <name>` | 流程名稱 | **必填** |
| `--config <path>` | 配置檔路徑 | `flow.yaml` |
| `--dry-run` | 僅顯示命令，不實際執行 | `false` |

### 使用範例

```bash
# 執行 prod 流程
npm run flow -- --name prod

# 執行 beta 流程，使用自訂配置檔
npm run flow -- --name beta --config my-flow.yaml

# Dry run 模式（僅顯示命令）
npm run flow -- --name prod --dry-run
```

---

## 配置檔格式

### 基本結構

```yaml
flows:
  <flow-name>:
    build:
      # build 相關配置
    deploy:
      # deploy 相關配置
```

### Build 配置選項

| 選項 | 型別 | 說明 |
|------|------|------|
| `env` | string | 環境 (`dev`/`beta`/`prod`) |
| `minify` | boolean | 是否壓縮 |
| `merge` | boolean | 是否合併 CSS/JS |
| `hash` | boolean | 是否加上 hash |
| `url` | string | 基礎 URL |
| `out` | string | 輸出目錄 |

### Deploy 配置選項

#### 通用選項

| 選項 | 型別 | 說明 |
|------|------|------|
| `goal` | string | 部署目標 (`github` 或 `s3`) |
| `prefix` | string | 前綴路徑 |
| `url` | string | 基礎 URL |

#### GitHub 專用選項

| 選項 | 型別 | 說明 |
|------|------|------|
| `gh-account` | string | GitHub 帳號 |
| `gh-repository` | string | GitHub 儲存庫 |
| `gh-branch` | string | 部署分支 |
| `gh-message` | string | Commit 訊息 |

#### S3 專用選項

| 選項 | 型別 | 說明 |
|------|------|------|
| `s3-bucket` | string | S3 Bucket 名稱 |
| `s3-access` | string | AWS Access Key ID |
| `s3-secret` | string | AWS Secret Access Key |
| `s3-region` | string | AWS Region |

---

## 環境變數支援

配置檔支援 `${VAR_NAME}` 語法引用環境變數：

```yaml
flows:
  prod:
    deploy:
      goal: s3
      s3-bucket: my-bucket
      s3-access: ${AWS_ACCESS_KEY_ID}
      s3-secret: ${AWS_SECRET_ACCESS_KEY}
      s3-region: ${AWS_REGION}
```

### 環境變數處理流程

```typescript
// 替換 ${VAR_NAME} 為實際環境變數值
function replaceEnvVars(value: string): string {
  return value.replace(/\$\{([^}]+)\}/g, (_, varName) => {
    return process.env[varName] || ''
  })
}
```

**注意：** 若環境變數不存在，會被替換為空字串。

---

## 執行流程

### 流程圖

```
┌─────────────────────────────────────────────────────────────────┐
│                       Flow 執行流程                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 搜尋配置檔                                                   │
│     └── 依序搜尋多個可能路徑                                      │
│                                                                 │
│  2. 載入配置檔                                                   │
│     └── 支援 YAML (.yaml/.yml) 和 JSON (.json)                  │
│                                                                 │
│  3. 解析指定流程                                                 │
│     └── 從 flows 物件中取得對應配置                               │
│                                                                 │
│  4. 處理環境變數                                                 │
│     └── 遞迴替換 ${VAR_NAME} 為實際值                            │
│                                                                 │
│  5. 執行 Build（若有配置）                                        │
│     └── spawn('npm', ['run', 'build', '--', ...args])           │
│     └── 等待完成後繼續                                           │
│                                                                 │
│  6. 執行 Deploy（若有配置）                                       │
│     └── spawn('npm', ['run', 'deploy', '--', ...args])          │
│     └── 若 deploy 無 url，自動繼承 build 的 url                   │
│                                                                 │
│  7. 完成                                                        │
│     └── 顯示總耗時                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 配置檔搜尋順序

Flow 會依序搜尋以下路徑，使用找到的第一個：

1. `{cwd}/{config}` - 命令列指定的配置檔
2. `{rootDir}/{config}` - 上層目錄的指定配置檔
3. `{cwd}/flow.yml` - 當前目錄的 yml 檔
4. `{cwd}/flow.json` - 當前目錄的 json 檔

### URL 繼承機制

若 `deploy` 配置中沒有指定 `url`，但 `build` 有指定，則自動繼承：

```typescript
if (!processedConfig.deploy.url && processedConfig.build?.url) {
  processedConfig.deploy.url = processedConfig.build.url
}
```

---

## 核心函數說明

### `replaceEnvVars(value: string): string`

替換字串中的環境變數。

```typescript
replaceEnvVars('${AWS_ACCESS_KEY_ID}')  // => 'AKIAXXXXXXXX'
replaceEnvVars('prefix-${VAR}-suffix')  // => 'prefix-value-suffix'
replaceEnvVars('${UNDEFINED_VAR}')      // => ''
```

### `processEnvVars(obj: Record<string, any>): Record<string, any>`

遞迴處理物件中所有字串的環境變數。

```typescript
processEnvVars({
  bucket: '${S3_BUCKET}',
  nested: {
    key: '${AWS_KEY}'
  }
})
// => { bucket: 'my-bucket', nested: { key: 'xxx' } }
```

### `configToArgs(config: Record<string, any>): string[]`

將配置物件轉換為命令列參數。

```typescript
configToArgs({
  env: 'prod',
  minify: true,
  merge: false,
  url: 'https://example.com/'
})
// => ['--env', 'prod', '--minify', '--url', 'https://example.com/']
```

**轉換規則：**
- `undefined`、`null`、`''` → 忽略
- `boolean: true` → `--key`
- `boolean: false` → 忽略
- 其他值 → `--key value`

---

## 資料結構

### FlowBuildConfig

```typescript
interface FlowBuildConfig {
  env?: string      // 環境
  minify?: boolean  // 是否壓縮
  merge?: boolean   // 是否合併
  hash?: boolean    // 是否加 hash
  url?: string      // 基礎 URL
  out?: string      // 輸出目錄
}
```

### FlowDeployConfig

```typescript
interface FlowDeployConfig {
  goal?: string           // 部署目標
  prefix?: string         // 前綴路徑
  url?: string            // 基礎 URL

  // GitHub
  'gh-account'?: string
  'gh-repository'?: string
  'gh-branch'?: string
  'gh-message'?: string

  // S3
  's3-bucket'?: string
  's3-access'?: string
  's3-secret'?: string
  's3-region'?: string
}
```

### FlowConfig

```typescript
interface FlowConfig {
  build?: FlowBuildConfig
  deploy?: FlowDeployConfig
}
```

### FlowsFile

```typescript
interface FlowsFile {
  flows: Record<string, FlowConfig>
}
```

---

## 完整範例

### flow.yaml

```yaml
# Lalilo Flow 配置檔

flows:
  # ============================================
  # 正式環境 - 部署到 AWS S3
  # ============================================
  prod:
    build:
      env: prod
      minify: true
      merge: false
      hash: true
      url: https://example.com/

    deploy:
      goal: s3
      prefix: ""
      s3-bucket: my-production-bucket
      s3-access: ${AWS_ACCESS_KEY_ID}
      s3-secret: ${AWS_SECRET_ACCESS_KEY}
      s3-region: ap-northeast-1

  # ============================================
  # 測試環境 - 部署到 GitHub Pages
  # ============================================
  beta:
    build:
      env: beta
      minify: true
      merge: false
      hash: true
      url: https://myaccount.github.io/myrepo/

    deploy:
      goal: github
      gh-account: myaccount
      gh-repository: myrepo
      gh-branch: gh-pages
      gh-message: "🚀 部署測試環境"

  # ============================================
  # Staging 環境 - 部署到 S3 子目錄
  # ============================================
  staging:
    build:
      env: beta
      minify: true
      hash: true
      url: https://staging.example.com/v2/

    deploy:
      goal: s3
      prefix: v2
      s3-bucket: my-staging-bucket
      s3-access: ${AWS_ACCESS_KEY_ID}
      s3-secret: ${AWS_SECRET_ACCESS_KEY}
      s3-region: ap-northeast-1

  # ============================================
  # 僅 Build（不部署）
  # ============================================
  build-only:
    build:
      env: prod
      minify: true
      merge: false
      hash: true
      url: https://example.com/

  # ============================================
  # 僅 Deploy（使用已存在的 dist）
  # ============================================
  deploy-only:
    deploy:
      goal: github
      gh-account: myaccount
      gh-repository: myrepo
      url: https://myaccount.github.io/myrepo/
```

### 多環境配置建議

若需要多個獨立的配置檔，可使用 `--config` 指定：

```bash
# 使用不同配置檔
npm run flow -- --name prod --config flow.prod.yaml
npm run flow -- --name beta --config flow.beta.yaml
```

---

## 安全注意事項

### 1. 敏感資訊處理

配置檔可能包含 AWS 金鑰等敏感資料，建議：

```bash
# 加入 .gitignore
echo "flow.yaml" >> .gitignore
echo "flow.*.yaml" >> .gitignore
```

### 2. 使用環境變數

**推薦做法**：將敏感資訊放在環境變數中

```yaml
# flow.yaml
flows:
  prod:
    deploy:
      s3-access: ${AWS_ACCESS_KEY_ID}
      s3-secret: ${AWS_SECRET_ACCESS_KEY}
```

```bash
# 執行時設定環境變數
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
npm run flow -- --name prod
```

### 3. CI/CD 整合

在 GitHub Actions 中使用：

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm install
      - run: npm run flow -- --name prod
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

## 檔案結構

```
cmd/
├── src/
│   └── cli/
│       └── commands/
│           └── flow.ts           # Flow 指令實作
├── flow.yaml                     # Flow 配置檔（使用者建立）
└── flow.example.yaml             # Flow 配置範例（可選）
```

---

## 相依套件

| 套件 | 用途 |
|------|------|
| `js-yaml` | YAML 解析 |
| `fs-extra` | 檔案系統操作 |
| `commander` | CLI 參數解析 |

---

## 相關文件

- [Deploy 部署系統文件](./deploy.md) - 部署指令詳細說明

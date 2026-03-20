# Lalilo Build 流程架構文件

本文件詳細說明 Lalilo 專案的 Build 編譯流程，包含架構設計、資料流、模組職責與設計模式。

---

## 目錄

1. [概述](#概述)
2. [執行指令](#執行指令)
3. [整體流程圖](#整體流程圖)
4. [階段詳解](#階段詳解)
5. [核心模組](#核心模組)
6. [資料流與設計模式](#資料流與設計模式)
7. [輸出結構](#輸出結構)
8. [類型定義](#類型定義)

---

## 概述

Build 流程負責將 `src/` 目錄下的原始碼編譯成可部署的靜態檔案，輸出至 `dist/` 目錄。

### 主要功能

- **Icon 編譯**：將 IcoMoon 的 `style.css` 轉換為 CSS，輸出至 `cmd/node_modules/_/icon/`
- **SCSS 編譯**：將 SCSS 編譯為 CSS（可選壓縮），輸出至 `cmd/node_modules/_/css/`
- **JavaScript 編譯**：使用 esbuild 編譯 JS，輸出以 MD5 hash 命名
- **HTML 編譯**：使用 Handlebars 模板引擎，結合 Model 資料渲染
- **資源複製**：複製圖片、字型、CSS、Icon CSS 等靜態資源

### 入口檔案

```
cmd/src/cli/commands/build.ts
```

---

## 執行指令

```bash
cd cmd
npx ts-node src/cli/index.ts build [options]
```

### 參數選項

| 參數 | 說明 | 預設值 |
|------|------|--------|
| `--env <env>` | 環境（dev/beta/prod） | `prod` |
| `--minify` | 壓縮 CSS/JS/HTML | `true` |
| `--merge` | 合併 CSS/JS 至 HTML | `false` |
| `--hash` | 使用 MD5 hash 檔名 | `true` |
| `--url <url>` | 基礎 URL | `''` |
| `--out <dir>` | 輸出目錄 | `dist` |

#### `--hash` 參數說明

控制 CSS 和 JS 檔案是否使用 MD5 hash 命名：

```bash
# 啟用 hash 模式（預設）
node build.js --hash

# 停用 hash 模式，保持原始檔名
node build.js --no-hash
```

| 模式 | CSS 輸出 | JS 輸出 |
|------|----------|---------|
| `--hash` | `css/a1b2c3d4...css` | `js/f6e5d4c3...js` |
| `--no-hash` | `css/index.css` | `js/index.js` |

使用 hash 命名的優點：
- 檔案內容變更時，hash 也會變更，確保瀏覽器載入最新版本
- 適合搭配 CDN 快取策略，可設定長時間快取

---

## 整體流程圖

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Build 流程                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐                                                   │
│  │ 1. 載入配置   │ resolveConfig()                                   │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │ 2. 清空輸出   │ emptyDir(outDir)                                  │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │ 3. 編譯 Icon  │ compileIcon() → 輸出 SCSS                         │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │ 4. 編譯 SCSS  │ compileScss() → 輸出 CSS                          │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │ 5. 掃描檔案   │ scanFiles() → 分類檔案                            │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │ 6. 複製 CSS   │ copyFile()                                        │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐    ┌─────────────────┐                            │
│  │ 7. 編譯 JS    │───▶│ jsMap 映射表     │                            │
│  └──────┬───────┘    └────────┬────────┘                            │
│         ▼                     │                                      │
│  ┌──────────────┐             ▼                                      │
│  │ 8. 編譯 HTML  │◀── jsMap 傳入 Model/Asset                          │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │ 9. 複製其他   │ 圖片、字型等                                       │
│  └──────┬───────┘                                                   │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │ 10. 完成     │                                                    │
│  └──────────────┘                                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 階段詳解

### 階段 1：載入配置

**檔案**：`cmd/src/core/config/index.ts`

```typescript
const config = await resolveConfig(rootDir, {
  env: options.env,
  minify: options.minify,
  merge: options.merge,
  baseUrl: options.url,
})
```

**流程**：

1. 載入預設配置 `getDefaultConfig()`
   - 優先從 `cmd/config.yaml` 讀取
   - 若無則使用硬編碼預設值
2. 嘗試載入使用者配置 `lalilo.config.js`
3. 合併配置 `mergeConfig()`
4. 解析並驗證路徑
5. 返回完整配置 `FullConfig`

**配置結構**：

```typescript
interface FullConfig {
  source: {
    path: string           // src/
    dirs: {
      js: string           // src/js/
      scss: string         // src/scss/
      html: string         // src/html/
      model: string        // src/model/
      icon: string         // src/icon/
      img: string          // src/img/
    }
  }
  runtime: {
    env: 'dev' | 'beta' | 'prod'
    baseUrl: string
    isMinify: boolean
    isMerge: boolean
    rootDir: string
    cmdDir: string
    cssDir: string         // cmd/node_modules/_/css（固定路徑）
  }
  build: {
    outDir: string
    target: string[]
    allowedExts: string[]
  }
}
```

---

### 階段 2：清空輸出目錄

```typescript
await emptyDir(outDir)
await writeFile(path.join(outDir, '.gitignore'), '*\n')
```

- 清空 `dist/` 目錄
- 建立 `.gitignore` 防止輸出被提交

---

### 階段 3：編譯 Icon

**檔案**：`cmd/src/core/compiler/icon.ts`

**輸入**：`src/icon/{name}/style.css`（IcoMoon 匯出）

**輸出**：`cmd/node_modules/_/icon/{name}.css`

**命名規則**：

| 來源目錄 | 輸出檔案 | font-family |
|----------|----------|-------------|
| `src/icon/icomoon/` | `icon.css` | `'icon'` |
| `src/icon/aaa/` | `aaa.css` | `'icon-aaa'` |

**流程**：

```
src/icon/icomoon/style.css
         │
         ▼
    compileIcon()
         │
         ├── 解析 @font-face
         ├── 解析 icon 定義（.icon-xxx:before）
         └── 產生 CSS
         │
         ▼
cmd/node_modules/_/icon/icon.css
```

**處理邏輯**：

1. 讀取 IcoMoon 的 `style.css`
2. 解析目錄名稱決定 font-family（icomoon → `'icon'`，其他 → `'icon-{name}'`）
3. 提取所有 `.icon-xxx:before` 定義
4. 產生包含 `@font-face` 和 icon class 的 CSS
5. 寫入 `cmd/node_modules/_/icon/` 目錄

---

### 階段 4：編譯 SCSS

**檔案**：`cmd/src/core/compiler/scss.ts`

**輸入**：`src/scss/*.scss`（排除 `_` 開頭的 partial）

**輸出**：`cmd/node_modules/_/css/*.css`

**流程**：

```
src/scss/index.scss
         │
         ▼
    compileScss()
         │
         ├── @oawu/scss 編譯
         ├── lightningcss 壓縮（若 minify）
         └── 寫入檔案
         │
         ▼
cmd/node_modules/_/css/index.css
```

**使用工具**：

- `@oawu/scss`：SCSS 編譯（支援 `@/` 路徑別名）
- `lightningcss`：CSS 壓縮

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

---

### 階段 5：掃描與分類檔案

```typescript
const allFiles = await scanFiles(config.source.path, {
  recursive: true,
  ignoreDirs: ['model'],
})

// 分類
const cssFiles = allFiles.filter(f => f.ext === '.css')
const jsFiles = allFiles.filter(f => f.ext === '.js')
const htmlFiles = allFiles.filter(f => f.ext === '.html' && isInDir(htmlDir, f.fullPath))
const otherFiles = allFiles.filter(f => /* 其他允許的副檔名 */)
```

---

### 階段 6：複製 CSS

```typescript
await copyFile(file.fullPath, destPath)
```

CSS 檔案直接複製到輸出目錄，保持原始目錄結構。

---

### 階段 7：編譯 JavaScript（關鍵階段）

**檔案**：`cmd/src/core/compiler/javascript.ts`

**函數**：`compileJsWithHash()`

**輸入**：`src/js/**/*.js`

**輸出**：`dist/js/{md5-hash}.js`

**流程**：

```
src/js/index.js
src/js/page.js
src/js/_01-Core/01-Helper.js
         │
         ▼
  compileJsWithHash()
         │
         ├── 讀取原始碼
         ├── 處理 __tmpl__ 注入（若有）
         ├── esbuild.transform() 編譯/壓縮
         ├── 加入版權宣告
         ├── 計算 MD5 hash
         └── 寫入 {hash}.js
         │
         ▼
dist/js/a1b2c3d4e5f6...js
dist/js/f6e5d4c3b2a1...js
dist/js/1234567890ab...js
```

**`__tmpl__` 處理**：

若 JS 檔案包含 `__tmpl__: 'name'`，會自動查找 `src/tmpl/{name}.html` 或 `src/tmpl/{name}.el3`，將內容壓縮後替換為 `template: \`...\``。

| 優先級 | 檔案格式 | 說明 |
|--------|----------|------|
| 1 | `.html` | 直接壓縮 HTML |
| 2 | `.el3` | 編譯 El3 為 HTML 後壓縮 |

**jsMap 映射表**：

```typescript
const jsMap = new Map<string, string>()

// 編譯後記錄映射
jsMap.set('js/index.js', 'a1b2c3d4e5f6...js')
jsMap.set('js/page.js', 'f6e5d4c3b2a1...js')
jsMap.set('js/_01-Core/01-Helper.js', '1234567890ab...js')
```

**esbuild 配置**：

```typescript
esbuild.transform(source, {
  loader: 'js',
  charset: 'utf8',
  minify: config.runtime.isMinify,
  minifyWhitespace: true,
  minifyIdentifiers: true,
  minifySyntax: true,
  legalComments: 'none',
  target: ['es2020', 'chrome90', 'firefox88', 'safari14'],
})
```

---

### 階段 8：編譯 HTML（關鍵階段）

**檔案**：

- `cmd/src/core/compiler/html.ts`
- `cmd/src/core/model/index.ts`
- `cmd/src/core/asset/index.ts`

**輸入**：

- `src/html/*.html`（Handlebars 模板）
- `src/model/*.js`（Model 資料）
- `jsMap`（JS 映射表）

**輸出**：`dist/*.html`

**流程**：

```
src/html/index.html          src/model/index.js
         │                           │
         │                           ▼
         │                  loadAndExecuteModel()
         │                           │
         │                           ├── 建立 ModelContext
         │                           │      ├── config
         │                           │      ├── Asset: () => createAsset(config, jsMap)
         │                           │      ├── jsEnv
         │                           │      └── require
         │                           │
         │                           ▼
         │                  執行 Model 函數
         │                           │
         │                           ▼
         │                  resolveModelData()
         │                           │
         │                           ├── 遞迴處理 Promise
         │                           ├── 遞迴處理函數
         │                           └── Asset.toString()
         │                                    │
         │                                    ├── 產生 CSS 標籤
         │                                    └── 產生 JS 標籤
         │                                         │
         │                                         └── 比對 jsMap
         │                                              若匹配則替換為 hash 路徑
         │                           │
         ▼                           ▼
    compileHtml(inputFile, outputFile, { modelData })
         │
         ├── Handlebars.compile() 渲染模板
         ├── html-minifier-terser 壓縮（若 minify）
         └── 加入版權宣告
         │
         ▼
dist/index.html
```

**Model 檔案範例**：

```javascript
// src/model/index.js
module.exports = ({ Asset, config, jsEnv }) => ({
  title: '首頁',
  jsEnv,
  asset: Asset()
    .scss('index')
    .js('_01-Core/**')
    .js('index.js'),
})
```

**Asset 類別**：

```typescript
class Asset {
  private jsMap?: Map<string, string>
  private cssMap?: Map<string, string>
  private iconMap?: Map<string, string>

  constructor(config: FullConfig, jsMap?: Map<string, string>, cssMap?: Map<string, string>, iconMap?: Map<string, string>) {
    this.config = config
    this.jsMap = jsMap
    this.cssMap = cssMap
    this.iconMap = iconMap
  }

  icon(name: string): this { /* 添加 Icon CSS */ }
  scss(src: string): this { /* 添加 SCSS（支援多種格式） */ }
  js(src: string): this { /* 添加 JS */ }

  async toString(): Promise<string> {
    // 產生 icon、css、js 標籤
    // 若有對應的 Map，則替換為 hash 檔名
  }
}
```

**Asset 方法說明**：

| 方法 | 說明 | 範例 |
|------|------|------|
| `.icon(name)` | 載入 Icon CSS | `.icon('icon')` |
| `.scss(path)` | 載入 SCSS（支援 `'index'`、`'index.scss'`、`'index.css'`） | `.scss('_01-Core/01-Elements')` |
| `.js(path)` | 載入 JavaScript | `.js('index.js')` |

---

### 階段 9：複製其他檔案

```typescript
const otherFiles = allFiles.filter(f =>
  !['.css', '.js', '.html', '.scss'].includes(f.ext) &&
  !isInDir(modelDir, f.fullPath) &&
  config.build.allowedExts.includes(f.ext)
)

await copyFile(file.fullPath, destPath)
```

允許的副檔名：
- 圖片：`.png`, `.jpg`, `.jpeg`, `.gif`, `.ico`, `.svg`
- 字型：`.eot`, `.ttf`, `.woff`
- 其他：`.txt`, `.xml`, `.json`

---

## 核心模組

### 模組依賴圖

```
build.ts
    │
    ├── config/index.ts
    │       └── resolveConfig()
    │
    ├── compiler/
    │       ├── icon.ts
    │       │       └── compileIcon()
    │       ├── scss.ts
    │       │       └── compileScss()
    │       ├── javascript.ts
    │       │       └── compileJsWithHash()
    │       ├── html.ts
    │       │       └── compileHtml()
    │       ├── tmpl.ts
    │       │       └── processTmpl()
    │       └── el3.ts
    │               └── compileEl3()
    │
    ├── model/index.ts
    │       └── loadAndExecuteModel()
    │
    ├── asset/index.ts
    │       ├── Asset class
    │       └── createAsset()
    │
    └── utils/
            ├── fs.ts
            ├── logger.ts
            └── errors.ts
```

### 各模組職責

| 模組 | 檔案 | 職責 |
|------|------|------|
| Config | `config/index.ts` | 配置載入、合併、驗證 |
| Icon Compiler | `compiler/icon.ts` | IcoMoon CSS → SCSS |
| SCSS Compiler | `compiler/scss.ts` | SCSS → CSS |
| JS Compiler | `compiler/javascript.ts` | JS 編譯、壓縮、hash 命名 |
| HTML Compiler | `compiler/html.ts` | Handlebars 渲染、壓縮 |
| Tmpl Processor | `compiler/tmpl.ts` | JS 中 `__tmpl__` 注入處理 |
| El3 Compiler | `compiler/el3.ts` | El3 語法編譯為 HTML |
| Model Loader | `model/index.ts` | 載入並執行 Model 檔案 |
| Asset Builder | `asset/index.ts` | 產生 CSS/JS 標籤 |

---

## 資料流與設計模式

### jsMap 資料流

```
┌─────────────────────────────────────────────────────────────────────┐
│                         jsMap 資料流                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  build.ts                                                           │
│      │                                                              │
│      │  const jsMap = new Map<string, string>()                     │
│      │                                                              │
│      ▼                                                              │
│  compileJsWithHash()                                                │
│      │                                                              │
│      │  jsMap.set('js/index.js', 'a1b2c3d4.js')                     │
│      │                                                              │
│      ▼                                                              │
│  loadAndExecuteModel(modelPath, config, jsMap)                      │
│      │                                                              │
│      │  ctx.Asset = () => createAsset(config, jsMap)                │
│      │                                                              │
│      ▼                                                              │
│  new Asset(config, jsMap)                                           │
│      │                                                              │
│      │  this.jsMap = jsMap                                          │
│      │                                                              │
│      ▼                                                              │
│  Asset.toString()                                                   │
│      │                                                              │
│      │  const hashName = this.jsMap.get(name)                       │
│      │  finalSrc = 'js/' + hashName                                 │
│      │                                                              │
│      ▼                                                              │
│  <script src="js/a1b2c3d4.js"></script>                             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 使用的設計模式

#### 1. 依賴注入 (Dependency Injection)

```typescript
// jsMap 作為可選依賴注入
createAsset(config, jsMap)
new Asset(config, jsMap)
```

- Asset 不需要知道 jsMap 從哪來
- 便於測試（可傳入 mock）
- 解耦模組間的依賴

#### 2. 注冊表模式 (Registry Pattern)

```typescript
const jsMap = new Map<string, string>()

// 編譯時註冊
jsMap.set('js/index.js', 'a1b2c3d4.js')

// 使用時查詢
const hashName = this.jsMap.get(name)
```

- 集中管理路徑映射
- 類似 Webpack 的 manifest

#### 3. 工廠模式 (Factory Pattern)

```typescript
export function createAsset(config, jsMap?): Asset {
  return new Asset(config, jsMap)
}
```

- 封裝實例化邏輯
- 統一創建入口

#### 4. 兩階段處理 (Two-Phase Processing)

```
階段一：編譯 JS → 收集映射（jsMap）
階段二：編譯 HTML → 使用映射替換路徑
```

- 分離關注點
- 確保資料在使用前已準備好

---

## 輸出結構

### 編譯前（src/）

```
src/
├── html/
│   ├── index.html
│   └── page.html
├── js/
│   ├── index.js
│   ├── page.js
│   └── _01-Core/
│       ├── 01-Helper.js
│       ├── 02-Load.js
│       └── ...
├── scss/
│   ├── index.scss
│   └── page.scss
├── icon/
│   └── icomoon/
│       ├── style.css
│       └── fonts/
├── img/
│   └── logo.png
└── model/
    ├── index.js
    └── page.js
```

### 編譯後（dist/）

```
dist/
├── index.html
├── page.html
├── js/
│   ├── a1b2c3d4e5f6789...js (index.js)
│   ├── f6e5d4c3b2a1098...js (page.js)
│   ├── 1234567890abcde...js (01-Helper.js)
│   └── ...
├── css/
│   ├── index.css
│   └── page.css
├── icon/
│   └── icomoon/
│       └── fonts/
├── img/
│   └── logo.png
└── .gitignore
```

### HTML 輸出範例

**輸入**（src/html/index.html + src/model/index.js）：

```html
<!DOCTYPE html>
<html>
<head>
  <title>{{title}}</title>
  {{{asset}}}
</head>
<body>
  <script>{{{jsEnv}}}</script>
</body>
</html>
```

**輸出**（dist/index.html）：

```html
<!--
 * @author      OA Wu <oawu.tw@gmail.com>
 * @copyright   Copyright (c) 2015 - 2026, Lalilo
 * @license     http://opensource.org/licenses/MIT  MIT License
 * @link        https://www.ioa.tw/
-->
<!DOCTYPE html>
<html>
<head>
  <title>首頁</title>
  <link href="css/index.css" type="text/css" rel="stylesheet" />
  <script src="js/a1b2c3d4e5f6789...js"></script>
  <script src="js/f6e5d4c3b2a1098...js"></script>
</head>
<body>
  <script>window.Env={url:{base:""}};window.Env.toString=function(){return"prod"};</script>
</body>
</html>
```

---

## 類型定義

### CompileResult

```typescript
interface CompileResult {
  content: string      // 輸出內容
  sourceFile: string   // 來源檔案
  outputFile: string   // 輸出檔案
  duration: number     // 編譯耗時（毫秒）
  sourceMap?: string   // Source map（如果有）
}
```

### JsCompilerOptions

```typescript
interface JsCompilerOptions {
  minify: boolean      // 是否壓縮
  sourceMap: boolean   // 是否產生 source map
  target: string[]     // esbuild 目標（如 ['es2020']）
  bundle: boolean      // 是否打包
  tmplDir?: string     // 模板目錄路徑（用於 __tmpl__ 注入）
}
```

### HtmlCompilerOptions

```typescript
interface HtmlCompilerOptions {
  minify: boolean                    // 是否壓縮
  merge: boolean                     // 是否合併 CSS/JS
  modelData?: Record<string, unknown> // Model 資料
}
```

### ModelContext

```typescript
interface ModelContext {
  config: FullConfig
  Asset: () => Asset
  jsEnv: string
  require: (requirePath: string) => unknown
}
```

**`require` 函數路徑解析規則：**

| 寫法 | 解析結果 |
|------|----------|
| `require('./_base.js')` | 相對於當前 Model 檔案 |
| `require('../_base.js')` | 相對於當前檔案的上層 |
| `require('/_base.js')` | `src/model/_base.js`（相對於 model 根目錄） |

使用範例：

```javascript
// src/model/page/a.js
module.exports = ({ require }) => {
  const base = require('/_base.js')  // → src/model/_base.js
  return { /* ... */ }
}
```

---

## 並行處理

Build 流程使用 `p-limit` 控制並行數量：

```typescript
const limit = pLimit(10) // 最多同時 10 個任務

await Promise.all(
  files.map(file =>
    limit(async () => {
      await compileFile(file)
    })
  )
)
```

### 各階段並行策略

| 階段 | 並行方式 | 原因 |
|------|----------|------|
| Icon | 並行（10） | 獨立編譯 |
| SCSS | 並行（10） | 獨立編譯 |
| CSS | 並行（10） | 獨立複製 |
| JS | 並行（10） | 獨立編譯，收集 jsMap |
| HTML | **序列** | 依賴 jsMap 完成 |
| Other | 並行（10） | 獨立複製 |

---

## 錯誤處理

所有編譯器使用統一的錯誤處理模式：

```typescript
import { JsError, tryAsync } from '../../utils/errors.js'

const [result, error] = await tryAsync(() => compile(file))

if (error) {
  throw new JsError(file, '編譯失敗', {
    line: error.line,
    column: error.column,
    cause: error,
  })
}
```

錯誤類型：
- `ConfigError`：配置錯誤
- `ScssError`：SCSS 編譯錯誤
- `JsError`：JavaScript 編譯錯誤
- `HtmlError`：HTML 編譯錯誤
- `CompileError`：通用編譯錯誤

---

## 維護指南

### 新增編譯器

1. 在 `cmd/src/core/compiler/` 建立新檔案
2. 實作編譯函數，返回 `CompileResult`
3. 在 `build.ts` 中加入編譯階段

### 修改 JS hash 邏輯

檔案：`cmd/src/core/compiler/javascript.ts`

```typescript
export async function compileJsWithHash(
  inputFile: string,
  outputDir: string,
  options: Partial<JsCompilerOptions>
): Promise<CompileResult>
```

### 修改 Asset 路徑替換邏輯

檔案：`cmd/src/core/asset/index.ts`

```typescript
// Asset.toString() 中的分離模式
const jsTags = jsFiles.map(({ src, name }) => {
  if (this.jsMap && name) {
    const hashName = this.jsMap.get(name)
    if (hashName) {
      finalSrc = baseUrl + 'js/' + hashName
    }
  }
  // ...
})
```

### 修改 Model 上下文

檔案：`cmd/src/core/model/index.ts`

```typescript
const ctx: ModelContext = {
  config,
  Asset: () => createAsset(config, jsMap),
  jsEnv: generateJsEnv(config),
  require: (requirePath: string) => {
    let absolutePath: string
    if (requirePath.startsWith('/')) {
      // / 開頭：相對於 model 根目錄 (src/model/)
      absolutePath = path.join(config.source.dirs.model, requirePath.slice(1))
    } else {
      // 相對路徑：相對於當前 model 檔案
      absolutePath = path.resolve(modelDir, requirePath)
    }
    delete require.cache[require.resolve(absolutePath)]
    return require(absolutePath)
  },
}
```

---

*最後更新：2025-01-25*

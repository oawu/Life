# Lalilo

Lalilo 是一套個人網頁前端框架，用於快速編寫靜態網頁。

> 用自己做出來的工具開發，就像再品嚐自己做的一道菜，美味只有自己知道。

---

## 快速開始

```bash
cd cmd
npm install
npm run serve    # 開發伺服器 http://127.0.0.1:8000
npm run build    # 編譯至 dist/
```

---

## 專案結構

```
Lalilo/
├── src/                    # 開發目錄（所有開發皆在此進行）
│   ├── html/               # HTML 模板（Handlebars）
│   ├── scss/               # SCSS 樣式
│   ├── js/                 # JavaScript
│   ├── model/              # 資料模型（注入 HTML）
│   ├── tmpl/               # JS 模板（用於 __tmpl__ 注入）
│   └── img/                # 圖片資源
│
├── cmd/                    # 建構工具
│   └── config.yaml         # 預設配置
│
└── dist/                   # 編譯輸出
```

---

## 新增頁面

新增 `about` 頁面需建立三個檔案：

### 1. HTML 模板

```html
<!-- src/html/about.html -->
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Language" content="zh-tw" />
    <meta http-equiv="Content-type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,minimal-ui" />

    <title>{{ title }}</title>

    <script type="text/javascript">{{{ jsEnv }}}</script>

    {{{ asset }}}
  </head>
  <body lang="zh-Hant"></body>
</html>
```

| 語法 | 說明 |
|------|------|
| `{{ title }}` | 輸出純文字（自動 HTML 轉義） |
| `{{{ asset }}}` | 輸出 HTML（CSS/JS 標籤） |
| `{{{ jsEnv }}}` | 輸出環境變數 JavaScript |

### 2. Model 資料

```javascript
// src/model/about.js
module.exports = ({ Asset, jsEnv, require }) => {
  const base = require('/_base.js')

  return {
    title: base.title + ' - 關於我們',
    jsEnv,
    asset: () => base.createAsset(Asset, {
      scss: 'about.scss',
      js: 'about.js',
    }),
  }
}
```

### 3. 樣式與 JS

```scss
// src/scss/about.scss
@import "/_01-Var";

body { background: #f5f5f5; }
```

```javascript
// src/js/about.js
```

訪問 `http://127.0.0.1:8000/about` 即可預覽。

---

## Asset 資源載入

```javascript
// src/model/_base.js
module.exports = {
  title: 'Lalilo',
  coreScss: [
    '_01-Core/01-Elements',
    '_01-Core/02-Vars',
    // ...
    ],
  coreJs: [
    'https://unpkg.com/vue@3/dist/vue.global.js',
    '_01-Core/**',
  ],

  createAsset(Asset, options = {}) {
    const asset = Asset()
    this.coreScss.forEach(scss => asset.scss(scss))
    if (options.scss) asset.scss(options.scss)
    this.coreJs.forEach(js => asset.js(js))
    if (options.js) asset.js(options.js)
    return asset
  },
}
```

| 方法 | 說明 | 範例 |
|------|------|------|
| `.scss(path)` | 載入 SCSS | `.scss('index')` 或 `.scss('_01-Core/01-Elements')` |
| `.js(path)` | 載入 JavaScript | `.js('index.js')` 或 `.js('_01-Core/**')` |

---

## SCSS 開發

### 檔案規則

| 檔案格式 | 說明 |
|----------|------|
| `*.scss` | 會被編譯成 CSS |
| `_*.scss` | Partial，不會單獨編譯，供 `@import` 使用 |

### @import 路徑

```scss
@import "./_local";      // 相對於當前檔案
@import "/_01-Var";      // 相對於 src/scss/ 根目錄
@import "@/CSS3/Font";   // @oawu/scss 內建模組
```

---

## JavaScript 模板注入（__tmpl__）

在 JS 中使用 `__tmpl__` 可自動注入模板內容：

```javascript
// src/js/index.js
{
  __tmpl__: 'index',     // 查找 src/tmpl/index.html 或 index.el3
}
```

編譯時會自動替換為：

```javascript
{
  template: `<div id="app">...</div>`,
}
```

**查找優先級**：`.html` > `.el3`

**El3 語法**（類 Pug 縮進式 HTML）：

```
// src/tmpl/index.el3
div#app.container
  h1 標題
  p.text 內容
```

**模板使用方式請一定要先參考** [el3.md](./el3.md) - 模板注入功能

---

## 相關文件

### 指令說明（工作流程）

- [serve.md](./serve.md) - Serve 命令
- [build.md](./build.md) - Build 命令
- [deploy.md](./deploy.md) - Deploy 命令
- [flow.md](./flow.md) - Flow 命令

### 進階開發

- [model.md](./model.md) - Model 資料模型
- [asset.md](./asset.md) - Asset 資源管理
- [el3.md](./el3.md) - 模板注入功能
- [scss.md](./scss.md) - SCSS 開發指南
- [js.md](./js.md) - JavaScript 核心模組

---

## 作者

[OA Wu](https://www.ioa.tw/) - oawu.tw@gmail.com

## 授權

MIT License

# Model 資料模型

Model 負責將資料注入 HTML 模板，並管理頁面的 CSS/JS 資源載入。

---

## 目錄結構

```
src/model/
├── _base.js      # 共用配置（_ 開頭不會被當作頁面 Model）
├── index.js      # 首頁 Model（對應 src/html/index.html）
├── about.js      # 關於頁 Model（對應 src/html/about.html）
└── page/
    └── sub.js    # 子頁面 Model（對應 src/html/page/sub.html）
```

---

## Model Context

每個 Model 檔案接收一個 Context 物件：

```javascript
module.exports = ({ Asset, env, Env, require, config }) => {
  // ...
}
```

| 屬性 | 型別 | 說明 |
|------|------|------|
| `Asset` | `() => Asset` | Asset 建構函數 |
| `env` | `string` | 前端環境變數腳本（完整版） |
| `Env` | `(modifier?) => string` | 自訂環境變數（接收 modifier 函式修改 env 物件後序列化） |
| `require` | `(path) => any` | 載入相對路徑模組 |
| `config` | `FullConfig` | 完整配置物件 |

### env vs Env

- **`env`**：已序列化的完整 `window.Env` 字串，適合大多數頁面直接使用
- **`Env(modifier?)`**：每次呼叫重建 env 物件，可透過 modifier 刪除或修改屬性後再序列化，適合需要精簡 env 的頁面（如公開頁面不需要 API URL）

```javascript
// 使用完整 env（等同 Env() 不帶參數）
module.exports = ({ env }) => ({ env })

// 自訂 env：移除不需要的屬性
module.exports = ({ Env }) => ({
  env: Env((env) => {
    delete env.url.api
    delete env.config
  }),
})
```

---

## require 路徑規則

由於 Model 檔案會被複製到暫存目錄執行，需使用 Context 提供的 `require` 函數：

| 寫法 | 解析結果 |
|------|----------|
| `require('./_base.js')` | 相對於當前 Model 檔案 |
| `require('../_base.js')` | 相對於當前檔案的上層 |
| `require('/_base.js')` | `src/model/_base.js`（相對於 model 根目錄） |

```javascript
// src/model/page/sub.js
module.exports = ({ require }) => {
  // 以下兩種寫法等效
  const base = require('../_base.js')  // 相對路徑
  const base = require('/_base.js')    // / 開頭

  return { /* ... */ }
}
```

---

## 共用配置（_base.js）

```javascript
// src/model/_base.js
module.exports = {
  title: 'Lalilo',

  // 共用 Icon
  coreIcon: ['icon'],

  // 共用 SCSS
  coreScss: [
    '_01-Core/01-Elements',
    '_01-Core/02-Vars',
  ],

  // 共用 JS
  coreJs: [
    'https://cdn.jsdelivr.net/npm/vue@2.6.11/dist/vue.min.js',
    '_01-Core/**',
  ],

  // 建立包含共用資源的 Asset
  createAsset(Asset, options = {}) {
    const asset = Asset()

    this.coreIcon.forEach(icon => asset.icon(icon))
    this.coreScss.forEach(scss => asset.scss(scss))
    if (options.scss) {
      const list = Array.isArray(options.scss) ? options.scss : [options.scss]
      list.forEach(scss => asset.scss(scss))
    }

    this.coreJs.forEach(js => asset.js(js))
    if (options.js) {
      const list = Array.isArray(options.js) ? options.js : [options.js]
      list.forEach(js => asset.js(js))
    }

    return asset
  },
}
```

---

## 頁面 Model

```javascript
// src/model/index.js
module.exports = ({ Asset, env, require }) => {
  const base = require('./_base.js')

  return {
    title: base.title,
    env,
    asset: () => base.createAsset(Asset, {
      scss: 'index',
      js: 'index.js',
    }),
  }
}
```

---

## HTML 模板使用

```html
<!-- src/html/index.html -->
<!DOCTYPE html>
<html>
  <head>
    <title>{{ title }}</title>
    <script>{{{ env }}}</script>
    {{{ asset }}}
  </head>
  <body>
    <div id="app"></div>
  </body>
</html>
```

| 語法 | 說明 |
|------|------|
| `{{ var }}` | 輸出並 HTML 轉義 |
| `{{{ var }}}` | 輸出原始 HTML |

---

## 資料解析流程

Model 返回的資料會經過遞迴解析：

1. **Asset 實例** → 呼叫 `toString()` 產生 HTML 標籤
2. **函數** → 執行並遞迴解析結果
3. **Promise** → await 並遞迴解析結果
4. **陣列/物件** → 遞迴處理每個元素

```javascript
module.exports = ({ Asset }) => ({
  // 函數會被執行
  asset: () => Asset().scss('index').js('index.js'),

  // 直接值
  title: 'Hello',

  // 陣列會被遞迴處理
  items: [
    { name: 'A' },
    { name: 'B' },
  ],
})
```

---

## 錯誤處理

Model 載入失敗時，會顯示：

- 檔案路徑
- 錯誤行號（從 stack trace 提取）
- 錯誤訊息

```
Model 載入錯誤
  檔案: model/index.js
  位置: 第 15 行
  錯誤: xxx is not defined
```

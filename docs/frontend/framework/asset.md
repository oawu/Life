# Asset 資源管理

Asset 類別用於管理頁面的 CSS、JS 和 Icon 資源載入，產生對應的 HTML 標籤。

---

## 基本用法

```javascript
// src/model/index.js
module.exports = ({ Asset }) => ({
  asset: () => Asset()
    .icon('icon')
    .scss('index')
    .js('index.js'),
})
```

---

## 方法說明

### .icon(name)

載入 Icon CSS。

```javascript
asset.icon('icon')     // → cmd/node_modules/_/icon/icon.css
asset.icon('other')    // → cmd/node_modules/_/icon/other.css
```

### .scss(path)

載入 SCSS 檔案。支援多種格式：

```javascript
asset.scss('index')              // → src/scss/index.scss
asset.scss('index.scss')         // → src/scss/index.scss
asset.scss('index.css')          // → src/scss/index.scss
asset.scss('_01-Core/01-Elements')  // → src/scss/_01-Core/01-Elements.scss
```

### .js(path)

載入 JavaScript 檔案。

```javascript
asset.js('index.js')                    // 單一檔案
asset.js('_01-Core/**')                    // 遞迴載入目錄下所有 JS
asset.js('_01-Core/*')                     // 載入目錄下的 JS（不遞迴）
asset.js('https://cdn.example.com/x.js') // 外部 URL
```

---

## 萬用字元

| 萬用字元 | 說明 |
|----------|------|
| `*` | 載入目錄下的檔案（不含子目錄） |
| `**` | 遞迴載入目錄下所有檔案 |

```javascript
asset.js('_01-Core/**')  // 載入 _01-Core/ 下所有 JS，包含子目錄
asset.js('_01-Core/*')   // 只載入 _01-Core/ 下的 JS，不含子目錄
```

---

## 合併模式（--merge）

使用 `--merge` 參數時，CSS 和 JS 會被內聯到 HTML 中：

**一般模式輸出**：

```html
<link href="css/index.css" type="text/css" rel="stylesheet" />
<script src="js/index.js"></script>
```

**合併模式輸出**：

```html
<style type="text/css">
body { background: #fff; }
</style>
<script type="text/javascript">
console.log('Hello');
</script>
```

---

## Hash 模式（build --hash）

Build 時使用 `--hash` 參數，JS 和 CSS 檔名會替換為 MD5 hash：

```html
<!-- 原始 -->
<script src="js/index.js"></script>

<!-- Hash 模式 -->
<script src="js/a1b2c3d4e5f6.js"></script>
```

---

## 屬性設定

每個方法都支援第二個參數設定 HTML 屬性：

```javascript
asset.scss('index', { media: 'screen' })
// → <link href="css/index.css" media="screen" ... />

asset.js('index.js', false, { defer: null })
// → <script src="js/index.js" defer></script>
```

### .js() 的 merge 參數

`.js()` 的第二個參數控制合併模式下是否合併該檔案：

```javascript
asset.js('index.js', true)   // 合併模式下會合併（預設）
asset.js('index.js', false)  // 合併模式下不合併，保持獨立 script 標籤
```

---

## 完整範例

```javascript
// src/model/_base.js
module.exports = {
  coreIcon: ['icon'],
  coreScss: ['_01-Core/01-Elements', '_01-Core/02-Vars'],
  coreJs: [
    'https://cdn.jsdelivr.net/npm/vue@2.6.11/dist/vue.min.js',
    '_01-Core/**',
  ],

  createAsset(Asset, options = {}) {
    const asset = Asset()

    // 載入共用資源
    this.coreIcon.forEach(icon => asset.icon(icon))
    this.coreScss.forEach(scss => asset.scss(scss))
    this.coreJs.forEach(js => asset.js(js))

    // 載入頁面專屬資源
    if (options.scss) {
      const list = Array.isArray(options.scss) ? options.scss : [options.scss]
      list.forEach(scss => asset.scss(scss))
    }

    if (options.js) {
      const list = Array.isArray(options.js) ? options.js : [options.js]
      list.forEach(js => asset.js(js))
    }

    return asset
  },
}
```

```javascript
// src/model/index.js
module.exports = ({ Asset, jsEnv, require }) => {
  const base = require('/_base.js')

  return {
    jsEnv,
    asset: () => base.createAsset(Asset, {
      scss: ['index', 'components/header'],
      js: ['index.js', 'components/**'],
    }),
  }
}
```

---

## 輸出順序

資源按照加入順序輸出：

```javascript
asset
  .icon('icon')       // 1. Icon CSS
  .scss('_01-Core/01')   // 2. Core CSS
  .scss('index')      // 3. 頁面 CSS
  .js('vue.min.js')   // 4. Vue
  .js('_01-Core/**')     // 5. Core JS
  .js('index.js')     // 6. 頁面 JS
```

輸出：

```html
<link href="icon/icon.css" ... />
<link href="css/_01-Core/01.css" ... />
<link href="css/index.css" ... />
<script src="vue.min.js"></script>
<script src="js/_01-Core/01-Helper.js"></script>
<script src="js/_01-Core/02-Load.js"></script>
...
<script src="js/index.js"></script>
```

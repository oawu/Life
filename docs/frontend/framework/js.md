# JavaScript 核心模組

本文件說明 Lalilo 專案的 JavaScript 核心模組架構。

---

## 目錄結構

```
src/js/
├── _01-Core/                  # 核心模組（依數字順序載入）
│   ├── 01-Helper.js        # 工具函數
│   ├── 02-Load.js          # Vue 組件載入
│   ├── 03-El3.js           # El3 模板語法
│   ├── 04-Param.js         # URL 參數解析
│   ├── 05-Data.js          # 資料管理
│   ├── 06-Api.js           # API 請求
│   ├── 07-Copy.js          # 複製功能
│   ├── 08-Page.js          # 頁面管理
│   └── 09-Bus.js           # 事件總線
│
├── index.js                # 首頁
├── about.js                # 關於頁
└── components/             # 共用元件
    └── header.js
```

---

## 核心模組說明

### 01-Helper.js

類型檢查與工具函數。

```javascript
// 類型檢查
Type.isString(val)
Type.isNumber(val)
Type.isArray(val)
Type.isObject(val)
Type.isFunction(val)
Type.isBoolean(val)
Type.isNull(val)
Type.isUndefined(val)

// JSON 工具
Json.parse(str)
Json.stringify(obj)
```

### 02-Load.js

Vue 組件載入系統（Composition API）。

```javascript
// 載入 Vue 組件
Load.Vue(({ ref, onMounted }) => ({
  setup() {
    const message = ref('Hello')
    const submit = () => { /* ... */ }
    return { message, submit }
  },
  __tmpl__: 'index',       // 自動注入模板
}))
```

### 03-El3.js

El3 模板語法（前端版本），用於動態產生 HTML。

```javascript
// 字串轉 HTML
const html = El3(`
  div#app.container
    h1 Hello
    p World
`)
// → <div id="app" class="container"><h1>Hello</h1><p>World</p></div>
```

### 04-Param.js

URL 參數解析。

```javascript
// 取得 URL 參數
const id = Param.get('id')
const page = Param.get('page', 1)  // 預設值

// 設定 URL 參數
Param.set('id', 123)
Param.set({ id: 123, page: 2 })
```

### 05-Data.js

資料管理（localStorage 包裝）。

```javascript
// 儲存資料
Data.set('user', { name: 'OA' })

// 讀取資料
const user = Data.get('user')
const token = Data.get('token', 'default')

// 刪除資料
Data.remove('user')
```

### 06-Api.js

API 請求模組。

```javascript
// GET 請求
Api('/api/users').get()

// POST 請求 (JSON body)
Api('/api/users')
  .payload.raw({ name: 'OA' })
  .post()

// 其他方法
Api('/api/users/1').payload.raw(data).put()
Api('/api/users/1').del()
```

### 07-Copy.js

複製到剪貼簿。

```javascript
// 複製文字
Copy.text('Hello World').then(() => {
  console.log('已複製')
})

// 複製元素內容
Copy.element(document.querySelector('.content'))
```

### 08-Page.js

頁面管理。

```javascript
// 頁面跳轉
Page.go('/about')
Page.go('/page/sub', { id: 123 })

// 重載頁面
Page.reload()

// 回上一頁
Page.back()
```

### 09-Bus.js

事件總線，用於組件間通訊。

```javascript
// 監聽事件
Bus.on('user:login', (user) => {
  console.log('User logged in:', user)
})

// 發送事件
Bus.emit('user:login', { name: 'OA' })

// 移除監聽
Bus.off('user:login')
```

---

## 在 Model 中載入

```javascript
// src/model/_base.js
module.exports = {
  coreJs: [
    'https://unpkg.com/vue@3/dist/vue.global.js',
    '_01-Core/**',  // 載入所有核心模組
  ],
}
```

```javascript
// src/model/index.js
module.exports = ({ Asset, require }) => {
  const base = require('/_base.js')

  return {
    asset: () => base.createAsset(Asset, {
      js: 'index.js',
    }),
  }
}
```

---

## 頁面 JS 範例

```javascript
// src/js/index.js
Load.Vue(({ ref, reactive, onMounted }) => ({
  setup() {
    const title = ref('Lalilo')
    const items = reactive([])
    const loading = ref(false)

    const fetchItems = async () => {
      loading.value = true
      try {
        const res = await Api('/api/items').get()
        items.push(...res.data)
      } catch (e) {
        console.error(e)
      }
      loading.value = false
    }

    const copyItem = (item) => {
      Copy.str(item.name).then(() => {
        Bus.emit('toast', '已複製')
      })
    }

    onMounted(() => {
      fetchItems()
    })

    return { title, items, loading, fetchItems, copyItem }
  },
  __tmpl__: 'index',
}))

// 監聽全域事件
Bus.on('toast', (message) => {
  alert(message)
})
```

---

## __tmpl__ 模板注入

JS 檔案中的 `__tmpl__` 會在編譯時自動替換為模板內容：

```javascript
// 原始碼
Load.Vue(({ ref }) => ({
  setup() {
    return { /* ... */ }
  },
  __tmpl__: 'index',
}))

// 編譯後
Load.Vue(({ ref }) => ({
  setup() {
    return { /* ... */ }
  },
  template: `<div id="app">...</div>`,
}))
```

詳見 [模板注入功能](./tmpl.md)。

---

## Build 編譯

Build 時使用 esbuild 編譯：

- 支援 ES2020+ 語法
- 自動壓縮（`--minify`）
- MD5 hash 檔名（`--hash`）

```bash
npm run build -- --minify --hash
```

輸出：

```
dist/js/
├── a1b2c3d4.js    # _01-Core/01-Helper.js
├── e5f6g7h8.js    # _01-Core/02-Load.js
├── ...
└── z9y8x7w6.js    # index.js
```

---

## 注意事項

1. **載入順序**：`_01-Core/**` 會按檔名數字順序載入
2. **全域變數**：核心模組會註冊全域變數（Type、Load、El3 等）
3. **Vue 版本**：預設使用 Vue 3
4. **模板注入**：使用 `__tmpl__` 需確保 `src/tmpl/` 有對應檔案

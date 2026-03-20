# Vue 組件開發規範

## 私有變數與函數命名

在 Vue 組件的 `setup()` 中，若變數或函數**不會**傳入 template（即不在 `return` 中回傳給 `__tmpl__` 使用），命名時加上 `_` 前綴以區分：

```javascript
setup(props, { emit }) {
  const el = ref(null)           // ✓ 會傳入 template
  const photos = ref([])         // ✓ 會傳入 template

  let _observer = null           // ✓ 私有變數，不傳入 template
  const _cache = new Map()       // ✓ 私有變數，不傳入 template

  const load = () => { ... }     // ✓ 會傳入 template
  const _handleResize = () => {} // ✓ 私有函數，不傳入 template

  return {
    el,
    photos,
    load,
    // _observer, _cache, _handleResize 不需要回傳
  }
}
```

**檢查原則**：寫 `return` 時，逐一確認：有 return 的不加 `_`，沒 return 的才加 `_`。

**⚠️ Vue 3 限制**：Vue 3 會過濾以 `_` 或 `$` 開頭的屬性，不會代理到組件實例上。因此即使將 `_` 開頭的變數放入 `return`，template 中也無法存取，會導致渲染錯誤。**絕對不要在 `return` 中回傳 `_` 開頭的變數**。

## 組件程式碼結構

### IIFE 層級

頁面組件（註冊在 `Core.page`）的 IIFE 結構：

```javascript
void (() => {
  // ===== 確保存在 =====
  window.Core = window.Core || {}
  window.Core.page = window.Core.page || {}
  // ...依需求補齊 ui, modal, helper, layout, component

  // ===== 引用 components 資源 =====
  const { Icon, Segmented } = window.Core.component
  const { GridPhoto } = window.Core.page

  const MyPage = {
    components: { Icon, Segmented, GridPhoto },
    setup(props) { ... },
    __tmpl__: 'admin/my-page',
  }

  window.Core.page.MyPage = MyPage
})();
```

- **確保存在**：確保 `window.Core` 各命名空間存在
- **引用 components 資源**：解構 `components:` 所需的組件

根組件（如 `app.js`）不需要「確保存在」，直接從 `window.Core` 引用。

### setup() 區塊順序

```javascript
setup(props) {
  // ===== 引用資源 =====        ← setup 內用到的 Core / Vue API
  // ===== 普通變數 =====        ← 非響應式的固定值
  // ===== 響應式變數 =====      ← ref, reactive
  // ===== 計算屬性 =====        ← computed
  // ===== 事件處理函式 =====    ← template 綁定的 @click 等
  // ===== 模板輔助函式 =====    ← boolean check、formatter、style getter
  // ===== 私有函式 =====        ← 不傳入 template 的內部邏輯
  // ===== 初始設定 =====        ← watch, onMounted, inject, provide
  // ===== 回傳 =====            ← return { ... }
}
```

**規則**：
- 只列出有內容的區塊，空區塊不需要出現
- 區塊之間用兩個空行分隔
- `return` 內使用相同的區塊註解分組
- **修改既有程式碼時**：新增的變數或函式必須放在對應區塊，不可就近宣告在使用處旁邊。例如新增 `let` 旗標放「普通變數」、新增 `ref()` 放「響應式變數」、新增內部函式放「私有函式」。若該區塊不存在，先建立區塊再加入。

### 事件處理函式的子分類

當事件處理函式同時包含 DOM 事件和子組件事件時，用子註解分隔：

```javascript
// ===== 事件處理函式 =====
const onClickSave = () => { ... }
const onDrop = (event) => { ... }
// 子組件事件
const retryUpload = (item) => { ... }
const removeFromQueue = (id) => { ... }
```

`return` 中同樣保持對應結構：

```javascript
// ===== 事件處理函式 =====
onClickSave,
onDrop,
// 子組件事件
retryUpload,
removeFromQueue,
```

## API 請求提前發起（`_prepare` 模式）

頁面初始化需要的 API 請求，應在 `setup()` 中立即發起，不要等到 `onMounted` 才開始。這樣網路請求與 Vue 渲染可以並行，減少等待時間。

**關鍵**：`_prepare` 只負責發起網路請求（不依賴 DOM），資料賦值和 DOM 操作留在 `onMounted` 中處理：

```javascript
// ===== 私有函式 =====
const _fetchProfile = () => _hooks(Api('/api/profile')).get()

const _applyProfile = (data) => {
  userName.value = data.name || ''
  items.value = data.items
}

// ===== 初始設定 =====
// 提前發起網路請求（不需要 DOM）
const _prepare = _fetchProfile()

onMounted(async () => {
  try {
    const { data } = await _prepare
    _applyProfile(data)
    await nextTick()
    _initSortable()  // DOM 操作在 mounted 後才安全
  } catch (e) {
    Toastr.failure('載入失敗')
  }
})
```

```javascript
// ✗ 錯誤：等 onMounted 才開始請求，浪費了 setup → mounted 之間的時間
onMounted(() => {
  _loadData()
})
```

**原則**：只要請求不依賴 DOM，就在 `setup()` 同步階段立即發起，`onMounted` 中 `await` 取得結果後再操作 DOM。

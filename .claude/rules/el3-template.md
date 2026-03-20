# El3 模板語法規範

**注意!** 完整說明文件：docs/frontend/framework/el3.md

## 語法速查表

| el3 語法 | HTML + Vue |
|----------|------------|
| `div.class#id` | `<div class="class" id="id">` |
| `*text='內容'` | `v-text="'內容'"` |
| `*text=variable` | `v-text="variable"` |
| `*for=item in list` | `v-for="item in list"` |
| `*if=condition` | `v-if="condition"` |
| `*else-if=cond` | `v-else-if="cond"` |
| `*else` | `v-else` |
| `*model=value` | `v-model="value"` |
| `:class={ 'active': isActive }` | `:class="{ 'active': isActive }"` |
| `:style={ color: c }` | `:style="{ color: c }"` |
| `@click=handler` | `@click="handler"` |
| `>> variable` | `{{ variable }}` (插值) |
| `| 純文字` | 純文字節點 |

## 屬性值轉譯訣竅

el3 編譯時會將 `=` 右邊的值加上雙引號 `"`，所以可以**反推**來判斷該不該加單引號 `'`：

| 目標 HTML | 反推 | El3 寫法 |
|-----------|------|----------|
| `type="text"` | 去除 `"` → `text` | `type=text` |
| `v-model="name"` | 去除 `"` → `name` | `*model=name` |
| `v-text="message"` | 去除 `"` → `message` | `*text=message` |
| `v-text="'靜態文字'"` | 去除 `"` → `'靜態文字'` | `*text='靜態文字'` |
| `:disabled="loading"` | 去除 `"` → `loading` | `:disabled=loading` |

**範例**：

```
// 目標：<input type="text" v-model="username">
input => type=text   *model=username

// 目標：<span v-text="'Hello'"></span>
span => *text='Hello'

// 目標：<span v-text="count"></span>
span => *text=count
```

## 常見錯誤（AI 必讀）

```
// ✗ 錯誤：屬性值加了雙引號
span => *text="'內容'"
span => *text="變數"

// ✓ 正確：屬性值不需要雙引號
span => *text='內容'
span => *text=變數
```

```
// ✗ 錯誤：普通屬性使用單引號包裹靜態值
// el3 編譯時會將 = 右邊加上雙引號，所以 title='文字' → title="'文字'"
Layout => title='Api.js 測試'
input => placeholder='請輸入'

// ✓ 正確：普通屬性不需要引號
Layout => title=Api.js 測試
input => placeholder=請輸入

// ✓ 正確：或使用 Vue 綁定（冒號開頭），這樣單引號表示字串
Layout => :title='Api.js 測試'
input => :placeholder='請輸入'

// 區分：Vue 指令 vs 普通屬性
// Vue 指令（*text, *if, :class 等）：單引號表示字串 → *text='靜態文字'
// 普通屬性（type, placeholder, title 等）：不需要引號 → type=text
```

```
// ✗ 錯誤：標籤不能直接接文字
h1 標題
p.intro 介紹

// ✓ 正確：使用 *text= 或子元素 |
h1 => *text='標題'
p.intro => *text='介紹'
```

```
// ✗ 錯誤：多個屬性只用 1-2 個空格
button => @click=fn :disabled=d

// ✓ 正確：多個屬性用 3+ 個空格分隔
button => @click=fn   :disabled=d
```

```
// 注意：// 開頭會變成 HTML 註解
// 這行會變成 <!-- 這行會變成 -->

// 若要顯示 // 文字，用 *text=
span => *text='// 註解文字'
```

```
// ⚠️ 重要：*text= 值中「不可包含任何引號」（單引號或雙引號都不行）
// 因為 *text= 編譯後會變成 v-text="..."，值中的引號會造成衝突
// 如果文字內容包含引號，必須改用 | 語法

// ✗ 錯誤：包含雙引號
h4 => *text='type="cell"'
// 編譯後：v-text="'type="cell"'" ← 雙引號衝突！

// ✗ 錯誤：包含單引號
span => *text="Api.when('auth')"
// 編譯後：v-text=""Api.when('auth')"" ← 引號衝突！

// ✓ 正確：使用 | 符號（推薦）
h4
  | type="cell"
span
  | Api.when('auth', api => {

// ✓ 正確：將含引號的字串存為 JS 變數
// JS: const code = "Api.when('auth')"
// el3: span => *text=code
```

```
// ✗ 錯誤：*for 和 *if 不能同時用在同一元素上
// Vue 3 中 v-if 優先於 v-for，導致 v-if 無法存取 v-for 的變數
.item => *for=item in items   :key=item.id   *if=item.active

// ✓ 正確：使用 template 包裹 *for，內層元素用 *if
template => *for=item in items   :key=item.id
  .item => *if=item.active
    span => *text=item.name

// ✓ 正確：或使用 computed 預先過濾資料
// JS: const activeItems = computed(() => items.filter(i => i.active))
.item => *for=item in activeItems   :key=item.id
  span => *text=item.name
```

```
// ✗ 錯誤：*text= 無法包含變數插值 {{ }}
button => *text='發送 ({{ count }})'

// ✓ 正確：使用 | 語法來包含變數插值
button => @click=send
  | 發送 ({{ count }})

// 區分：
// *text='靜態文字'     → 純靜態文字
// *text=variable      → 純變數
// | 文字 {{ var }}    → 文字中包含變數插值
```

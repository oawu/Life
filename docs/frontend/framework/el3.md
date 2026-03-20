# 模板注入功能（__tmpl__）

`__tmpl__` 功能允許在 JavaScript 檔案中引用外部模板，編譯時自動注入模板內容。

---

## 基本用法

在 JS 檔案中使用 `__tmpl__` 標記：

```javascript
// src/js/index.js
Load.Vue(({ ref }) => ({
  setup() {
    const message = ref('Hello!')
    return { message }
  },
  __tmpl__: 'index',
}))
```

編譯時會自動查找 `src/tmpl/index.html` 或 `src/tmpl/index.el3`，並替換為：

```javascript
Load.Vue(({ ref }) => ({
  setup() {
    const message = ref('Hello!')
    return { message }
  },
  template: `<div id="app"><h1>Hello</h1></div>`,
}))
```

---

## 模板查找規則

| `__tmpl__` 值 | 查找路徑 |
|---------------|----------|
| `'index'` | `src/tmpl/index.html` 或 `src/tmpl/index.el3` |
| `'page/a'` | `src/tmpl/page/a.html` 或 `src/tmpl/page/a.el3` |
| `'components/header'` | `src/tmpl/components/header.html` 或 `src/tmpl/components/header.el3` |

**優先級**：`.html` > `.el3`

---

## 支援的格式

### HTML 格式（.html）

直接編寫 HTML：

```html
<!-- src/tmpl/index.html -->
<div id="app">
  <h1>{{ title }}</h1>
  <p>{{ message }}</p>
</div>
```

### El3 格式（.el3）

使用類 Pug 的縮進式語法，但是與 Pug 完全不同：

```
// src/tmpl/index.el3
div#app
  h1 => *text=title
  p => *text=message
```

---

## El3 語法詳解

El3 是一種類似 Pug 的縮進式 HTML 語法，但是與 Pug 完全不同，專為 Lalilo 框架模板設計。

### 行結構

每行的基本結構為：

```
標籤#id.class => 屬性1=值1   屬性2=值2
```

- **標籤**：HTML 標籤名（可省略，預設為 `div`）
- **`#id`**：ID 選擇器
- **`.class`**：Class 選擇器（可多個）
- **`=>`**：分隔符，前後各需**至少一個空格**
- **屬性**：以 **3 個以上空格**分隔多個屬性
- **屬性值**：**不需要**雙引號包裹

### 縮進規則

使用 **2 個空格**表示巢狀層級：

```
div.container
  header
    h1 => *text='標題'
  main
    p => *text='內容'
```

輸出：

```html
<div class="container">
  <header><h1 v-text="'標題'"></h1></header>
  <main><p v-text="'內容'"></p></main>
</div>
```

---

### 標籤與文字內容

文字內容**必須**使用 `*text=` 或子元素 `|`，但優先使用 `*text=`，不可直接接在標籤後：

```
// ✗ 錯誤寫法
h1 標題
p 這是段落內容

// ✓ 正確寫法 - 使用 *text
h1 => *text='標題'
p => *text='這是段落內容'

// ✓ 正確寫法 - 使用子元素
h1
  | 標題
```

輸出：

```html
<h1 v-text="'標題'"></h1>
<p v-text="'這是段落內容'"></p>
```

**優先級**：`*text=` > `|`

---

### ID 和 Class

```
div#app
div.container
div#app.container.main
#app                      // 標籤省略，預設為 div
.container.flex           // 標籤省略，預設為 div
```

輸出：

```html
<div id="app"></div>
<div class="container"></div>
<div id="app" class="container main"></div>
<div id="app"></div>
<div class="container flex"></div>
```

---

### 屬性語法

使用 `=>` 後接屬性，多個屬性用 **3+ 空格**分隔，**屬性值不需要雙引號**：

```
input => type=text   placeholder=請輸入...
a => href=https://example.com   target=_blank
img => src=logo.png   alt=Logo
```

輸出：

```html
<input type="text" placeholder="請輸入..." />
<a href="https://example.com" target="_blank"></a>
<img src="logo.png" alt="Logo" />
```

---

### 屬性值轉譯訣竅

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

---

### Vue 指令簡寫

El3 提供 Vue 指令的簡寫語法，**屬性值不需要雙引號**：

| El3 寫法 | 轉換 HTML 結果 |
|----------|----------|
| `*if=condition` | `v-if="condition"` |
| `*else-if=condition` | `v-else-if="condition"` |
| `*else` | `v-else` |
| `*for=(item, i) in items` | `v-for="(item, i) in items"` |
| `*show=visible` | `v-show="visible"` |
| `*model=text` | `v-model="text"` |
| `*text=message` | `v-text="message"` |
| `*text='靜態文字'` | `v-text="'靜態文字'"` |
| `*html=content` | `v-html="content"` |
| `@click=handler` | `v-on:click="handler"` |
| `@click=handler(param)` | `v-on:click="handler(param)"` |
| `:class=classes` | `:class="classes"` |
| `:class={ 'active': isActive }` | `:class="{ 'active': isActive }"` |
| `:style={ color: textColor }` | `:style="{ color: textColor }"` |
| `:slot:header` | `v-slot:header` |

#### 範例

```
div => *if=show
  input => *model=text   @input=onChange
  button => @click=submit   :disabled=loading   *text='送出'
  span => *text=message
div => *else
  p => *text='無內容'
ul
  li => *for=(item, i) in items   :key=i
    >> item.name
```

輸出：

```html
<div v-if="show">
  <input v-model="text" v-on:input="onChange" />
  <button v-on:click="submit" :disabled="loading" v-text="'送出'"></button>
  <span v-text="message"></span>
</div>
<div v-else>
  <p v-text="'無內容'"></p>
</div>
<ul>
  <li v-for="(item, i) in items" :key="i">{{ item.name }}</li>
</ul>
```

---

### 動態綁定語法

#### :class 物件語法

```
div => :class={ 'active': isActive, 'error': hasError }
button => :class={ 'btn-primary': isPrimary }   @click=onClick
```

#### :style 物件語法

```
div => :style={ color: textColor, fontSize: size + 'px' }
span => :style={ background: bgColor }
```

#### 條件判斷

```
p => *if=count === 0   *text='沒有資料'
p => *else-if=count < 10   *text='資料較少'
p => *else   *text='資料充足'
```

#### 迴圈

```
ul
  li => *for=(item, index) in items   :key=index
    span => *text=item.name
```

---

### 特殊語法

#### 註解

以 `//` 開頭，轉換為 HTML 註解：

```
// 這是註解
div
  // 巢狀註解
  p 內容
```

輸出：

```html
<!-- 這是註解 -->
<div>
  <!-- 巢狀註解 -->
  <p>內容</p>
</div>
```

#### 輸出變數（Mustache）

以 `>>` 開頭，轉換為 `{{ }}` 語法，適用於需要在標籤內混合文字與變數：

```
span
  >> count
```

輸出：

```html
<span>{{ count }}</span>
```

#### 純文字

以 `|` 開頭，輸出純文字。適用於混合多個元素與文字：

```
p
  | 歡迎來到
  a => href=/   *text='首頁'
  | ，祝您使用愉快！
```

輸出：

```html
<p>歡迎來到<a href="/" v-text="'首頁'"></a>，祝您使用愉快！</p>
```

**建議**：單純顯示文字時，優先使用 `*text=` 而非 `|`

```
// 推薦
span.label => *text='標籤'

// 較不推薦
span.label
  | 標籤
```

---

### 自閉合標籤

以下標籤會自動處理為自閉合：

```
area, base, br, col, command, embed, hr, img,
input, keygen, link, meta, param, source, track, wbr
```

範例：

```
div
  input => type=text   *model=value
  br
  img => src=photo.jpg   alt=照片
```

輸出：

```html
<div>
  <input type="text" v-model="value" />
  <br />
  <img src="photo.jpg" alt="照片" />
</div>
```

---

### Class 合併

多個 `.class` 會自動合併：

```
div.container.flex.center
button.btn.btn-primary.large => @click=submit
```

輸出：

```html
<div class="container flex center"></div>
<button class="btn btn-primary large" v-on:click="submit"></button>
```

---

## 目錄結構範例

```
src/
├── js/
│   ├── index.js          # __tmpl__: 'index'
│   └── page/
│       └── a.js          # __tmpl__: 'page/a'
│
└── tmpl/
    ├── index.el3
    └── page/
        └── a.el3
```

---

## 注意事項

1. **屬性值不需要雙引號**：`type=text` 而非 `type="text"`
2. **物件語法使用大括號**：`:class={ 'active': isActive }`
3. **多個屬性用 3+ 空格分隔**：`@click=fn   :disabled=loading`
4. **`=>` 分隔符前後需有空格**：`div => *if=show`
5. **優先使用 `*text=` 顯示文字**：比 `|` 更簡潔
6. **找不到模板**：若找不到對應的模板檔案，`__tmpl__` 行會被移除
7. **HTML 壓縮**：模板內容會自動壓縮，移除多餘空白

---

## 完整範例

**JS 檔案**：

```javascript
// src/js/index.js
window.Load.Vue(({ ref, reactive, computed }) => {
  return {
    setup() {
      const title = ref('Lalilo')
      const show = ref(true)
      const items = reactive([])

      const add = () => {
        items.push({ name: 'New Item' })
      }

      return { title, show, items, add }
    },
    __tmpl__: 'index',
  }
})
```

**El3 模板**：

```
// src/tmpl/index.el3
div#app.container
  h1.title => *text=title

  div => *if=show
    ul.list
      li => *for=(item, i) in items   :key=i
        span => *text=item.name
    button.btn => @click=add   *text='新增'

  div => *else
    p.empty => *text='無資料'
```

**編譯結果**：

```javascript
window.Load.Vue(({ ref, reactive, computed }) => {
  return {
    setup() {
      const title = ref('Lalilo')
      const show = ref(true)
      const items = reactive([])

      const add = () => {
        items.push({ name: 'New Item' })
      }

      return { title, show, items, add }
    },
    template: `<div id="app" class="container"><h1 class="title" v-text="title"></h1><div v-if="show"><ul class="list"><li v-for="(item, i) in items" :key="i"><span v-text="item.name"></span></li></ul><button class="btn" v-on:click="add" v-text="'新增'"></button></div><div v-else><p class="empty" v-text="'無資料'"></p></div></div>`,
  }
})
```

---

## 語法對照表

| El3 | HTML |
|-----|------|
| `div` | `<div></div>` |
| `div#app` | `<div id="app"></div>` |
| `.container` | `<div class="container"></div>` |
| `div#app.a.b` | `<div id="app" class="a b"></div>` |
| `p => *text='文字'` | `<p v-text="'文字'"></p>` |
| `div => *if=x` | `<div v-if="x"></div>` |
| `div => *for=(i, idx) in arr` | `<div v-for="(i, idx) in arr"></div>` |
| `div => @click=fn` | `<div v-on:click="fn"></div>` |
| `div => :class={ 'a': b }` | `<div :class="{ 'a': b }"></div>` |
| `// 註解` | `<!-- 註解 -->` |
| `>> var` | `{{ var }}` |
| `| 文字` | `文字` |

---

## 常見錯誤

```
// ✗ 錯誤：標籤不能直接接文字
h1 標題
p.intro 介紹文字

// ✓ 正確：使用 *text=
h1 => *text='標題'
p.intro => *text='介紹文字'
```

```
// ✗ 錯誤：屬性值加了雙引號
input => type="text"

// ✓ 正確
input => type=text
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
// ✗ 錯誤：物件語法加了雙引號
div => :class="{ 'active': isActive }"

// ✓ 正確
div => :class={ 'active': isActive }
```

```
// ✗ 錯誤：屬性間只有 1-2 個空格
button => @click=fn :disabled=loading

// ✓ 正確：屬性間需 3+ 個空格
button => @click=fn   :disabled=loading
```

```
// ✗ 錯誤：*text= 值包含單引號造成衝突
// 因為 *text= 編譯後會變成 v-text="..."
// 所以 *text="Api.when('auth')" 會變成 v-text=""Api.when('auth')""
span => *text="Api.when('auth', api => {"

// ✓ 正確：將含引號的字串存為 JS 變數
// 在 JS 中定義：
// const code = "Api.when('auth', api => {"
// 在 el3 中引用變數：
span => *text=code

// ✓ 正確：或者使用 | 符號
// 在 el3 中：
span
  | Api.when('auth', api => {
// 輸出：
<span>Api.when('auth', api => {</span>
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

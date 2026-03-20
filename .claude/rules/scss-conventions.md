---
paths:
  - "frontend/src/scss/**"
---

# SCSS 開發規範

## ⚠️ SCSS 審查順序

Review SCSS 時，先讀對應的 el3 模板，再按此順序檢查：

1. **結構對應**：SCSS 巢狀是否與 el3 模板的父子關係一致
2. **屬性順序**：每個選擇器內的屬性是否符合撰寫順序規則
3. **其他規則**：RWD 三斷點、顏色格式、Mixin 使用等

---

## RWD 三斷點規則

使用 `@include range-width` 切版時，**必須列出三個斷點**，即使部分斷點設定相同：

```scss
// ✓ 正確：三個斷點都列出
@include range-width($admin-breakpoint-tablet) {
  display: inline-block;
}
@include range-width($admin-breakpoint-mobile, $admin-breakpoint-tablet) {
  display: inline-block;
}
@include range-width(0, $admin-breakpoint-mobile) {
  display: none;
}

// ✗ 錯誤：省略設定相同的斷點
@include range-width($admin-breakpoint-tablet) {
  display: inline-block;
}
@include range-width(0, $admin-breakpoint-mobile) {
  display: none;
}
```

## Display 偏好

所有元素預設使用 `display: inline-block`，避免使用 `display: block`：

```scss
// ✗ 避免
display: block;

// ✓ 優先
display: inline-block;
// 需要滿版時加上 width: 100%
```

需要排版時，使用 `inline-flex` / `inline-grid` 取代 `flex` / `grid`：

```scss
// ✗ 避免
display: flex;
display: grid;
@include prefix(display, grid);

// ✓ 優先
display: inline-flex;
width: 100%;

@include prefix(display, inline-grid);
width: 100%;
```

**包含 `img`、`svg`、`span` 等行內元素**，一律加上 `display: inline-block`：

```scss
img {
  display: inline-block;

  width: 100%;
  height: 100%;

  object-fit: cover;
}

svg {
  display: inline-block;

  width: 20px;
  height: 20px;
}
```

## Flex 完整宣告

若是 inline-flex，習慣把 `flex-direction`、`align-items`、`justify-content` 一起補上：

```scss
// ✓ 優先
display: inline-flex;
flex-direction: row;
align-items: stretch;
justify-content: flex-start;

width: 100%;
```

## 顏色格式

**優先使用 `rgba()` 格式**，而非 hex 色碼：

```scss
// ✗ 避免
color: #f8f8f2;

// ✓ 優先
color: rgba(248, 248, 242, 1);
```

## 數字習慣

`0.` 開頭省略 `0`：

```scss
// ✗ 避免
color: rgba(0, 0, 0, 0.5);

// ✓ 優先
color: rgba(0, 0, 0, .5);
```

## 偽元素單冒號

```scss
// ✗ 避免
&::before { }

// ✓ 優先
&:before { }
```

## 多選擇器不換行

多個選擇器寫在同一行，不要每個選擇器換行：

```scss
// ✗ 避免
.a,
.b,
.c {
  color: red;
}

// ✓ 優先
.a, .b, .c {
  color: red;
}
```

## 屬性撰寫順序

```scss
.selector {
  // 1. Flex
  flex-grow:
  flex-shrink:
  gap:

  // 2. 定位
  position:
  z-index:

  // 3. 位置（position: absolute 時）
  top:
  left:
  right:
  bottom:

  // 4. 盒模型
  display:

  // 5. Flex 方向（display: inline-flex 時）
  flex-direction:
  align-items:
  justify-content:

  // 6. 寬高
  width:
  height:

  // 7. 間距
  margin:
  padding:

  // 8. 文字
  font-size:
  font-weight:
  text-align:
  line-height:
  font-family:

  // 9. 顏色
  color:
  background:

  // 10. 邊框
  border:
  outline:
  cursor:

  // 11. Mixin（放最後）
  @include border-radius();
  @include box-shadow();
  @include opacity();
  @include transition();
}
```

## iOS 色彩：使用 CSS 自訂屬性

iOS UIColor 已透過 `Core.scss` 定義為 CSS 自訂屬性，會自動切換 Light/Dark Mode。

**直接使用 `var(--ui-color-iOS-*)` 取代 `ios-color()` 函數**，不需要 `@include dark` 對應：

```scss
// ✗ 舊寫法：需要 @include dark 手動切換
color: ios-color(secondaryLabel);
@include dark {
  color: ios-color(secondaryLabel, dark);
}

// ✓ 新寫法：CSS 變數自動切換 light/dark
color: var(--ui-color-iOS-secondaryLabel);
```

**混合情境**：當 `@include dark` 區塊同時包含 iOS 色彩與其他 dark 屬性時，僅移除 iOS 色彩部分，保留其他屬性：

```scss
// ✓ 正確：iOS 色彩用 var()，非 iOS 屬性保留 @include dark
color: var(--ui-color-iOS-secondaryLabel);
background-color: rgba(0, 0, 0, .05);
@include dark {
  background-color: rgba(255, 255, 255, .1);
}
```

## Dark Mode 分組規則

有 `@include dark` 對應的屬性，**必須緊貼在 `@include dark` 前面**，不被其他無關屬性隔開：

```scss
// ✗ 錯誤：light 屬性和 @include dark 被其他屬性隔開
background-color: rgba(0, 0, 0, .05);
border: none;

@include border-radius(6px);
@include transition(all 150ms);

@include dark {
  background-color: rgba(255, 255, 255, .1);
}

// ✓ 正確：有 dark 對應的屬性一起放在 @include dark 前
border: none;

@include border-radius(6px);
@include transition(all 150ms);

background-color: rgba(0, 0, 0, .05);
@include dark {
  background-color: rgba(255, 255, 255, .1);
}
```

## Mixin 優先

**請優先使用 @oawu/scss mixin 而非原生 CSS 屬性**。大部分 mixin 已包含在 `@import "Lalilo";` 中。

### 常用 Mixin

| Mixin | 範例 | 額外 Import |
|-------|------|------------|
| `@include opacity($val)` | `@include opacity(.5)` | 否 |
| `@include transition(...)` | `@include transition(all .2s ease)` | 否 |
| `@include border-radius($val)` | `@include border-radius(10px)` | 否 |
| `@include box-shadow(...)` | `@include box-shadow(0 2px 8px rgba(0,0,0,.1))` | 否 |
| `@include user-select($val)` | `@include user-select(none)` | 否 |
| `@include transform(...)` | `@include transform(scale(.95))` | 否 |
| `@include animation(...)` | `@include animation(name 5s linear infinite)` | 否 |
| `@include filter(...)` | `@include filter(blur(10px))` | 否 |
| `@include backdrop-filter(...)` | `@include backdrop-filter(blur(24px) saturate(180%))` | 否 |
| `@include overflow-docx3()` | `@include overflow-docx3()` | 否 |
| `@include text-more($line)` | `@include text-more(2)` | 否 |
| `@include appearance($val)` | `@include appearance(none)` | `@import "@/CSS3/Appearance"` |
| `@include input-placeholder {}` | `@include input-placeholder { color: #999; }` | 否 |
| `@include dark {}` | `@include dark { color: #999; }` | 否 |
| `@include range-width(...) {}` | `@include range-width(0, 100px) { ... }` | 否 |
| `@include hover {}` | `@include hover { cursor: pointer; &:hover { ... } }` | 否 |
| `@include keyframes(...) {}` | `@include keyframes(name) { to { ... } }` | 否 |

### Hover 效果

使用 `@include hover {}` 確保只在非手機版才有 hover 效果：

```scss
// ✗ 錯誤：直接使用 &:hover
.button {
  &:hover {
    background-color: var(--color-primary-hover);
  }
}

// ✓ 正確：使用 @include hover 包裹
.button {
  @include hover {
    cursor: pointer;

    &:hover {
      background-color: var(--color-primary-hover);
    }
  }
}
```

### 可點擊元素

可點擊的交互元素需加上 `@include user-select(none)`（放在 `@include hover` 外面）。

**注意**：Admin 頁面已在 `Admin.scss` 全域設定 `* { @include user-select(none); }`，因此 Admin 底下的元素不需要重複宣告。

```scss
.clickable-element {
  @include user-select(none);

  @include hover {
    cursor: pointer;

    &:hover {
      // hover 效果
    }
  }
}
```

### Class 命名與巢狀結構

**SCSS 巢狀必須對應 HTML 結構**——父子關係的選擇器一律巢狀，不可攤平到同層：

```scss
// ✗ 錯誤：.album 是 .albums 的子元素，卻放在同層
main {
  .albums { ... }
  .album { ... }
}

// ✓ 正確：巢狀對應 HTML 父子關係
main {
  .albums {
    .album { ... }
  }
}
```

頁面已有 `.page-xxx` 或 `#ComponentName` 隔離時，子元素精簡命名：

```scss
// ✗ 避免：冗長前綴 + 平層
.page-profile {
  .card-cover { ... }
  .card-info { ... }
  .card-name { ... }
}

// ✓ 正確：精簡命名 + 巢狀對應 HTML
.page-profile {
  .card {
    .cover { ... }
    .info { ... }
    .name { ... }
  }
}
```

**末端元素**：若 HTML tag 本身在同層內可區分，省略 class，直接用 tag 選擇器：

```scss
// ✓ 正確：span 和 button 不同 tag，不需要 class
.meta {
  span { flex-grow: 1; }
  button { ... }
}
```

```
// el3 對應
.meta
  span
    | {{ item.photoCount }} 張照片
  button => @click.stop=onRemoveItem(item)
    Icon => name=trash   stroke-width=1.8
```

**例外**：同層有多個相同 tag 時，仍需 class 區分：

```scss
// 兩個 span 需要 class 區分
.meta {
  .access { ... }
  .count { ... }
}
```

### 避免重複父層樣式

寫子選擇器前，先確認父層是否已定義相同屬性。只覆寫需要改變的屬性：

```scss
// 父層已定義
button {
  svg {
    width: 18px;
    height: 18px;
    color: var(--ui-color-iOS-label);
  }
}

// ✗ 錯誤：重複寫 width、height
.locate svg {
  width: 18px;
  height: 18px;
  color: var(--ui-color-iOS-link);
}

// ✓ 正確：只覆寫不同的屬性
.locate svg {
  color: var(--ui-color-iOS-link);
}
```

### 組件 SCSS 引入方式

組件 SCSS 應在 Model 的 scss 陣列中引入，而非在 SCSS 檔案中直接 import：

```scss
// ✗ 錯誤：在 SCSS 中直接 import 組件
@import "../layout/Admin";

// ✓ 正確：SCSS 使用標準結構
@use "sass:math";
@import "@/CSS3/Appearance";
@import "/_01-Var";
@import "/_02-Lib";
@import "Lalilo";
```

```javascript
// ✓ 正確：組件在 Model 的 scss 陣列引入
scss: [
  'layout/Admin.scss',
  'test/xxx.scss',
],
```

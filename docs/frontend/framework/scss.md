# SCSS 開發指南

本文件說明 Lalilo 專案中 SCSS 的開發規範與使用方式。

---

## 目錄結構

```
src/scss/
├── _01-Var.scss          # 變數定義（Partial）
├── _02-Lib.scss          # 共用函數/Mixin（Partial）
├── _01-Core/                # 核心樣式
│   ├── 01-Elements.scss
│   └── 02-Vars.scss
├── index.scss            # 首頁樣式
├── about.scss            # 關於頁樣式
└── components/           # 元件樣式
    └── header.scss
```

---

## 檔案命名規則

| 格式 | 說明 | 編譯行為 |
|------|------|----------|
| `*.scss` | 主要樣式檔 | 會被編譯成 CSS |
| `_*.scss` | Partial 檔案 | 不會單獨編譯，供 `@import` 使用 |

---

## @import 路徑規則

### 相對路徑

```scss
// src/scss/page/a.scss
@import "./_local-var";     // → src/scss/page/_local-var.scss
@import "../_01-Var";       // → src/scss/_01-Var.scss
```

### 根目錄路徑（/ 開頭）

```scss
// src/scss/page/a.scss
@import "/_01-Var";         // → src/scss/_01-Var.scss
@import "/_02-Lib";         // → src/scss/_02-Lib.scss
@import "/_01-Core/01-Elements"; // → src/scss/_01-Core/01-Elements.scss
```

### @oawu/scss 內建模組

```scss
@import "@/CSS3/Font";      // @oawu/scss 內建的 CSS3 模組
@import "@/CSS3/Border";
@import "Lalilo";           // @oawu/scss 內建的快取模組
```

---

## CSS 輸出位置

SCSS 編譯後的 CSS 檔案輸出至 `cmd/node_modules/_/css/`：

| SCSS 來源 | CSS 輸出 |
|-----------|----------|
| `src/scss/index.scss` | `cmd/node_modules/_/css/index.css` |
| `src/scss/page/a.scss` | `cmd/node_modules/_/css/page/a.css` |

---

## 在 Model 中載入

```javascript
// src/model/index.js
module.exports = ({ Asset }) => ({
  asset: () => Asset()
    .scss('_01-Core/01-Elements')   // 核心樣式
    .scss('index'),              // 頁面樣式
})
```

支援多種寫法：

```javascript
asset.scss('index')          // → src/scss/index.scss
asset.scss('index.scss')     // → src/scss/index.scss
asset.scss('index.css')      // → src/scss/index.scss
```

---

## 變數檔案範例

```scss
// src/scss/_01-Var.scss

// 顏色
$primary: #007bff;
$secondary: #6c757d;
$success: #28a745;
$danger: #dc3545;

// 字型
$font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
$font-size-base: 16px;

// 間距
$spacing-unit: 8px;
$spacing-sm: $spacing-unit;
$spacing-md: $spacing-unit * 2;
$spacing-lg: $spacing-unit * 3;

// 斷點
$breakpoint-sm: 576px;
$breakpoint-md: 768px;
$breakpoint-lg: 992px;
$breakpoint-xl: 1200px;
```

---

## Mixin 範例

```scss
// src/scss/_02-Lib.scss

// RWD Mixin
@mixin mobile {
  @media (max-width: $breakpoint-sm) {
    @content;
  }
}

@mixin tablet {
  @media (min-width: $breakpoint-sm) and (max-width: $breakpoint-lg) {
    @content;
  }
}

@mixin desktop {
  @media (min-width: $breakpoint-lg) {
    @content;
  }
}

// Flexbox
@mixin flex-center {
  display: flex;
  justify-content: center;
  align-items: center;
}

// 使用
.container {
  @include flex-center;

  @include mobile {
    flex-direction: column;
  }
}
```

---

## 頁面樣式範例

```scss
// src/scss/index.scss
@import "/_01-Var";
@import "/_02-Lib";

body {
  font-family: $font-family;
  font-size: $font-size-base;
  color: $secondary;
  background: #f5f5f5;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: $spacing-md;

  @include mobile {
    padding: $spacing-sm;
  }
}

.header {
  @include flex-center;
  height: 60px;
  background: $primary;
  color: white;
}
```

---

## 編譯選項

### Serve 模式

- 即時編譯，修改後自動重新編譯
- 不壓縮（除非加上 `--minify`）

### Build 模式

```bash
npm run build -- --minify    # 壓縮 CSS
npm run build --no-minify    # 不壓縮
```

壓縮使用 `lightningcss`，會：
- 移除註解
- 壓縮空白
- 合併相同選擇器
- 自動加上瀏覽器前綴

---

## 注意事項

1. **Partial 命名**：以 `_` 開頭的檔案不會單獨編譯
2. **根目錄路徑**：使用 `/` 開頭可從任何位置引用 scss 根目錄的檔案
3. **編譯輸出**：CSS 輸出到 `cmd/node_modules/_/css/`，不在 `src/` 內
4. **熱重載**：修改 SCSS 檔案會自動重新編譯並觸發瀏覽器重載

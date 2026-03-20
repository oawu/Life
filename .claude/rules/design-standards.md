# 設計規範

## Apple Human Interface Guidelines（iOS 18 / macOS Sequoia）

- 配色：iOS UIColor 系統色彩（定義於 `_01-Var.scss`）
- 支援 Light / Dark Mode
- 主色調：`#007AFF`（Light）/ `#0A84FF`（Dark）

## 現代視覺風格

- **毛玻璃效果**：`backdrop-filter: blur(24px) saturate(180%)`
- **漸層背景**：微妙的 linear-gradient
- **柔和陰影**：多層陰影營造深度感
- **大圓角**：8px / 12px / 16px / 20px

## RWD 響應式斷點

| 裝置 | 寬度 | 佈局 |
|------|------|------|
| 桌面 | >1024px | 固定側邊欄 |
| 平板 | 768-1024px | 抽屜式側邊欄 |
| 手機 | <768px | 抽屜式側邊欄 + 底部 Tab Bar |

## 互動元素

- 所有可點擊元素必須加上 `cursor: pointer`
- hover 狀態需有視覺回饋（顏色、陰影、位移）
- 過渡動畫使用 `cubic-bezier(0.32, 0.72, 0, 1)` Apple 標準曲線
- 點擊回饋使用 `scale(0.95)` 縮放效果

## 圖示規範

- 使用 SVG 圖示，禁止使用 emoji 作為 UI 圖示
- 統一使用 Heroicons 風格（stroke, viewBox 24x24）

## 文字選取

- 預設禁止文字選取（`user-select: none`）
- 需要選取時使用 `.select-text` 類別
- `input`、`textarea`、`[contenteditable]` 自動允許選取

## 後台子頁面 Header 設計

後台子頁面統一採用以下 header 結構：
```
[漢堡選單] [Logo + 名稱] | [返回按鈕] [頁面標題]
                             ↑ 分隔線對齊側邊欄邊界
```
- **Logo 區域**：寬度對齊側邊欄 `calc($sidebar-width - 20px - 12px - 1px)`
- **分隔線**：1px 寬，高度 28px，對齊側邊欄右邊界
- **平板/手機**：隱藏分隔線，Logo 區域自適應寬度

## iOS UIColor 色彩

iOS 系統色彩已透過 `Core.scss` 定義為 CSS 自訂屬性（`--ui-color-iOS-*`），會自動切換 Light/Dark Mode。

```scss
// 直接使用 CSS 自訂屬性，不需要 @include dark
.element {
  color: var(--ui-color-iOS-label);
  background: var(--ui-color-iOS-systemBackground);
}
```

### 常用色彩

| 名稱 | 用途 |
|------|------|
| `label` | 主要文字 |
| `secondaryLabel` | 次要文字 |
| `systemBackground` | 背景色 |
| `systemGroupedBackground` | 分組背景 |
| `systemBlue` | 強調色/連結 |
| `systemRed` | 錯誤/警告 |
| `systemGreen` | 成功 |
| `separator` | 分隔線 |

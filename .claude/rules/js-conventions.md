# JavaScript 開發規範

## 圖示：使用 Icon 組件

所有 SVG 圖示必須註冊到 `Icon.js`（`frontend/src/js/component/Icon.js`），在 template 中使用 `Icon` 組件，禁止 inline SVG：

```javascript
// ✗ 錯誤：inline SVG
// el3: svg => viewBox=0 0 24 24 ...

// ✓ 正確：註冊到 Icon.js，用 Icon 組件
// Icon.js 中新增：
const icons = {
  // ===== 分類名稱 =====
  myIcon: 'M12 4.5v15m7.5-7.5h-15',  // 簡單 path
  myIcon: `<g ...>...</g>`,            // 複雜圖示（含 < 字元）
}
// el3: Icon => name=myIcon
```

**viewBox 適配**：Icon 組件固定使用 `viewBox="0 0 24 24"`。若來源 SVG 的 viewBox 不同，用 `<g transform="translate(...) scale(...)">` 包裹以適配 24×24。

## 頁面跳轉：使用 PageRedirect

需要帶訊息的頁面跳轉（登出、錯誤導向、登入成功等）一律使用 `PageRedirect`，禁止直接 `window.location.href`：

```javascript
// ✗ 錯誤：直接使用 window.location.href
window.location.href = '/auth/login'
window.location.href = '/admin.html'

// ✓ 正確：純導航
PageRedirect.to('admin.html')
PageRedirect.to('admin/folder.html?id=3')

// ✓ 正確：外部跳轉
PageRedirect.to('https://accounts.google.com/...')

// ✓ 正確：帶訊息跳轉
PageRedirect.error('auth/login', '登入已過期，請重新登入')
PageRedirect.success('admin', '登入成功')
```

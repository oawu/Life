# 更新文件並提交

執行 save + commit：先更新文件，再提交 Git 變更。

## 步驟

### 第一階段：更新文件 (Save)

1. 回顧本次對話中所做的程式碼變更
2. 判斷哪些變更涉及架構、規範、API、元件等需要記錄的內容
3. 根據路由表找到對應的目標文件並更新
4. 若無對應區塊，在適當位置新增

**更新原則：**
- 只記錄**架構性**或**規範性**的變更
- 不記錄單純的 bug fix 或小調整
- 使用簡潔的描述，避免冗長
- 保持與現有文件風格一致

**判斷更新位置：**

| 變更類型 | 目標文件 |
|----------|----------|
| 新增/修改頁面功能 | docs/frontend/pages.md |
| 新增/修改通用組件 | docs/frontend/components.md |
| 新增/修改 UI / Modal 組件 | docs/frontend/ui.md |
| 新增/修改 Helper | docs/frontend/helpers.md |
| El3 新規則/陷阱 | .claude/rules/el3-template.md |
| SCSS 新規則 | .claude/rules/scss-conventions.md |
| JS 新規則 | .claude/rules/js-conventions.md |
| 設計規範變更 | .claude/rules/design-standards.md |
| 新頁面/組件加入清單 | CLAUDE.md（已完成功能表格） |
| 架構性變更 | CLAUDE.md |
| 新增/修改 Model、Lib | docs/backend/overview.md + CLAUDE.md |
| 新增/修改 API 路由 | docs/backend/api-routes.md |
| 新增/修改 Migration | docs/backend/overview.md + docs/architecture.md |
| PHP 新規則 | .claude/rules/php-conventions.md |
| 後端架構變更 | docs/backend/overview.md + CLAUDE.md |
| Worker 架構/模組變更 | docs/worker/overview.md |
| iOS 新增/修改頁面或元件 | CLAUDE.md（已完成功能） |
| iOS 架構性變更 | CLAUDE.md + docs/architecture.md |
| iOS 資料模型/Services 變更 | docs/ios/data-models.md + docs/ios/overview.md |
| iOS 功能模組/操作流程變更 | docs/ios/features.md |
| iOS View 新增/修改/參數變更 | docs/ios/views.md |

### 第二階段：Git Commit

1. 執行 `git status` 和 `git diff` 查看變更
2. 分析變更內容，**逐一辨識**每項獨立功能
3. **依功能拆分 commit**：每項獨立功能各自 stage 並 commit，不混雜
4. 只有功能之間有**嚴重相依性**時（如 Migration + 對應 Model），才合併為同一個 commit
5. 撰寫繁體中文 commit 訊息（不要加 Co-Authored-By）

## Commit 格式

```
<type>: <描述>
```

## Type 對照表

| Type | 使用時機 |
|------|----------|
| feat | 新功能 |
| fix | 修復 bug |
| docs | 文件變更 |
| style | 程式碼風格（不影響功能） |
| refactor | 重構（不是新功能也不是修 bug） |
| perf | 效能優化 |
| test | 測試相關 |
| chore | 建置、工具、設定變更 |

## 注意事項

- 訊息必須使用**台灣繁體中文**
- 不要標註是由 AI 產生
- 描述要簡潔明瞭，說明「做了什麼」
- 若文件無需更新，直接進行 commit

# Git 開發規範

## Merge 必須使用 `--no-ff`

所有 merge 一律使用 `--no-ff`（no fast-forward），保留完整分支歷史：

```bash
# ✓ 正確
git merge --no-ff feat/my-feature

# ✗ 禁止：fast-forward merge 會丟失分支資訊
git merge feat/my-feature
```

這是鐵則，無例外。

## Commit 必須按功能拆分

每個 commit 只包含一項獨立功能的變更。累積多項功能時，依功能分組各自 commit：

```bash
# ✓ 正確：拆分為獨立 commit
git add backend/Migration/002-* backend/App/Model/Album.php
git commit -m "feat: 建立 Album 資料表"

git add backend/App/Controller/Api/Auth.php backend/Router/Main.php
git commit -m "feat: 實作 Google 登入 API"

# ✗ 錯誤：不相關的功能混在同一個 commit
git add .
git commit -m "feat: 建立 Album 資料表、實作登入 API、修正樣式"
```

**例外**：功能之間有嚴重相依性（如 Migration + 對應 Model）才放同一個 commit。

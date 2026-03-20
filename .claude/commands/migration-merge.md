# Migration 整併

將指定版本起的所有 Migration 檔案整併，同一資料表的 create + alter 合併為單一 create。

**參數**：`$ARGUMENTS`（起始版本號，如 `3`）

---

## 前置檢查

1. 參數必須為正整數，否則提示用法：`/migration-merge <起始版本號>`
2. 讀取 `backend/Migration/` 下所有檔案，列出**起始版本（含）以後**的檔案清單
3. 若無符合的檔案，提示「沒有需要整併的 Migration」

---

## 步驟

### 1. 盤點

讀取所有目標 Migration 檔案，建立清單：

| 版本 | 檔名 | 資料表 | 操作類型 |
|------|------|--------|----------|

操作類型從檔名解析：
- `create XXX` → create
- `alter XXX add YYY` → alter-add
- `alter XXX drop YYY` → alter-drop
- `alter XXX change YYY` → alter-change
- `drop XXX` → drop

### 2. 分組

按**資料表名稱**分組，每組內按版本號排序。

### 3. 合併邏輯

對每個資料表群組：

#### CREATE + ALTER ADD
將 ALTER ADD 的欄位插入 CREATE TABLE 語句中：
- 解析 `AFTER \`欄位名\`` 確定插入位置
- 若無 AFTER，插在 `updateAt` 之前
- 若 ALTER ADD 包含 KEY/INDEX，也加入 CREATE TABLE

#### CREATE + ALTER DROP
從 CREATE TABLE 中移除該欄位，同時移除只引用該欄位的 KEY/INDEX。

#### CREATE + ALTER CHANGE
在 CREATE TABLE 中找到原欄位名，替換為新的欄位定義。

#### CREATE + DROP
整個資料表從結果中移除（不產生任何 Migration）。

#### 只有 ALTER（無 CREATE）
該資料表的 create 在起始版本之前，無法合併進 create。保留為一個合併的 alter Migration（多條 ALTER 合併為陣列）。

### 4. 產生新檔案

- 從起始版本號開始重新編號（3 位數）
- 檔名格式：`{版本號}-create {TableName}.php`（或 `alter`）
- 每個檔案保留原始 Migration 的模板註解區塊（從 `# 欄位格式` 到檔案結尾，取第一個 create 檔案的即可）
- `at` 使用當前時間
- `down` 為 `DROP TABLE IF EXISTS \`{TableName}\`;`

### 5. 清理

- 刪除起始版本（含）以後的**所有舊 Migration 檔案**
- 寫入新的合併後檔案

---

## 輸出格式

整併前後對照表：

```
整併前：
  003-create Book.php
  004-alter Book add author.php
  005-alter Book add price.php
  006-create Author.php
  007-alter Book add isbn.php
  008-alter Author add name.php

整併後：
  003-create Book.php      ← 合併 003, 004, 005, 007
  004-create Author.php    ← 合併 006, 008
```

---

## 安全措施

- 整併前先向用戶確認操作（顯示整併前後對照表）
- 起始版本之前的檔案**絕對不動**
- 整併完成後，提醒用戶需要重置 Migration：
  ```
  docker exec php zsh -c "cd ~/Workspace/32_Life/backend && php Maple.php migration -R && php Maple.php migration"
  ```

---

## 注意事項

- `up` 可能是字串或字串陣列，解析時都要處理
- ALTER 語句可能一個檔案包含多條（陣列形式）
- 合併後的 CREATE TABLE 欄位順序要正確（依 AFTER 定位）
- 合併後的 CREATE TABLE 格式要與現有 Migration 風格一致（對齊、縮排）
- KEY/INDEX 定義放在欄位之後、`PRIMARY KEY` 之前或之後（依現有慣例）

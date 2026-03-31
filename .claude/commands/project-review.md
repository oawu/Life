# 專案開發報告

分析 Git commit 歷史，產生專案開發狀況報告並寫入 `docs/report/<today>.md`（如 `2026-02-23.md`）。同一天執行則覆寫。

## 步驟

### 1. 收集 Git 資料

執行以下 git 指令收集資料：

```bash
# 總 commit 數
git log --oneline --all | wc -l

# 每日 commit 數
git log --format="%ad" --date=short --all | sort | uniq -c | sort -k2

# 作者統計
git shortlog -sn --all

# commit type 分布（取 : 前的 type）
git log --format="%s" --all | sed 's/:.*//' | sort | uniq -c | sort -rn

# 完整 log（含日期與訊息）
git log --format="%h %ad %s" --date=short --all

# 開發起迄日期
git log --format="%ad" --date=short --all | sort | head -1
git log --format="%ad" --date=short --all | sort | tail -1

# 每週 commit 數（週趨勢）
git log --format="%ad" --date=short --all | sort | awk '{print $1}' | while read d; do date -j -f "%Y-%m-%d" "$d" "+%Y-W%V"; done | sort | uniq -c

# 最近 7 天 commit log
git log --format="%h %ad %s" --date=short --since="7 days ago"

# 熱點檔案（最常被修改的前 15 個檔案）
git log --name-only --pretty=format: --all | sort | uniq -c | sort -rn | head -15

# 程式碼統計（各類型檔案數與行數）
find frontend/src -name "*.js" | xargs wc -l 2>/dev/null | tail -1
find frontend/src -name "*.scss" | xargs wc -l 2>/dev/null | tail -1
find frontend/src -name "*.el3" | xargs wc -l 2>/dev/null | tail -1
find backend/App -name "*.php" | xargs wc -l 2>/dev/null | tail -1
find frontend/src -name "*.js" | wc -l
find frontend/src -name "*.scss" | wc -l
find frontend/src -name "*.el3" | wc -l
find backend/App -name "*.php" | wc -l

# 前端 JS 子目錄分類統計（前後端分析用）
for dir in Admin App layout ui helper component config modal auth; do
  echo "=== frontend/src/js/$dir ==="
  find "frontend/src/js/$dir" -name "*.js" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1
  find "frontend/src/js/$dir" -name "*.js" 2>/dev/null | wc -l
done

# 前端 SCSS 子目錄分類統計
for dir in layout Admin App ui component modal auth; do
  echo "=== frontend/src/scss/$dir ==="
  find "frontend/src/scss/$dir" -name "*.scss" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1
  find "frontend/src/scss/$dir" -name "*.scss" 2>/dev/null | wc -l
done

# 後端各模組分類統計
for dir in Controller Model Middleware Lib View; do
  echo "=== backend/App/$dir ==="
  find "backend/App/$dir" -name "*.php" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1
  find "backend/App/$dir" -name "*.php" 2>/dev/null | wc -l
done

# 後端其他目錄
find backend/Router -name "*.php" | xargs wc -l 2>/dev/null | tail -1
find backend/Config -name "*.php" | xargs wc -l 2>/dev/null | tail -1
find backend/Migration -name "*.php" | xargs wc -l 2>/dev/null | tail -1

# Worker 統計
find worker/src -name "*.js" | xargs wc -l 2>/dev/null | tail -1
find worker/src -name "*.js" | wc -l

# iOS 統計
find ios -name "*.swift" | xargs wc -l 2>/dev/null | tail -1
find ios -name "*.swift" | wc -l

# iOS 各模組分類統計
for dir in Life/Views Life/Models Life/Services Life/Utils Shared LifeWatch LifeWidget; do
  echo "=== ios/$dir ==="
  find "ios/$dir" -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1
  find "ios/$dir" -name "*.swift" 2>/dev/null | wc -l
done

# 前後端最大檔案 Top 5（複雜度指標）
echo "=== 前端 JS Top 5 ==="
find frontend/src/js -name "*.js" | xargs wc -l 2>/dev/null | sort -rn | head -6
echo "=== 後端 PHP Top 5 ==="
find backend/App -name "*.php" | xargs wc -l 2>/dev/null | sort -rn | head -6
echo "=== iOS Swift Top 5 ==="
find ios -name "*.swift" | xargs wc -l 2>/dev/null | sort -rn | head -6

# HTML 與 el3
find frontend/src/html -name "*.html" | xargs wc -l 2>/dev/null | tail -1
find frontend/src/tmpl -name "*.el3" | xargs wc -l 2>/dev/null | tail -1
```

### 2. 讀取上一份報告

檢查 `docs/report/` 目錄下是否有**早於今天**的報告檔案。若有，讀取最近一份作為比對基準，用於產生「與上次報告的差異」區塊。

### 3. 分析與撰寫報告

根據收集的資料，依以下結構撰寫報告。**每個區塊都必須包含**：

---

#### 近期焦點（最近 7 天）

放在報告最前面，讓讀者快速掌握當下進度：

- 本週完成的主要功能 / 重構 / 修復（從最近 7 天的 commit 歸納）
- 用 3-5 個條列摘要，不需要太細節
- 標註 commit 數量

---

#### 與上次報告的差異

若有上一份報告可比對：

- commit 數變化（從 N → M，新增 X 個）
- 本期新增的 commit type 分布
- 本期新完成的功能（API、組件、頁面）
- 本期新增的檔案或重大變更

若無上一份報告，註明「首次產生報告，無歷史比對」。

---

#### 基本資訊
- 專案名稱、開發期間、總 commit 數、開發者、分支策略

#### 程式碼規模

統計各類型檔案的數量與總行數，用表格呈現：

```
| 類型 | 檔案數 | 總行數 |
|------|--------|--------|
| JS   | xx     | x,xxx  |
| SCSS | xx     | x,xxx  |
| el3  | xx     | x,xxx  |
| PHP   | xx     | x,xxx  |
| Swift | xx     | x,xxx  |
```

#### 前後端程式碼分析

根據收集的子目錄統計資料，分析前後端程式碼的比重、結構與複雜度：

**整體比重**：前端（frontend/src 全部）vs 後端（backend/App + Router + Config + Migration）的檔案數、行數、佔比表格。

**邏輯層比重**：排除 SCSS 樣式後，僅計算邏輯程式碼（前端 JS + el3 vs 後端 PHP）的比例，分析前後端實際邏輯量的對比。

**前端程式碼結構**：JS 按子目錄分類（UI、頁面、Helper、Layout、其他），列出各模組的檔案數、行數、佔比、說明。列出 Top 5 最大/最複雜檔案及其複雜度來源。

**後端程式碼結構**：PHP 按模組分類（Controller、Lib、Migration、Config、Model、View、Middleware），列出各模組的檔案數、行數、佔比。列出 Top 5 最大/最複雜檔案及其複雜度來源。

**複雜度評估**：用表格比較前後端的「平均行數/檔」「最大檔案」「互動模式數」「非同步複雜度」「狀態管理」等指標，並給出一段總結性分析。

#### Commit 類型分布
- 統計各 type（feat、refactor、fix、docs、style、chore、perf、merge）的數量與佔比
- 分析 feat vs refactor 比例，解讀開發節奏

#### 每日開發節奏
- 用 ASCII 柱狀圖視覺化每日 commit 數
- 標註開發高峰與休息日
- 歸納出幾個開發高峰期及其主題

#### 週趨勢

用 ASCII 柱狀圖呈現每週 commit 數，觀察開發節奏是加速、穩定還是趨緩。

#### 開發時間軸
- 依時間順序，將 commit 歸納為幾個開發階段（Phase）
- 每個階段標註起迄日期、主題、完成的主要工作項目
- 階段劃分依據：功能主題的集中度與時間間隔

#### 熱點檔案

列出被修改最頻繁的 Top 10 檔案，用表格呈現：

```
| 排名 | 檔案 | 修改次數 | 說明 |
|------|------|----------|------|
| 1    | ...  | xx       | ...  |
```

分析熱點集中的原因（核心組件、頻繁重構、架構演進等）。

#### 已完成功能清單
- 參考 CLAUDE.md 的「已完成功能」區塊
- 分前端（頁面 + 組件）與後端（API + CLI + Model + Lib）列出

#### 待開發功能
- 參考 CLAUDE.md 的「待開發功能」區塊
- 標註前端/後端各自的狀態

#### 技術亮點
- 挑選 2-3 個值得注意的技術決策或架構特色

#### 觀察
- 開發速度、品質意識、文件同步率、專案完成度等綜合評價

### 4. 寫入報告

確保 `docs/report/` 目錄存在，將報告寫入 `docs/report/YYYY-MM-DD.md`（當天日期），格式：

- 開頭加上產生日期（`> 產生日期：YYYY-MM-DD`）
- 使用 Markdown 表格、標題、條列，保持易讀
- ASCII 柱狀圖放在 code block 中
- 同一天執行則**覆寫**該日檔案

### 5. 更新摘要（docs/report/summary.md）

報告寫完後，根據最新資料**覆寫** `docs/report/summary.md`。這份摘要供管理者快速掌握專案現況，結構如下：

```markdown
# Life 專案摘要

> 最後更新：YYYY/MM/DD

## 專案概況
表格：專案名稱、開發期間、總 commit 數、開發者、專案完成度

## 目前狀態
一句話描述當前階段 + 最近動態（3-5 條列，從最近 7 天歸納）

## Commit 類型分布
完整 type 分布表（含數量、佔比、說明），一句話解讀

## 開發時間軸
各 Phase 用 ### 標題 + 一行條列描述，不需要細節

## 已完成功能清單
分「### 前端」與「### 後端」，各用條列列出（不用表格）

## 待開發
純條列，標註前端/後端

## 技術亮點
2-3 個條列

## 觀察
3-4 個條列，涵蓋開發速度、品質、文件、完成度
```

**原則：**
- 整份摘要控制在 **100 行以內**，重點扼要
- 數據從剛產生的報告中取用，不需要重新計算
- 「最近動態」與報告的「近期焦點」內容一致，但更精簡
- 「專案完成度」根據已完成 vs 待開發功能比例估算

## 注意事項

- 報告內容基於 git log 客觀資料，輔以 CLAUDE.md 的功能清單
- 階段劃分和觀察需根據實際 commit 內容判斷，不要套用固定模板
- 日期使用 YYYY/MM/DD 格式
- 保持繁體中文
- 熱點檔案排除 `docs/`、`.claude/`、`package-lock.json` 等非程式碼檔案
- 程式碼統計只計算原始碼（`frontend/src/` + `backend/App/`），不含 `dist/`、`node_modules/`、框架核心 `System/`

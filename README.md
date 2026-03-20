# Life

Life 是一個 Web 應用服務。

## 技術棧

| 層級 | 技術 |
|------|------|
| 前端框架 | Lalilo（靜態檔案產生器） |
| 前端 UI | Vue 3 CDN（Composition API） |
| 模板引擎 | El3（縮排式 Vue template 語法） |
| 樣式 | SCSS + @oawu/scss |
| 後端框架 | Maple 9（PHP 7.4，MVC + Active Record ORM） |
| Worker | Node.js 18+（pm2 常駐服務） |
| 資料庫 | MySQL（InnoDB, utf8mb4） |
| 容器 | Docker |

## 專案結構

```
life/
├── frontend/    # 前端（Lalilo + Vue 3 + El3 + SCSS）
├── backend/     # 後端（Maple 9 PHP）
├── worker/      # Worker（Node.js + pm2）
└── docs/        # 專案文件
```

## 環境啟動

（待設定後補齊）

## 文件

| 文件 | 說明 |
|------|------|
| [CLAUDE.md](CLAUDE.md) | 專案索引 |
| [docs/](docs/) | 專案文件 |

## 授權條款

MIT License

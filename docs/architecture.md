# 系統架構

## 技術棧

| 層級 | 技術 | 說明 |
|------|------|------|
| 前端框架 | Lalilo | 靜態檔案產生器 |
| 前端 UI | Vue 3 CDN | Composition API |
| 模板引擎 | El3 | 縮排式 Vue template 語法 |
| 樣式 | SCSS + @oawu/scss | CSS 預處理器 |
| 後端框架 | Maple 9 | PHP 7.4，MVC + Active Record ORM |
| Worker | Node.js 18+ | pm2 常駐服務 |
| 資料庫 | MySQL | InnoDB, utf8mb4 |
| iOS App | SwiftUI | iOS 17+, watchOS 10+, XcodeGen |
| 容器 | Docker | 本機開發環境 |

---

## API 網址

| 環境 | 網址 |
|------|------|
| 本地 | `http://local-api-life.iwi.tw` |
| 線上測試 | `https://beta-api-life.iwi.tw` |
| 線上正式 | `https://api-life.iwi.tw` |

---

## 資料模型

### User（用戶）

| 欄位 | 類型 | 說明 |
|------|------|------|
| id | int unsigned AI | 主鍵 |
| name | varchar(190) | 名稱 |
| email | varchar(190) | Email |
| avatar | text | 頭像 URL |
| googleId | varchar(190), UNIQUE | Google 登入 ID |
| appleId | varchar(190), UNIQUE | Apple 登入 ID |
| status | enum(active, disabled) | 狀態 |
| token | varchar(512) | JWT Token（伺服端比對用） |
| updateAt | datetime | 更新時間 |
| createAt | datetime | 新增時間 |

---

## 資料流

（待開發後補齊）

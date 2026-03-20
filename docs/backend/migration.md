# Migration

## 建立 Migration 檔案

使用 CLI 指令建立，**不要手動新增檔案**：

```bash
php Maple.php create -I <type> <name> [<action>]
```

### 常用指令

```bash
# 資料表
php Maple.php create -I create User        # 建立 User 表
php Maple.php create -I drop User          # 刪除 User 表

# 欄位
php Maple.php create -I alter User add email      # 新增 email 欄位
php Maple.php create -I alter User drop email      # 刪除 email 欄位
php Maple.php create -I alter User change email    # 變更 email 欄位

# 資料
php Maple.php create -I insert User        # 新增資料
php Maple.php create -I update User        # 更新資料
php Maple.php create -I delete User        # 刪除資料
php Maple.php create -I truncate User      # 清空資料
```

### 命名規範

檔案自動以 `{版本號}-{type} {name}` 命名，版本號為 3 位數字：

```
Migration/
├── 001-create User.php
├── 002-alter User add avatar.php
└── 003-create Album.php
```

---

## 檔案結構

CLI 生成的檔案已包含模板和欄位格式參考，只需在 `up` 的 `CREATE TABLE` 中填入欄位即可：

```php
<?php

return [
  'up' => "CREATE TABLE `User` (
    `id`        int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',

    -- 在此填入欄位 --

    `updateAt`  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    `createAt`  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間',
    PRIMARY KEY (`id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='資料表註解';",

  'down' => "DROP TABLE IF EXISTS `User`;",

  'at' => "2026-02-10 16:36:32"  // 自動生成的時間戳
];
```

**三個必要鍵值：**

| 鍵 | 說明 |
|-----|------|
| `up` | 升級 SQL（字串或字串陣列） |
| `down` | 降級 SQL（字串或字串陣列） |
| `at` | 時間戳（自動生成） |

---

## 欄位格式速查

```sql
-- 主鍵
`id`        int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID'

-- 外鍵
`userId`    int(10) unsigned NOT NULL COMMENT 'User ID'

-- 整數
`sort`      int(10) unsigned NOT NULL DEFAULT 0 COMMENT '排序'

-- 字串
`title`     varchar(190) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '標題'
`content`   text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '內容'

-- 列舉
`status`    enum('pending', 'active', 'disabled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending' COMMENT '狀態'

-- 可為 NULL 的 TEXT
`avatar`    text COLLATE utf8mb4_unicode_ci COMMENT '頭像 URL'

-- JSON（ORM 自動 encode/decode，程式中直接用 array）
`colors`    json DEFAULT NULL COMMENT '色彩調色盤'

-- 小數
`price`     decimal(10,2) NOT NULL DEFAULT '0.00'

-- 時間戳（固定放在最後）
`updateAt`  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間'
`createAt`  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間'
```

### 索引

```sql
PRIMARY KEY (`id`),
UNIQUE KEY `email_unique` (`email`),
KEY `userId_index` (`userId`)
```

---

## 執行 Migration

```bash
php Maple.php migration           # 更新至最新版本
php Maple.php migration new       # 同上
php Maple.php migration -R        # 重置（回滾所有 Migration）
```

### 首次執行

系統自動建立 `_Migration` 追蹤資料表和對應 Model，用於記錄當前版本號。

### 失敗處理

Migration 執行失敗會自動 rollback，版本號維持在前一版。

---

## 命名慣例（CamelCase）

Maple ORM 預設使用 CamelCase：

| 項目 | 命名 | 範例 |
|------|------|------|
| 資料表 | 大駝峰（單數） | `User`、`Album` |
| 欄位 | 小駝峰 | `createAt`、`googleId`、`userId` |
| 外鍵 | 小駝峰 + Id | `userId`、`albumId` |

---

## 多條 SQL

`up` 和 `down` 支援字串陣列，依序執行多條 SQL：

```php
return [
  'up' => [
    "ALTER TABLE `User` ADD `avatar` text COLLATE utf8mb4_unicode_ci COMMENT '頭像' AFTER `name`;",
    "ALTER TABLE `User` ADD `bio` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '自介' AFTER `avatar`;",
  ],
  'down' => [
    "ALTER TABLE `User` DROP COLUMN `bio`;",
    "ALTER TABLE `User` DROP COLUMN `avatar`;",
  ],
  'at' => "2026-02-10 17:00:00"
];
```

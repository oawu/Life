<?php

return [
  'up' => "CREATE TABLE `Category` (
    `id`              int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `localId`         varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'Client UUID',
    `ledgerId`        int(10) unsigned NOT NULL COMMENT 'Ledger ID',
    `name`            varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '分類名稱',
    `icon`            varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'SF Symbol 圖示',
    `color`           varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '#007AFF' COMMENT '色碼 #RRGGBB',
    `sort`            int(10) unsigned NOT NULL DEFAULT 0 COMMENT '排序',
    `isSystemDefault` tinyint(3) unsigned NOT NULL DEFAULT 0 COMMENT '是否為系統預設',
    `updateAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    `createAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間',
    PRIMARY KEY (`id`),
    UNIQUE KEY `ledgerId_localId_unique` (`ledgerId`, `localId`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分類';",

  'down' => "DROP TABLE IF EXISTS `Category`;",

  'at' => "2026-03-24 18:00:03"
];

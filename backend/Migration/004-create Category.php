<?php

return [
  'up' => "CREATE TABLE `Category` (
    `id`              int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `ledgerId`        int(10) unsigned NOT NULL COMMENT 'Ledger ID',
    `key`             varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '系統預設分類識別碼',
    `name`            varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '分類名稱',
    `icon`            varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'SF Symbol 圖示',
    `color`           varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '#007AFF' COMMENT '色碼 #RRGGBB',
    `sort`            int(10) unsigned NOT NULL DEFAULT 0 COMMENT '排序',
    `updateAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    `createAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間',
    PRIMARY KEY (`id`),
    KEY `ledgerId` (`ledgerId`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分類';",

  'down' => "DROP TABLE IF EXISTS `Category`;",

  'at' => "2026-03-24 18:00:03"
];

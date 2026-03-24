<?php

return [
  'up' => "CREATE TABLE `LedgerMember` (
    `id`       int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `ledgerId` int(10) unsigned NOT NULL COMMENT 'Ledger ID',
    `userId`   int(10) unsigned NOT NULL COMMENT 'User ID',
    `role`     enum('owner', 'member') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'member' COMMENT '角色',
    `sort`     int(10) unsigned NOT NULL DEFAULT 0 COMMENT '排序',
    `joinAt`   datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '加入時間',
    PRIMARY KEY (`id`),
    UNIQUE KEY `ledgerId_userId_unique` (`ledgerId`, `userId`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='帳本成員';",

  'down' => "DROP TABLE IF EXISTS `LedgerMember`;",

  'at' => "2026-03-24 10:01:00"
];

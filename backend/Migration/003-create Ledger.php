<?php

return [
  'up' => "CREATE TABLE `Ledger` (
    `id`              int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `name`            varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '帳本名稱',
    `type`            enum('personal', 'group') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'personal' COMMENT '類型',
    `currency`        varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'TWD' COMMENT '幣別代碼',
    `inviteCode`      varchar(6) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '邀請碼（群組帳本）',
    `createdByUserId` int(10) unsigned NOT NULL COMMENT '建立者 User ID',
    `updateAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    `createAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間',
    PRIMARY KEY (`id`),
    UNIQUE KEY `inviteCode_unique` (`inviteCode`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='帳本';",

  'down' => "DROP TABLE IF EXISTS `Ledger`;",

  'at' => "2026-03-24 10:00:00"
];

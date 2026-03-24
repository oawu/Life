<?php

return [
  'up' => "CREATE TABLE `Settlement` (
    `id`              int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `ledgerId`        int(10) unsigned NOT NULL COMMENT 'Ledger ID',
    `settledByUserId` int(10) unsigned NOT NULL COMMENT '結算者 User ID',
    `transfers`       json DEFAULT NULL COMMENT '轉帳明細快照',
    `currencySymbol`  varchar(5) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '$' COMMENT '幣別符號',
    `createAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間',
    PRIMARY KEY (`id`),
    KEY `ledgerId_index` (`ledgerId`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='結算紀錄';",

  'down' => "DROP TABLE IF EXISTS `Settlement`;",

  'at' => "2026-03-24 18:00:06"
];

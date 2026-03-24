<?php

return [
  'up' => "CREATE TABLE `Expense` (
    `id`              int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `ledgerId`        int(10) unsigned NOT NULL COMMENT 'Ledger ID',
    `categoryId`      int(10) unsigned DEFAULT NULL COMMENT 'Category ID（null = 其他）',
    `amount`          int(10) unsigned NOT NULL DEFAULT 0 COMMENT '金額（整數）',
    `memo`            varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '備註',
    `date`            datetime NOT NULL COMMENT '消費日期時間',
    `latitude`        decimal(10,7) DEFAULT NULL COMMENT '緯度',
    `longitude`       decimal(10,7) DEFAULT NULL COMMENT '經度',
    `address`         varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '地址',
    `isSettled`       tinyint(3) unsigned NOT NULL DEFAULT 0 COMMENT '是否已結算',
    `paidByUserId`    int(10) unsigned DEFAULT NULL COMMENT '付款人 User ID',
    `createdByUserId` int(10) unsigned NOT NULL COMMENT '建立者 User ID',
    `updateAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    `createAt`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間',
    PRIMARY KEY (`id`),
    KEY `ledgerId` (`ledgerId`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='開銷';",

  'down' => "DROP TABLE IF EXISTS `Expense`;",

  'at' => "2026-03-24 18:00:04"
];

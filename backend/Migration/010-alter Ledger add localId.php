<?php

return [
  'up' => "ALTER TABLE `Ledger` ADD `localId` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Client UUID' AFTER `id`, ADD UNIQUE KEY `createdByUserId_localId_unique` (`createdByUserId`, `localId`);",

  'down' => "ALTER TABLE `Ledger` DROP INDEX `createdByUserId_localId_unique`, DROP COLUMN `localId`;",

  'at' => "2026-03-24 10:07:00"
];

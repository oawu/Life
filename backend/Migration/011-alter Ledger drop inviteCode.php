<?php

return [
  'up' => "ALTER TABLE `Ledger` DROP INDEX `inviteCode_unique`, DROP COLUMN `inviteCode`;",

  'down' => "ALTER TABLE `Ledger` ADD COLUMN `inviteCode` varchar(6) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '邀請碼（群組帳本）' AFTER `currency`, ADD UNIQUE KEY `inviteCode_unique` (`inviteCode`);",

  'at' => "2026-03-31 18:00:01"
];

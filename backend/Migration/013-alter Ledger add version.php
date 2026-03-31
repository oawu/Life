<?php

return [
  'up' => "ALTER TABLE `Ledger` ADD COLUMN `version` int(10) unsigned NOT NULL DEFAULT 1 COMMENT '版本號' AFTER `id`;",

  'down' => "ALTER TABLE `Ledger` DROP COLUMN `version`;",

  'at' => "2026-03-31 20:00:02"
];

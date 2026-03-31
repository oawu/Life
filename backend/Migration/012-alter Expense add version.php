<?php

return [
  'up' => "ALTER TABLE `Expense` ADD COLUMN `version` int(10) unsigned NOT NULL DEFAULT 1 COMMENT '版本號' AFTER `categoryId`;",

  'down' => "ALTER TABLE `Expense` DROP COLUMN `version`;",

  'at' => "2026-03-31 20:00:01"
];

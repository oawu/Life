<?php

return [
  'up' => "ALTER TABLE `User` ADD `token` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'JWT Token' AFTER `status`;",

  'down' => "ALTER TABLE `User` DROP COLUMN `token`;",

  'at' => "2026-03-20 22:00:00"
];

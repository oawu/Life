<?php

return [
  'up' => "ALTER TABLE `User` ADD `carrierNumber` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '載具號碼' AFTER `token`;",

  'down' => "ALTER TABLE `User` DROP COLUMN `carrierNumber`;",

  'at' => "2026-03-24 10:06:00"
];

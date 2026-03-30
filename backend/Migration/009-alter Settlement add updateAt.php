<?php

return [
  'up' => "ALTER TABLE `Settlement`
    ADD `updateAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間' AFTER `currencySymbol`;",

  'down' => "ALTER TABLE `Settlement`
    DROP COLUMN `updateAt`;",

  'at' => "2026-03-30 12:00:01"
];

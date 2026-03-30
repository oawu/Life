<?php

return [
  'up' => "ALTER TABLE `LedgerMember`
    ADD `updateAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間' AFTER `joinAt`,
    ADD `createAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '新增時間' AFTER `updateAt`;",

  'down' => "ALTER TABLE `LedgerMember`
    DROP COLUMN `updateAt`,
    DROP COLUMN `createAt`;",

  'at' => "2026-03-30 12:00:00"
];

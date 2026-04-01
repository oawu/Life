<?php

return [
  'up' => "ALTER TABLE `Expense`
    MODIFY COLUMN `latitude`  decimal(11,7) DEFAULT NULL COMMENT '緯度',
    MODIFY COLUMN `longitude` decimal(11,7) DEFAULT NULL COMMENT '經度';",

  'down' => "ALTER TABLE `Expense`
    MODIFY COLUMN `latitude`  decimal(10,7) DEFAULT NULL COMMENT '緯度',
    MODIFY COLUMN `longitude` decimal(10,7) DEFAULT NULL COMMENT '經度';",

  'at' => "2026-04-01 15:30:00"
];

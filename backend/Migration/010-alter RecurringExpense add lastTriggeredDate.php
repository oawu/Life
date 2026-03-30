<?php

return [
  'up' => "ALTER TABLE `RecurringExpense`
    ADD `lastTriggeredDate` date DEFAULT NULL COMMENT '最後觸發日期' AFTER `isEnabled`;",

  'down' => "ALTER TABLE `RecurringExpense`
    DROP COLUMN `lastTriggeredDate`;",

  'at' => "2026-03-31 12:00:00"
];

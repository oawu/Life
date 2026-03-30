<?php

namespace App\Model;

class RecurringExpense extends \Orm\Model {
  const IS_ENABLED_NO  = 0;
  const IS_ENABLED_YES = 1;
  const IS_ENABLED = [
    self::IS_ENABLED_NO  => '停用',
    self::IS_ENABLED_YES => '啟用',
  ];

  const FREQUENCY_TYPE_DAILY   = 'daily';
  const FREQUENCY_TYPE_WEEKLY  = 'weekly';
  const FREQUENCY_TYPE_MONTHLY = 'monthly';
  const FREQUENCY_TYPE_YEARLY  = 'yearly';
}

<?php

namespace App\Model;

class Expense extends \Orm\Model {
  const IS_SETTLED_NO  = 0;
  const IS_SETTLED_YES = 1;
  const IS_SETTLED = [
    self::IS_SETTLED_NO  => '未結算',
    self::IS_SETTLED_YES => '已結算',
  ];
}

<?php

namespace App\Model;

class Category extends \Orm\Model {
  const IS_SYSTEM_DEFAULT_NO  = 0;
  const IS_SYSTEM_DEFAULT_YES = 1;
  const IS_SYSTEM_DEFAULT = [
    self::IS_SYSTEM_DEFAULT_NO  => '否',
    self::IS_SYSTEM_DEFAULT_YES => '是',
  ];
}

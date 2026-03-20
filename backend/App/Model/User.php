<?php

namespace App\Model;

class User extends \Orm\Model {
  const STATUS_ACTIVE   = 'active';
  const STATUS_DISABLED = 'disabled';
  const STATUS = [
    self::STATUS_ACTIVE   => '啟用',
    self::STATUS_DISABLED => '停用',
  ];
}

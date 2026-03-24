<?php

namespace App\Model;

class LedgerMember extends \Orm\Model {
  const ROLE_OWNER  = 'owner';
  const ROLE_MEMBER = 'member';
  const ROLE = [
    self::ROLE_OWNER  => '擁有者',
    self::ROLE_MEMBER => '成員',
  ];
}

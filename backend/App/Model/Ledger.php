<?php

namespace App\Model;

class Ledger extends \Orm\Model {
  const TYPE_PERSONAL = 'personal';
  const TYPE_GROUP    = 'group';
  const TYPE = [
    self::TYPE_PERSONAL => '個人',
    self::TYPE_GROUP    => '群組',
  ];

  public static function generateInviteCode(): string {
    $chars = 'ACDEFGHJKMNPQRTUVWXY34679';

    do {
      $code = '';
      for ($i = 0; $i < 6; $i++) {
        $code .= $chars[random_int(0, strlen($chars) - 1)];
      }
    } while (self::one('inviteCode', $code));

    return $code;
  }
}

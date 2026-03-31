<?php

namespace App\Model;

class Ledger extends \Orm\Model {
  const TYPE_PERSONAL = 'personal';
  const TYPE_GROUP    = 'group';
  const TYPE = [
    self::TYPE_PERSONAL => '個人',
    self::TYPE_GROUP    => '群組',
  ];

  private static $_inviteHashids = null;

  private static function _inviteHashids(): \App\Lib\Hashids {
    if (self::$_inviteHashids !== null) {
      return self::$_inviteHashids;
    }
    self::$_inviteHashids = new \App\Lib\Hashids(8, KEY . '-Ledger', 'ACDEFGHJKMNPQRTUVWXY34679');
    return self::$_inviteHashids;
  }

  public function inviteCode(): string {
    return self::_inviteHashids()->encode($this->id);
  }

  public static function decodeInviteCode(string $code): ?int {
    $ids = self::_inviteHashids()->decode($code);
    return !empty($ids) ? (int)$ids[0] : null;
  }
}

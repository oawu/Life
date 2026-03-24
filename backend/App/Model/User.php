<?php

namespace App\Model;

use \App\Lib\Jwt;

class User extends \Orm\Model {
  const STATUS_ACTIVE   = 'active';
  const STATUS_DISABLED = 'disabled';
  const STATUS = [
    self::STATUS_ACTIVE   => '啟用',
    self::STATUS_DISABLED => '停用',
  ];

  private static $_current = null;

  public static function setCurrent(User $user) {
    self::$_current = $user;
  }

  public static function current() {
    return self::$_current;
  }

  public function toSafeArray(): array {
    return [
      'id'             => $this->id,
      'email'          => $this->email,
      'name'           => $this->name,
      'avatar'         => $this->avatar,
      'status'         => $this->status,
      'carrierNumber'  => $this->carrierNumber ?? '',
    ];
  }

  public function issueToken(): array {
    $jwt = Jwt::encode([
      'sub'   => $this->id,
      'email' => $this->email,
      'iat'   => time(),
      'exp'   => time() + 30 * 24 * 60 * 60,
    ], KEY, Jwt::HS256);

    $this->token = $jwt;

    $self = $this;
    transaction(static function () use ($self) {
      return $self->save() ?? error('儲存 token 失敗');
    });

    return [
      'token' => $jwt,
      'user'  => $this->toSafeArray(),
    ];
  }
}

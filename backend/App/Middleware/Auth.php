<?php

namespace App\Middleware;

use \Request;
use \App\Lib\Jwt;
use \App\Model\User;

class Auth {
  public function index($return) {
    if (Request::getMethod() === 'OPTIONS') {
      return $return;
    }

    // 取得 Authorization header
    $headers = Request::getHeaders();

    $authHeader = '';
    if (isset($headers['Authorization'])) {
      $authHeader = $headers['Authorization'];
    } elseif (isset($headers['authorization'])) {
      $authHeader = $headers['authorization'];
    }

    // 解析 Bearer token
    if (!preg_match('/^Bearer\s+(.+)$/i', $authHeader, $matches)) {
      error('Missing or invalid Authorization header', 401);
    }

    // 驗證 JWT
    $token = $matches[1];
    $payload = Jwt::decode($token, KEY);

    if ($payload === null) {
      error('Invalid or expired token', 401);
    }

    // 查詢用戶
    $user = User::one('id', $payload['sub']);

    if ($user === null) {
      error('User not found', 401);
    }

    // 比對 DB token（支援伺服端失效）
    if ($user->token !== $token) {
      error('Token has been revoked', 401);
    }

    // 檢查帳號狀態
    if ($user->status === User::STATUS_DISABLED) {
      error('Account is disabled', 401);
    }

    User::setCurrent($user);

    return $user;
  }
}

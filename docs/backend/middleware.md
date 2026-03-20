# 中介層（Middleware）

## 位置

`App/Middleware/`

## CORS 中介層

框架內建 CORS 中介層範例 `App/Middleware/Cors.php`：

```php
<?php

namespace App\Middleware;

use \Request;
use \Response;
use \Config;

class Cors {
  private $_methods = ['POST', 'PUT', 'DELETE', 'OPTIONS'];
  private $_headers = ['Content-Type', 'Authorization', 'X-Requested-With', 'authorization'];

  public function index(): void {
    $origins = Config::get('Cors', 'origins') ?? [];
    $headers = Request::getHeaders();

    if ($origins) {
      $origin = $headers['Origin'] ?? '';
      if (in_array($origin, $origins)) {
        Response::setHeader('Access-Control-Allow-Headers', implode(', ', $this->_headers));
        Response::setHeader('Access-Control-Allow-Methods', implode(', ', $this->_methods));
        Response::setHeader('Access-Control-Allow-Origin', $origin);
      }
    }
  }
}
```

允許的 origins 透過設定檔管理：

- `Config/Cors.php` — 預設（空陣列）
- `Config/Local/Cors.php` — 本地環境覆蓋（已 gitignore）

## 執行機制

Middleware 按路由群組掛載順序**依序執行**，前一個的回傳值作為下一個的參數，最終回傳值傳給 Controller 方法的最後一個參數：

```
Cors::index(null) → 回傳 void（$return 維持 null）
  ↓
Auth::index(null) → 回傳 User Model
  ↓
Controller::method($routeParams..., $user)
```

### 中止請求

Middleware 若要中止請求（如認證失敗），使用全域 `error()` 函式拋出例外：

```php
public function index($return) {
  if (!$valid) {
    error('Unauthorized', 401);
  }

  return $user;
}
```

`error(string $message, ?int $code)` 會拋出例外並中止流程，由 Api Middleware 的 `Response::setType(TYPE_API)` 確保回應為 JSON 格式。

## 掛載方式

在路由群組中使用 `->middleware()`：

```php
Group::create('api')
  ->middleware(App\Middleware\Cors::class)
  ->corsOptionsResponse('ok!')
  ->routers(static function() {
    // ...
  });
```

## 多層 Middleware

巢狀群組可疊加 Middleware，內層群組繼承外層的 Middleware：

```php
Group::create('api')
  ->middleware(App\Middleware\Cors::class)    // 所有 /api/* 都經過 CORS
  ->corsOptionsResponse('ok!')
  ->routers(static function() {

    // 公開路由（只經過 Cors）
    Router::post('auth/google/callback')
      ->controller(\App\Controller\Api\Auth::class . '@googleCallback');

    // 需認證路由（經過 Cors → Auth）
    Group::create()
      ->middleware(App\Middleware\Auth::class)
      ->routers(static function() {
        Router::get('auth/me')
          ->controller(\App\Controller\Api\Auth::class . '@me');

        // 管理員路由（經過 Cors → Auth → Admin）
        Group::create()
          ->middleware(App\Middleware\Admin::class)
          ->routers(static function() {
            Router::get('users')
              ->controller(\App\Controller\Api\User::class . '@index');
          });
      });
  });
```

## Auth Middleware 範例

JWT 驗證中介層，從 `Authorization: Bearer <token>` 取得並驗證 JWT：

```php
<?php

namespace App\Middleware;

use \Request;
use App\Lib\Jwt;
use App\Model\User;

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
    $payload = Jwt::decode($token);

    if ($payload === null) {
      error('Invalid or expired token', 401);
    }

    // 查詢用戶、比對 token、檢查狀態
    $user = User::one('id', $payload['sub']);

    if ($user === null) {
      notFound('User not found');
    }

    if ($user->token !== $token) {
      error('Token has been revoked', 401);
    }

    if ($user->status === 'disabled') {
      error('Account is disabled', 403);
    }

    if ($user->status === 'pending') {
      error('Account is pending approval', 403);
    }

    return $user;
  }
}
```

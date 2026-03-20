# 路由（Router）

## 路由定義

路由定義在 `Router/Main.php`，支援多種 HTTP 方法：

```php
// CLI 路由
Router::cli()->func(fn() => 'Hello!');

// HTTP 路由 — 對應 Controller
Router::get()->controller(\App\Controller\Main::class);
Router::post()->controller(\App\Controller\Main::class);
Router::put()->controller(\App\Controller\Main::class);
Router::delete()->controller(\App\Controller\Main::class);
```

## 路由群組

使用 `Group` 建立帶前綴的路由群組，可掛載 Middleware：

```php
use \Router\Group;

Group::create('api')
  ->middleware(App\Middleware\Cors::class)
  ->corsOptionsResponse('ok!')
  ->routers(static function() {

    Router::get('users')->controller(\App\Controller\Api\User::class);
    Router::post('user')->controller(\App\Controller\Api\User::class . '@create');
    Router::get('user/{{ id: int(0) }}')->controller(\App\Controller\Api\User::class . '@show');
    Router::put('user/{{ id: int(0) }}')->controller(\App\Controller\Api\User::class . '@update');
    Router::delete('user/{{ id: int(0) }}')->controller(\App\Controller\Api\User::class . '@delete');
  });
```

## 巢狀群組

群組可以巢狀，內層群組繼承外層的前綴和 Middleware。無前綴群組用於在同一前綴下區分認證與公開路由：

```php
Group::create('api')
  ->middleware(App\Middleware\Cors::class)
  ->corsOptionsResponse('ok!')
  ->routers(static function() {

    // 公開路由：/api/auth/google/callback
    Router::post('auth/google/callback')
      ->controller(\App\Controller\Api\Auth::class . '@googleCallback');

    // 需認證路由群組（無額外前綴）
    Group::create()
      ->middleware(App\Middleware\Auth::class)
      ->routers(static function() {
        // /api/auth/me
        Router::get('auth/me')
          ->controller(\App\Controller\Api\Auth::class . '@me');
      });
  });
```

### corsOptionsResponse

`->corsOptionsResponse('ok!')` 會自動為群組內的所有路由生成對應的 `OPTIONS` 路由，處理 CORS 預檢請求。回傳值為 OPTIONS 的回應內容。

---

## 路由參數型別

路由支援以下參數型別約束：

| 型別 | 說明 |
|------|------|
| `int(0)` | 整數，預設值 0 |
| `int(0, 10)` | 整數，範圍 0~10 |
| `int`, `int8`, `int16`, `int32`, `int64` | 有號整數 |
| `uint`, `uint8`, `uint16`, `uint32`, `uint64` | 無號整數 |
| `float`, `double`, `num`, `number` | 浮點數 |
| `str`, `string` | 字串 |

```php
// 範例
Router::get('user/{{ id: uint }}')->controller(...);
Router::get('page/{{ slug: string }}')->controller(...);
```

---

## 參數傳遞

路由匹配的參數會依序傳入 Controller 方法，Middleware 的回傳值作為最後一個參數：

```php
// 路由：Router::get('album/{{ id: uint }}')
// Middleware 鏈回傳：$user
// Controller 接收：function show($id, $user)
```

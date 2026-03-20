# 控制器（Controller）

## 位置

`App/Controller/`

## 基本結構

```php
<?php

namespace App\Controller;

use \View;

class Main {
  public function index(): View {
    return View::create('Main');
  }
}
```

## 對應規則

- 路由預設呼叫 `index()` 方法
- 使用 `@` 指定其他方法：`Controller::class . '@create'`

```php
// Router/Main.php
Router::get('users')->controller(\App\Controller\Api\User::class);           // -> index()
Router::post('user')->controller(\App\Controller\Api\User::class . '@create'); // -> create()
```

## 命名空間

Controller 使用 `App\Controller` 命名空間，子目錄對應子命名空間：

```
App/Controller/Main.php         → \App\Controller\Main
App/Controller/Api/User.php     → \App\Controller\Api\User
App/Controller/Api/Auth.php     → \App\Controller\Api\Auth
```

## 回傳值

Controller 方法的回傳值會經由 `Response::output()` 自動處理：

```php
// 回傳陣列 → 自動轉 JSON（前端 Accept: application/json 時）
public function index() {
  return ['status' => 'ok', 'data' => $items];
}

// 回傳 View → 渲染 HTML
public function show(): View {
  return View::create('User/Show');
}

// 回傳 ORM Model → 自動呼叫 toArray() 再轉 JSON
public function user($id) {
  return User::one($id);
}
```

### 錯誤回應

使用全域函式中止流程並回傳錯誤（需搭配 Api Middleware）：

```php
error(string $message, ?int $code = null): void     // 一般錯誤
notFound(string $message = '', int $code = 404): void // 找不到資料
```

```php
public function show($id) {
  $user = User::one($id);

  if ($user === null) {
    notFound('User not found');
  }

  return ['user' => [
    'id' => $user->id,
    'name' => $user->name,
    'email' => $user->email,
  ]];
}
```

**注意：** 禁止覆寫 Model 的 `toArray()`，不同 API 可能需要不同回應欄位，應在 Controller 內直接組裝陣列。

### 手動設定狀態碼

成功但非 200 的情況，使用 `Response::setCode()`：

```php
use \Response;

public function create() {
  Response::setCode(201);
  return ['id' => $user->id];
}
```

## 接收參數

### 路由參數

路由 `{{ id: int(0) }}` 匹配的參數會依序作為方法引數傳入：

```php
// Router: Router::get('user/{{ id: uint }}')->controller(User::class . '@show');
public function show($id) {
  // $id = 路由匹配的值
}
```

### 當前用戶

Controller 方法只接收路由參數，不接收 Middleware 傳遞的變數。
透過 `User::current()` 取得當前用戶：

```php
public function show(int $id) {
  $user = User::current();
}
```

> 詳見：`.claude/rules/php-conventions.md`「Controller 方法簽名」

### Request Body

```php
use \Request\Payload;

public function create() {
  // JSON body → 已解碼的 PHP 陣列
  $data = Payload::getJson();
  // $data['name'], $data['email'] ...

  // Form data
  $data = Payload::getData();

  // 上傳檔案
  $files = Payload::getFiles();
}
```

**注意：** `Payload::getJson()` 回傳的是**已解碼的 PHP 陣列**（非 JSON 字串），框架內部已呼叫 `json_decode`。

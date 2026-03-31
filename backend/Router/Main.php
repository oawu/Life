<?php

use \Router\Group;

require __DIR__ . '/Cli.php';

Router::get()->controller(\App\Controller\Main::class);
Router::post()->controller(\App\Controller\Main::class);

Group::create('api')
  ->middleware(
    \App\Middleware\Api::class,
    \App\Middleware\Cors::class
  )
  ->cors('ok!')
  ->routers(static function() {

    // 公開路由
    Router::post('auth/apple/callback')
      ->controller(\App\Controller\Api\Auth::class . '@appleCallback')
      ->title('Apple Sign In 回調');

    Router::post('test/reset')
      ->controller(\App\Controller\Api\Test::class . '@reset')
      ->title('測試 DB 重置（僅限非 Production）');

    Router::post('test/query')
      ->controller(\App\Controller\Api\Test::class . '@query')
      ->title('測試 DB 查詢（僅限非 Production，只允許 SELECT）');

    // 需認證路由
    Group::create()
      ->middleware(\App\Middleware\Auth::class)
      ->routers(static function() {
        // Auth
        Router::get('auth/me')
          ->controller(\App\Controller\Api\Auth::class . '@me')
          ->title('取得當前用戶');

        Router::put('auth/me')
          ->controller(\App\Controller\Api\Auth::class . '@updateProfile')
          ->title('更新個人資料');

        Router::post('auth/init')
          ->controller(\App\Controller\Api\Auth::class . '@init')
          ->title('登入初始化');

        // State
        Router::get('state')
          ->controller(\App\Controller\Api\State::class . '@index')
          ->title('取得完整狀態');

        // Manifest
        Router::get('manifest')
          ->controller(\App\Controller\Api\Manifest::class . '@index')
          ->title('取得 Manifest');

        Router::post('ledgers/{{ id: uint }}/expenses/fetch')
          ->controller(\App\Controller\Api\Manifest::class . '@fetch')
          ->title('批次取得開銷');

        // Ledger（群組帳本）
        Router::post('ledgers')
          ->controller(\App\Controller\Api\Ledger::class . '@create')
          ->title('建立群組帳本');

        Router::get('ledgers/{{ id: uint }}')
          ->controller(\App\Controller\Api\Ledger::class . '@show')
          ->title('取得帳本詳情');

        Router::put('ledgers/{{ id: uint }}')
          ->controller(\App\Controller\Api\Ledger::class . '@update')
          ->title('更新帳本');

        Router::post('ledgers/join')
          ->controller(\App\Controller\Api\Ledger::class . '@join')
          ->title('加入群組帳本');

        Router::post('ledgers/{{ id: uint }}/leave')
          ->controller(\App\Controller\Api\Ledger::class . '@leave')
          ->title('退出群組帳本');

        Router::get('ledgers/{{ id: uint }}/members')
          ->controller(\App\Controller\Api\Ledger::class . '@members')
          ->title('取得成員列表');

        Router::post('ledgers/{{ id: uint }}/settle')
          ->controller(\App\Controller\Api\Ledger::class . '@settle')
          ->title('結算拆帳');

        // Category
        Router::post('ledgers/{{ id: uint }}/categories')
          ->controller(\App\Controller\Api\Category::class . '@create')
          ->title('建立分類');

        Router::put('categories/{{ id: uint }}')
          ->controller(\App\Controller\Api\Category::class . '@update')
          ->title('更新分類');

        Router::delete('categories/{{ id: uint }}')
          ->controller(\App\Controller\Api\Category::class . '@destroy')
          ->title('刪除分類');

        Router::put('ledgers/{{ id: uint }}/categories/sort')
          ->controller(\App\Controller\Api\Category::class . '@sort')
          ->title('排序分類');

        // Expense
        Router::post('ledgers/{{ id: uint }}/expenses')
          ->controller(\App\Controller\Api\Expense::class . '@create')
          ->title('建立開銷');

        Router::post('ledgers/{{ id: uint }}/expenses/batch')
          ->controller(\App\Controller\Api\Expense::class . '@batch')
          ->title('批次建立開銷');

        Router::put('expenses/{{ id: uint }}')
          ->controller(\App\Controller\Api\Expense::class . '@update')
          ->title('更新開銷');

        Router::delete('expenses/{{ id: uint }}')
          ->controller(\App\Controller\Api\Expense::class . '@destroy')
          ->title('刪除開銷');

        // RecurringExpense
        Router::post('ledgers/{{ id: uint }}/recurring-expenses')
          ->controller(\App\Controller\Api\RecurringExpense::class . '@create')
          ->title('建立固定開銷');

        Router::put('recurring-expenses/{{ id: uint }}')
          ->controller(\App\Controller\Api\RecurringExpense::class . '@update')
          ->title('更新固定開銷');

        Router::delete('recurring-expenses/{{ id: uint }}')
          ->controller(\App\Controller\Api\RecurringExpense::class . '@destroy')
          ->title('刪除固定開銷');
      });
  });

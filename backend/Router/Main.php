<?php

use \Router\Group;

Router::cli()->func(fn() => 'Hello!');
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

        // Sync
        Router::post('sync/push')
          ->controller(\App\Controller\Api\Sync::class . '@push')
          ->title('推送本地變更');

        Router::post('sync/pull')
          ->controller(\App\Controller\Api\Sync::class . '@pull')
          ->title('拉取遠端變更');

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
      });
  });

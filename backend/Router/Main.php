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
      });
  });

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
        Router::get('auth/me')
          ->controller(\App\Controller\Api\Auth::class . '@me')
          ->title('取得當前用戶');
      });
  });

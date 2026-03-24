<?php

namespace App\Model;

class Category extends \Orm\Model {
  public static function defaultPersonalCategories(): array {
    return [
      ['key' => 'breakfast',     'name' => '早餐',     'icon' => 'sunrise.fill',              'color' => '#FF9500'],
      ['key' => 'lunch',         'name' => '午餐',     'icon' => 'sun.max.fill',              'color' => '#FF9500'],
      ['key' => 'dinner',        'name' => '晚餐',     'icon' => 'moon.fill',                 'color' => '#FF9500'],
      ['key' => 'dessert',       'name' => '甜點',     'icon' => 'birthday.cake.fill',        'color' => '#FF9500'],
      ['key' => 'drink',         'name' => '飲料',     'icon' => 'cup.and.saucer.fill',       'color' => '#FF9500'],
      ['key' => 'rent',          'name' => '租金',     'icon' => 'building.2.fill',           'color' => '#34C759'],
      ['key' => 'clothing',      'name' => '衣服',     'icon' => 'tshirt.fill',               'color' => '#FF2D55'],
      ['key' => 'dailySupply',   'name' => '日用品',   'icon' => 'basket.fill',               'color' => '#FF2D55'],
      ['key' => 'medical',       'name' => '醫療',     'icon' => 'cross.case.fill',           'color' => '#FF3B30'],
      ['key' => 'shopping',      'name' => '購物',     'icon' => 'bag.fill',                  'color' => '#FF2D55'],
      ['key' => 'bus',           'name' => '交通',     'icon' => 'bus.fill',                  'color' => '#007AFF'],
      ['key' => 'car',           'name' => '汽車',     'icon' => 'car.fill',                  'color' => '#007AFF'],
      ['key' => 'fuel',          'name' => '加油',     'icon' => 'fuelpump.fill',             'color' => '#007AFF'],
      ['key' => 'parking',       'name' => '停車',     'icon' => 'p.square.fill',             'color' => '#007AFF'],
      ['key' => 'transit',       'name' => '大眾運輸', 'icon' => 'tram.fill',                 'color' => '#007AFF'],
      ['key' => 'entertainment', 'name' => '娛樂',     'icon' => 'gamecontroller.fill',       'color' => '#AF52DE'],
      ['key' => 'sport',         'name' => '運動',     'icon' => 'figure.run',                'color' => '#AF52DE'],
      ['key' => 'study',         'name' => '學習',     'icon' => 'book.fill',                 'color' => '#AF52DE'],
      ['key' => 'creditCard',    'name' => '信用卡',   'icon' => 'creditcard.fill',           'color' => '#30B0C7'],
      ['key' => 'investment',    'name' => '投資',     'icon' => 'chart.line.uptrend.xyaxis', 'color' => '#30B0C7'],
      ['key' => 'transfer',      'name' => '轉帳',     'icon' => 'arrow.left.arrow.right',    'color' => '#30B0C7'],
      ['key' => 'gift',          'name' => '禮物',     'icon' => 'gift.fill',                 'color' => '#8E8E93'],
      ['key' => 'redEnvelope',   'name' => '紅包',     'icon' => 'envelope.fill',             'color' => '#FF3B30'],
      ['key' => 'phone',         'name' => '電話費',   'icon' => 'phone.fill',                'color' => '#34C759'],
      ['key' => 'subscription',  'name' => '訂閱',     'icon' => 'repeat',                    'color' => '#5856D6'],
      ['key' => 'threeC',        'name' => '3C',       'icon' => 'desktopcomputer',           'color' => '#8E8E93'],
    ];
  }

  public static function defaultGroupCategories(): array {
    return [
      ['key' => 'groupDining',        'name' => '聚餐', 'icon' => 'fork.knife',           'color' => '#FF9500'],
      ['key' => 'groupGrocery',       'name' => '採買', 'icon' => 'cart.fill',             'color' => '#FF2D55'],
      ['key' => 'groupRent',          'name' => '租金', 'icon' => 'building.2.fill',       'color' => '#34C759'],
      ['key' => 'groupUtility',       'name' => '水電', 'icon' => 'bolt.fill',             'color' => '#FFCC00'],
      ['key' => 'groupTransport',     'name' => '交通', 'icon' => 'bus.fill',              'color' => '#007AFF'],
      ['key' => 'groupEntertainment', 'name' => '娛樂', 'icon' => 'gamecontroller.fill',   'color' => '#AF52DE'],
    ];
  }
}

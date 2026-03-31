<?php

namespace App\Controller\Api;

use \Valid;
use \Request\Payload;
use \App\Model\User;
use \App\Model\Ledger;
use \App\Model\LedgerMember;
use \App\Model\Category as CategoryModel;
use \App\Model\Expense;
use \App\Model\RecurringExpense;

class Category {
  public function create(int $id) {
    $user   = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    list(
      'name'  => $name,
      'icon'  => $icon,
      'color' => $color,
    ) = Valid::check(Payload::getJson(), [
      'name'  => Valid::string('分類名稱')->min(1)->max(50),
      'icon'  => Valid::string('圖示')->min(1)->max(50),
      'color' => Valid::string_('色碼')->max(7)->nullOrNoKey('#007AFF'),
    ]);

    // sort = 目前最大 + 1
    $maxSort  = CategoryModel::where('ledgerId', $ledger->id)->order('sort DESC')->one();
    $nextSort = $maxSort ? $maxSort->sort + 1 : 0;

    $category = transaction(static function () use ($ledger, $name, $icon, $color, $nextSort) {
      $category = CategoryModel::create([
        'ledgerId' => $ledger->id,
        'name'     => $name,
        'icon'     => $icon,
        'color'    => $color,
        'sort'     => $nextSort,
      ]) ?? error('建立分類失敗');

      $ledger->incrementVersion();
      $ledger->save() ?? error('更新帳本版本失敗');

      return $category;
    });

    return ['category' => State::formatCategory($category)];
  }

  public function update(int $id) {
    $user     = User::current();
    $category = CategoryModel::one('id', $id);

    if (!$category) {
      notFound('分類不存在');
    }

    $ledger = self::_findLedgerAsMember($category->ledgerId, $user->id);

    list(
      'name'  => $name,
      'icon'  => $icon,
      'color' => $color,
    ) = Valid::check(Payload::getJson(), [
      'name'  => Valid::string_('分類名稱')->max(50)->nullOrNoKey(null),
      'icon'  => Valid::string_('圖示')->max(50)->nullOrNoKey(null),
      'color' => Valid::string_('色碼')->max(7)->nullOrNoKey(null),
    ]);

    if ($name === null && $icon === null && $color === null) {
      return ['category' => State::formatCategory($category)];
    }

    if ($name !== null) {
      $category->name = $name;
    }

    if ($icon !== null) {
      $category->icon = $icon;
    }

    if ($color !== null) {
      $category->color = $color;
    }

    transaction(static function () use ($category, $ledger) {
      $category->save() ?? error('更新分類失敗');
      $ledger->incrementVersion();
      return $ledger->save();
    });

    return ['category' => State::formatCategory($category)];
  }

  public function destroy(int $id) {
    $user     = User::current();
    $category = CategoryModel::one('id', $id);

    if (!$category) {
      notFound('分類不存在');
    }

    $ledger = self::_findLedgerAsMember($category->ledgerId, $user->id);

    transaction(static function () use ($category, $ledger) {
      // 級聯：開銷和固定開銷的 categoryId 設為 null
      $expenses = Expense::where('categoryId', $category->id)->all();
      foreach ($expenses as $expense) {
        $expense->categoryId = null;
        $expense->version = $expense->version + 1;
        $expense->save() ?? error('更新開銷分類失敗');
      }

      $recurringExpenses = RecurringExpense::where('categoryId', $category->id)->all();
      foreach ($recurringExpenses as $recurring) {
        $recurring->categoryId = null;
        $recurring->save() ?? error('更新固定開銷分類失敗');
      }

      $category->delete() ?? error('刪除分類失敗');

      $ledger->incrementVersion();
      $ledger->save() ?? error('更新帳本版本失敗');

      return true;
    });

    return ['success' => true];
  }

  public function sort(int $id) {
    $user   = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    list(
      'categoryIds' => $categoryIds,
    ) = Valid::check(Payload::getJson(), [
      'categoryIds' => Valid::array('分類 ID', Valid::uInt('ID')),
    ]);

    transaction(static function () use ($ledger, $categoryIds) {
      foreach ($categoryIds as $index => $categoryId) {
        $category = CategoryModel::where('id', $categoryId)->where('ledgerId', $ledger->id)->one();

        if (!$category) {
          continue;
        }

        $category->sort = $index;
        $category->save() ?? error('更新排序失敗');
      }

      $ledger->incrementVersion();
      $ledger->save() ?? error('更新帳本版本失敗');

      return true;
    });

    return ['success' => true];
  }

  // MARK: - Private

  private static function _findLedgerAsMember(int $ledgerId, int $userId): Ledger {
    $ledger = Ledger::one('id', $ledgerId);

    if (!$ledger) {
      notFound('帳本不存在');
    }

    $member = LedgerMember::where('ledgerId', $ledgerId)->where('userId', $userId)->one();

    if (!$member) {
      error('你不是此帳本的成員', 403);
    }

    return $ledger;
  }
}

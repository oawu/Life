<?php

namespace App\Controller\Api;

use \Valid;
use \Request\Payload;
use \App\Model\User;
use \App\Model\Ledger as LedgerModel;
use \App\Model\LedgerMember;
use \App\Model\Category;
use \App\Model\Expense;
use \App\Model\RecurringExpense;
use \App\Model\Settlement;

class Ledger {
  public function create() {
    $user = User::current();

    list(
      'name'     => $name,
      'currency' => $currency,
    ) = Valid::check(Payload::getJson(), [
      'name'     => Valid::string('帳本名稱')->min(1)->max(100),
      'currency' => Valid::string_('幣別')->max(3)->nullOrNoKey('TWD'),
    ]);

    $inviteCode = LedgerModel::generateInviteCode();

    $ledger = transaction(static function () use ($name, $currency, $inviteCode, $user) {
      $ledger = LedgerModel::create([
        'name'            => $name,
        'type'            => LedgerModel::TYPE_GROUP,
        'currency'        => $currency,
        'inviteCode'      => $inviteCode,
        'createdByUserId' => $user->id,
      ]) ?? error('建立帳本失敗');

      LedgerMember::create([
        'ledgerId' => $ledger->id,
        'userId'   => $user->id,
        'role'     => LedgerMember::ROLE_OWNER,
      ]) ?? error('建立成員失敗');

      $defaults = Category::defaultGroupCategories();
      foreach ($defaults as $index => $cat) {
        Category::create([
          'ledgerId' => $ledger->id,
          'key'      => $cat['key'],
          'name'     => $cat['name'],
          'icon'     => $cat['icon'],
          'color'    => $cat['color'],
          'sort'     => $index,
        ]) ?? error('建立分類失敗');
      }

      return $ledger;
    });

    return ['ledger' => self::_buildLedgerResponse($ledger, $user)];
  }

  public function show(int $id) {
    $user   = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    return ['ledger' => self::_buildLedgerResponse($ledger, $user)];
  }

  public function update(int $id) {
    $user   = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    list(
      'name'     => $name,
      'currency' => $currency,
    ) = Valid::check(Payload::getJson(), [
      'name'     => Valid::string_('帳本名稱')->max(100)->nullOrNoKey(null),
      'currency' => Valid::string_('幣別')->max(3)->nullOrNoKey(null),
    ]);

    if ($name === null && $currency === null) {
      return ['ledger' => self::_buildLedgerResponse($ledger, $user)];
    }

    if ($name !== null) {
      $ledger->name = $name;
    }

    if ($currency !== null) {
      // 有開銷時不可變更幣別
      $expenseCount = Expense::where('ledgerId', $ledger->id)->count();
      if ($expenseCount > 0 && $currency !== $ledger->currency) {
        error('帳本已有開銷，無法變更幣別', 400);
      }
      $ledger->currency = $currency;
    }

    transaction(static function () use ($ledger) {
      return $ledger->save();
    });

    return ['ledger' => self::_buildLedgerResponse($ledger, $user)];
  }

  public function join() {
    $user = User::current();

    list(
      'inviteCode' => $inviteCode,
    ) = Valid::check(Payload::getJson(), [
      'inviteCode' => Valid::string('邀請碼')->min(1)->max(6),
    ]);

    $inviteCode = strtoupper($inviteCode);

    $ledger = LedgerModel::one('inviteCode', $inviteCode);
    if (!$ledger) {
      error('邀請碼無效', 404);
    }

    // 檢查是否已是成員
    $existing = LedgerMember::where('ledgerId', $ledger->id)->where('userId', $user->id)->one();
    if ($existing) {
      error('你已經是此帳本的成員', 400);
    }

    // 檢查是否有未結算開銷
    $unsettled = Expense::where('ledgerId', $ledger->id)->where('isSettled', Expense::IS_SETTLED_NO)->count();
    if ($unsettled > 0) {
      error('帳本尚未結清，無法加入新成員', 400);
    }

    transaction(static function () use ($ledger, $user) {
      return LedgerMember::create([
        'ledgerId' => $ledger->id,
        'userId'   => $user->id,
        'role'     => LedgerMember::ROLE_MEMBER,
      ]) ?? error('加入失敗');
    });

    return ['ledger' => self::_buildLedgerResponse($ledger, $user)];
  }

  public function leave(int $id) {
    $user   = User::current();
    $member = LedgerMember::where('ledgerId', $id)->where('userId', $user->id)->one();

    if (!$member) {
      error('你不是此帳本的成員', 403);
    }

    // 檢查未結算開銷
    $unsettled = Expense::where('ledgerId', $id)->where('isSettled', Expense::IS_SETTLED_NO)->count();
    if ($unsettled > 0) {
      error('帳本尚未結清，無法退出', 400);
    }

    $result = transaction(static function () use ($member, $id, $user) {
      // 刪除該成員的固定開銷
      $recurringExpenses = RecurringExpense::where('ledgerId', $id)->where('paidByUserId', $user->id)->all();
      foreach ($recurringExpenses as $recurring) {
        $recurring->delete() ?? error('刪除固定開銷失敗');
      }

      $member->delete() ?? error('退出失敗');

      // 在 transaction 內檢查殘餘成員（避免 race condition）
      $remainingMembers = (int)LedgerMember::where('ledgerId', $id)->count();
      return ['shouldDelete' => $remainingMembers === 0];
    });

    if ($result['shouldDelete']) {
      self::_deleteLedgerCompletely($id);
    }

    return ['success' => true];
  }

  public function members(int $id) {
    $user = User::current();
    self::_findLedgerAsMember($id, $user->id);

    $members = LedgerMember::where('ledgerId', $id)->all();
    $userIds = array_map(static function ($member) {
      return $member->userId;
    }, $members);

    $users   = User::where('id', $userIds)->all();
    $userMap = [];
    foreach ($users as $userItem) {
      $userMap[$userItem->id] = $userItem;
    }

    return ['members' => array_map(static function ($member) use ($user, $userMap) {
      $memberUser = $userMap[$member->userId] ?? null;
      return [
        'id'            => $member->id,
        'userId'        => $member->userId,
        'name'          => $memberUser ? $memberUser->name : '',
        'role'          => $member->role,
        'isCurrentUser' => $member->userId == $user->id,
      ];
    }, $members)];
  }

  public function settle(int $id) {
    $user = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    list(
      'transfers' => $transfers,
    ) = Valid::check(Payload::getJson(), [
      'transfers' => Valid::array('轉帳明細', Valid::any('明細項目')),
    ]);

    $settlement = transaction(static function () use ($id, $user, $transfers, $ledger) {
      // 標記所有未結算開銷
      $unsettled = Expense::where('ledgerId', $id)->where('isSettled', Expense::IS_SETTLED_NO)->all();
      foreach ($unsettled as $expense) {
        $expense->isSettled = Expense::IS_SETTLED_YES;
        $expense->save() ?? error('更新開銷失敗');
      }

      return Settlement::create([
        'ledgerId'        => $id,
        'settledByUserId' => $user->id,
        'transfers'       => $transfers,
        'currencySymbol'  => self::_currencySymbol($ledger->currency),
      ]) ?? error('建立結算紀錄失敗');
    });

    return ['settlement' => [
      'id'              => $settlement->id,
      'settledByUserId' => $user->id,
      'transfers'       => $settlement->transfers,
      'currencySymbol'  => $settlement->currencySymbol,
      'createAt'        => $settlement->createAt->format('Y-m-d H:i:s'),
    ]];
  }

  // MARK: - Private

  private static function _findLedgerAsMember(int $ledgerId, int $userId): LedgerModel {
    $ledger = LedgerModel::one('id', $ledgerId);
    if (!$ledger) {
      notFound('帳本不存在');
    }

    $member = LedgerMember::where('ledgerId', $ledgerId)->where('userId', $userId)->one();
    if (!$member) {
      error('你不是此帳本的成員', 403);
    }

    return $ledger;
  }

  private static function _buildLedgerResponse(LedgerModel $ledger, User $user): array {
    $members    = LedgerMember::where('ledgerId', $ledger->id)->all();
    $categories = Category::where('ledgerId', $ledger->id)->order('sort ASC')->all();

    $userIds = array_map(static function ($member) {
      return $member->userId;
    }, $members);

    $users   = User::where('id', $userIds)->all();
    $userMap = [];
    foreach ($users as $userItem) {
      $userMap[$userItem->id] = $userItem;
    }

    return [
      'id'         => $ledger->id,
      'name'       => $ledger->name,
      'type'       => $ledger->type,
      'currency'   => $ledger->currency,
      'inviteCode' => $ledger->inviteCode,
      'members'    => array_values(array_map(static function ($member) use ($user, $userMap) {
        $memberUser = $userMap[$member->userId] ?? null;
        return [
          'id'            => $member->id,
          'userId'        => $member->userId,
          'name'          => $memberUser ? $memberUser->name : '',
          'role'          => $member->role,
          'isCurrentUser' => $member->userId == $user->id,
        ];
      }, $members)),
      'categories' => array_map(static function ($category) {
        return State::formatCategory($category);
      }, $categories),
    ];
  }

  private static function _deleteLedgerCompletely(int $ledgerId): void {
    transaction(static function () use ($ledgerId) {
      $expenses = Expense::where('ledgerId', $ledgerId)->all();
      foreach ($expenses as $expense) {
        $expense->delete() ?? error('刪除開銷失敗');
      }

      $categories = Category::where('ledgerId', $ledgerId)->all();
      foreach ($categories as $category) {
        $category->delete() ?? error('刪除分類失敗');
      }

      $recurringExpenses = RecurringExpense::where('ledgerId', $ledgerId)->all();
      foreach ($recurringExpenses as $recurring) {
        $recurring->delete() ?? error('刪除固定開銷失敗');
      }

      $settlements = Settlement::where('ledgerId', $ledgerId)->all();
      foreach ($settlements as $settlement) {
        $settlement->delete() ?? error('刪除結算紀錄失敗');
      }

      $ledger = LedgerModel::one('id', $ledgerId);
      if ($ledger) {
        $ledger->delete() ?? error('刪除帳本失敗');
      }

      return true;
    });
  }

  private static function _currencySymbol(string $code): string {
    $symbols = [
      'TWD' => 'NT$',
      'USD' => '$',
      'EUR' => '€',
      'JPY' => '¥',
      'GBP' => '£',
      'KRW' => '₩',
      'CNY' => '¥',
      'HKD' => 'HK$',
      'SGD' => 'S$',
      'AUD' => 'A$',
      'CAD' => 'C$',
      'THB' => '฿',
      'VND' => '₫',
      'MYR' => 'RM',
    ];
    return $symbols[$code] ?? $code;
  }
}

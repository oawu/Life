<?php

namespace App\Controller\Api;

use \Valid;
use \Request\Payload;
use \App\Model\User;
use \App\Model\Ledger;
use \App\Model\LedgerMember;
use \App\Model\Category;
use \App\Model\Expense;
use \App\Model\RecurringExpense;
use \App\Model\Settlement;

class Sync {
  public function push() {
    $user = User::current();

    list(
      'ledgers' => $ledgers,
    ) = Valid::check(Payload::getJson(), [
      'ledgers' => Valid::array('帳本', Valid::any('帳本項目')),
    ]);

    $mappings = [
      'ledgers'           => [],
      'categories'        => [],
      'expenses'          => [],
      'recurringExpenses' => [],
    ];

    foreach ($ledgers as $ledgerData) {
      $localId = $ledgerData['localId'] ?? '';
      $type    = $ledgerData['type'] ?? Ledger::TYPE_PERSONAL;

      // 用 localId 查找已存在的帳本
      $ledger = self::_findLedgerByLocalId($user->id, $localId);

      if (!$ledger) {
        // 建立新帳本 + owner 成員
        $inviteCode = $type === Ledger::TYPE_GROUP ? Ledger::generateInviteCode() : null;

        $ledgerParam = [
          'localId'         => $localId ?: null,
          'name'            => $ledgerData['name'] ?? '',
          'type'            => $type,
          'currency'        => $ledgerData['currency'] ?? 'TWD',
          'inviteCode'      => $inviteCode,
          'createdByUserId' => $user->id,
        ];

        $ledger = transaction(static function () use ($ledgerParam, $user) {
          $ledger = Ledger::create($ledgerParam) ?? error('建立帳本失敗');

          LedgerMember::create([
            'ledgerId' => $ledger->id,
            'userId'   => $user->id,
            'role'     => LedgerMember::ROLE_OWNER,
          ]) ?? error('建立成員失敗');

          return $ledger;
        });
      } else {
        // 更新帳本
        $ledger->name     = $ledgerData['name'] ?? $ledger->name;
        $ledger->currency = $ledgerData['currency'] ?? $ledger->currency;

        transaction(static function () use ($ledger) {
          return $ledger->save();
        });
      }

      $mappings['ledgers'][] = [
        'localId'  => $localId,
        'serverId' => $ledger->id,
      ];

      // Upsert Categories
      $categories = $ledgerData['categories'] ?? [];
      foreach ($categories as $categoryData) {
        $catLocalId = $categoryData['localId'] ?? '';
        $category = Category::where('ledgerId', $ledger->id)->where('localId', $catLocalId)->one();

        if (!$category) {
          $catParam = [
            'localId'         => $catLocalId,
            'ledgerId'        => $ledger->id,
            'name'            => $categoryData['name'] ?? '',
            'icon'            => $categoryData['icon'] ?? '',
            'color'           => $categoryData['color'] ?? '#007AFF',
            'sort'            => $categoryData['sort'] ?? 0,
            'isSystemDefault' => ($categoryData['isSystemDefault'] ?? false) ? Category::IS_SYSTEM_DEFAULT_YES : Category::IS_SYSTEM_DEFAULT_NO,
          ];

          $category = transaction(static function () use ($catParam) {
            return Category::create($catParam) ?? error('建立分類失敗');
          });
        } else {
          $category->name  = $categoryData['name'] ?? $category->name;
          $category->icon  = $categoryData['icon'] ?? $category->icon;
          $category->color = $categoryData['color'] ?? $category->color;
          $category->sort  = $categoryData['sort'] ?? $category->sort;

          transaction(static function () use ($category) {
            return $category->save();
          });
        }

        $mappings['categories'][] = [
          'localId'  => $catLocalId,
          'serverId' => $category->id,
        ];
      }

      // Upsert Expenses
      $expenses = $ledgerData['expenses'] ?? [];
      foreach ($expenses as $expenseData) {
        $expLocalId = $expenseData['localId'] ?? '';
        $expense = Expense::where('ledgerId', $ledger->id)->where('localId', $expLocalId)->one();

        $categoryId   = self::_resolveCategoryId($ledger->id, $expenseData['categoryLocalId'] ?? '');
        $paidByUserId = $expenseData['paidByUserId'] ?? null;

        if (!$expense) {
          $expParam = [
            'localId'         => $expLocalId,
            'ledgerId'        => $ledger->id,
            'categoryId'      => $categoryId,
            'amount'          => (int)($expenseData['amount'] ?? 0),
            'memo'            => $expenseData['memo'] ?? '',
            'date'            => $expenseData['date'] ?? date('Y-m-d H:i:s'),
            'latitude'        => $expenseData['latitude'] ?? null,
            'longitude'       => $expenseData['longitude'] ?? null,
            'address'         => $expenseData['address'] ?? null,
            'isSettled'       => Expense::IS_SETTLED_NO,
            'paidByUserId'    => $paidByUserId,
            'createdByUserId' => $user->id,
          ];

          $expense = transaction(static function () use ($expParam) {
            return Expense::create($expParam) ?? error('建立開銷失敗');
          });
        } else {
          $expense->categoryId = $categoryId;
          $expense->amount     = (int)($expenseData['amount'] ?? $expense->amount);
          $expense->memo       = $expenseData['memo'] ?? $expense->memo;
          $expense->date       = $expenseData['date'] ?? $expense->date;
          $expense->latitude   = $expenseData['latitude'] ?? null;
          $expense->longitude  = $expenseData['longitude'] ?? null;
          $expense->address    = $expenseData['address'] ?? null;

          transaction(static function () use ($expense) {
            return $expense->save();
          });
        }

        $mappings['expenses'][] = [
          'localId'  => $expLocalId,
          'serverId' => $expense->id,
        ];
      }

      // Upsert Recurring Expenses
      $recurringExpenses = $ledgerData['recurringExpenses'] ?? [];
      foreach ($recurringExpenses as $recData) {
        $recLocalId = $recData['localId'] ?? '';
        $recurring = RecurringExpense::where('ledgerId', $ledger->id)->where('localId', $recLocalId)->one();

        $categoryId = self::_resolveCategoryId($ledger->id, $recData['categoryLocalId'] ?? '');

        if (!$recurring) {
          $recParam = [
            'localId'         => $recLocalId,
            'ledgerId'        => $ledger->id,
            'categoryId'      => $categoryId,
            'amount'          => (int)($recData['amount'] ?? 0),
            'frequencyType'   => $recData['frequencyType'] ?? '',
            'frequencyValue'  => $recData['frequencyValue'] ?? null,
            'memo'            => $recData['memo'] ?? '',
            'isEnabled'       => ($recData['isEnabled'] ?? true) ? RecurringExpense::IS_ENABLED_YES : RecurringExpense::IS_ENABLED_NO,
            'latitude'        => $recData['latitude'] ?? null,
            'longitude'       => $recData['longitude'] ?? null,
            'address'         => $recData['address'] ?? null,
            'paidByUserId'    => $recData['paidByUserId'] ?? null,
            'createdByUserId' => $user->id,
          ];

          $recurring = transaction(static function () use ($recParam) {
            return RecurringExpense::create($recParam) ?? error('建立固定開銷失敗');
          });
        } else {
          $recurring->categoryId     = $categoryId;
          $recurring->amount         = (int)($recData['amount'] ?? $recurring->amount);
          $recurring->frequencyType  = $recData['frequencyType'] ?? $recurring->frequencyType;
          $recurring->frequencyValue = $recData['frequencyValue'] ?? $recurring->frequencyValue;
          $recurring->memo           = $recData['memo'] ?? $recurring->memo;
          $recurring->isEnabled      = ($recData['isEnabled'] ?? ($recurring->isEnabled == RecurringExpense::IS_ENABLED_YES))
            ? RecurringExpense::IS_ENABLED_YES
            : RecurringExpense::IS_ENABLED_NO;
          $recurring->latitude       = $recData['latitude'] ?? null;
          $recurring->longitude      = $recData['longitude'] ?? null;
          $recurring->address        = $recData['address'] ?? null;

          transaction(static function () use ($recurring) {
            return $recurring->save();
          });
        }

        $mappings['recurringExpenses'][] = [
          'localId'  => $recLocalId,
          'serverId' => $recurring->id,
        ];
      }

      // 刪除標記為 deleted 的資料
      self::_deleteByLocalIds(Expense::class, $ledger->id, $ledgerData['deletedExpenseLocalIds'] ?? []);
      self::_deleteByLocalIds(Category::class, $ledger->id, $ledgerData['deletedCategoryLocalIds'] ?? []);
      self::_deleteByLocalIds(RecurringExpense::class, $ledger->id, $ledgerData['deletedRecurringLocalIds'] ?? []);
    }

    return ['mappings' => $mappings];
  }

  public function pull() {
    $user = User::current();

    list(
      'lastSyncAt' => $lastSyncAt,
    ) = Valid::check(Payload::getJson(), [
      'lastSyncAt' => Valid::string_('最後同步時間')->nullOrNoKey(null),
    ]);

    // 取得用戶所屬的帳本 ID
    $memberRecords = LedgerMember::where('userId', $user->id)->all();
    $ledgerIds = array_map(static function ($member) {
      return $member->ledgerId;
    }, $memberRecords);

    if (empty($ledgerIds)) {
      return [
        'ledgers'    => [],
        'serverTime' => date('Y-m-d H:i:s'),
      ];
    }

    // 預先載入所有相關的 User（避免 N+1）
    $allMembers = LedgerMember::where('ledgerId', $ledgerIds)->all();
    $userIds = array_unique(array_map(static function ($member) {
      return $member->userId;
    }, $allMembers));
    $users = User::where('id', $userIds)->all();
    $userMap = [];
    foreach ($users as $userItem) {
      $userMap[$userItem->id] = $userItem;
    }

    // 取得帳本
    $ledgers = Ledger::where('id', $ledgerIds)->all();

    $result = [];
    foreach ($ledgers as $ledger) {
      $categories = Category::where('ledgerId', $ledger->id)->order('sort ASC')->all();
      $members    = array_filter($allMembers, static function ($member) use ($ledger) {
        return $member->ledgerId == $ledger->id;
      });

      // 根據 lastSyncAt 過濾開銷
      $expenseQuery = Expense::where('ledgerId', $ledger->id);
      if ($lastSyncAt) {
        $expenseQuery = $expenseQuery->where('updateAt >=', $lastSyncAt);
      }
      $expenses = $expenseQuery->order('date DESC')->all();

      // 固定開銷
      $recurringQuery = RecurringExpense::where('ledgerId', $ledger->id);
      if ($lastSyncAt) {
        $recurringQuery = $recurringQuery->where('updateAt >=', $lastSyncAt);
      }
      $recurringExpenses = $recurringQuery->all();

      // 結算紀錄
      $settlementQuery = Settlement::where('ledgerId', $ledger->id);
      if ($lastSyncAt) {
        $settlementQuery = $settlementQuery->where('createAt >=', $lastSyncAt);
      }
      $settlements = $settlementQuery->order('createAt DESC')->all();

      $result[] = [
        'serverId'   => $ledger->id,
        'name'       => $ledger->name,
        'type'       => $ledger->type,
        'currency'   => $ledger->currency,
        'inviteCode' => $ledger->inviteCode,
        'members'    => array_values(array_map(static function ($member) use ($user, $userMap) {
          $memberUser = $userMap[$member->userId] ?? null;
          return [
            'serverId'      => $member->id,
            'userId'        => $member->userId,
            'name'          => $memberUser ? $memberUser->name : '',
            'role'          => $member->role,
            'isCurrentUser' => $member->userId == $user->id,
          ];
        }, $members)),
        'categories' => array_map(static function ($category) {
          return [
            'serverId'        => $category->id,
            'localId'         => $category->localId,
            'name'            => $category->name,
            'icon'            => $category->icon,
            'color'           => $category->color,
            'sort'            => $category->sort,
            'isSystemDefault' => $category->isSystemDefault == Category::IS_SYSTEM_DEFAULT_YES,
          ];
        }, $categories),
        'expenses' => array_map(static function ($expense) {
          return [
            'serverId'        => $expense->id,
            'localId'         => $expense->localId,
            'categoryId'      => $expense->categoryId,
            'amount'          => $expense->amount,
            'memo'            => $expense->memo,
            'date'            => $expense->date->format('Y-m-d H:i:s'),
            'latitude'        => $expense->latitude,
            'longitude'       => $expense->longitude,
            'address'         => $expense->address,
            'isSettled'       => $expense->isSettled == Expense::IS_SETTLED_YES,
            'paidByUserId'    => $expense->paidByUserId,
            'createdByUserId' => $expense->createdByUserId,
          ];
        }, $expenses),
        'recurringExpenses' => array_map(static function ($recurring) {
          return [
            'serverId'       => $recurring->id,
            'localId'        => $recurring->localId,
            'categoryId'     => $recurring->categoryId,
            'amount'         => $recurring->amount,
            'frequencyType'  => $recurring->frequencyType,
            'frequencyValue' => $recurring->frequencyValue,
            'memo'           => $recurring->memo,
            'isEnabled'      => $recurring->isEnabled == RecurringExpense::IS_ENABLED_YES,
            'paidByUserId'   => $recurring->paidByUserId,
          ];
        }, $recurringExpenses),
        'settlements' => array_map(static function ($settlement) {
          return [
            'serverId'        => $settlement->id,
            'settledByUserId' => $settlement->settledByUserId,
            'transfers'       => $settlement->transfers,
            'currencySymbol'  => $settlement->currencySymbol,
            'createAt'        => $settlement->createAt->format('Y-m-d H:i:s'),
          ];
        }, $settlements),
      ];
    }

    return [
      'ledgers'    => $result,
      'serverTime' => date('Y-m-d H:i:s'),
    ];
  }

  // MARK: - Private

  private static function _findLedgerByLocalId(int $userId, string $localId): ?Ledger {
    if ($localId === '') {
      return null;
    }

    return Ledger::where('createdByUserId', $userId)->where('localId', $localId)->one();
  }

  private static function _resolveCategoryId(int $ledgerId, string $categoryLocalId): int {
    if ($categoryLocalId === '') {
      return 0;
    }

    $category = Category::where('ledgerId', $ledgerId)->where('localId', $categoryLocalId)->one();

    if ($category) {
      return $category->id;
    }

    return 0;
  }

  private static function _deleteByLocalIds(string $modelClass, int $ledgerId, array $localIds): void {
    if (empty($localIds)) {
      return;
    }

    $records = [];
    foreach ($localIds as $localId) {
      $record = $modelClass::where('ledgerId', $ledgerId)->where('localId', $localId)->one();
      if ($record) {
        $records[] = $record;
      }
    }

    if (empty($records)) {
      return;
    }

    transaction(static function () use ($records) {
      foreach ($records as $record) {
        $record->delete() ?? error('刪除失敗');
      }
      return true;
    });
  }
}

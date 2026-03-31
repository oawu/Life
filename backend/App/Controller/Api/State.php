<?php

namespace App\Controller\Api;

use \App\Model\User;
use \App\Model\Ledger;
use \App\Model\LedgerMember;
use \App\Model\Category;
use \App\Model\Expense;
use \App\Model\RecurringExpense;
use \App\Model\Settlement;

class State {
  public function index() {
    $user = User::current();

    $memberRecords = LedgerMember::where('userId', $user->id)->all();
    $ledgerIds = array_map(static function ($member) {
      return $member->ledgerId;
    }, $memberRecords);

    if (empty($ledgerIds)) {
      return ['ledgers' => []];
    }

    // 預先載入所有相關 User（避免 N+1）
    $allMembers = LedgerMember::where('ledgerId', $ledgerIds)->all();
    $userIds = array_unique(array_map(static function ($member) {
      return $member->userId;
    }, $allMembers));

    $users   = User::where('id', $userIds)->all();
    $userMap = [];
    foreach ($users as $userItem) {
      $userMap[$userItem->id] = $userItem;
    }

    $ledgers = Ledger::where('id', $ledgerIds)->all();

    $result = [];
    foreach ($ledgers as $ledger) {
      $result[] = self::_buildFullLedger($ledger, $allMembers, $userMap, $user);
    }

    return ['ledgers' => $result];
  }

  // MARK: - Static Helpers

  public static function buildFullState(): array {
    $state = new self();
    return $state->index();
  }

  public static function buildFullStateWithoutExpenses(): array {
    $user = User::current();

    $memberRecords = LedgerMember::where('userId', $user->id)->all();
    $ledgerIds = array_map(fn($member) => $member->ledgerId, $memberRecords);

    if (empty($ledgerIds)) {
      return ['ledgers' => []];
    }

    $allMembers = LedgerMember::where('ledgerId', $ledgerIds)->all();
    $userIds = array_unique(array_map(fn($member) => $member->userId, $allMembers));

    $users   = User::where('id', $userIds)->all();
    $userMap = [];
    foreach ($users as $userItem) {
      $userMap[$userItem->id] = $userItem;
    }

    $ledgers = Ledger::where('id', $ledgerIds)->all();

    $result = [];
    foreach ($ledgers as $ledger) {
      $result[] = self::_buildFullLedgerWithoutExpenses($ledger, $allMembers, $userMap, $user);
    }

    return ['ledgers' => $result];
  }

  private static function _buildFullLedger(Ledger $ledger, array $allMembers, array $userMap, User $user): array {
    $members = array_filter($allMembers, static function ($member) use ($ledger) {
      return $member->ledgerId == $ledger->id;
    });

    $categories        = Category::where('ledgerId', $ledger->id)->order('sort ASC')->all();
    $expenses          = Expense::where('ledgerId', $ledger->id)->order('date DESC')->all();
    $recurringExpenses = RecurringExpense::where('ledgerId', $ledger->id)->all();
    $settlements       = Settlement::where('ledgerId', $ledger->id)->order('createAt DESC')->all();

    return [
      'id'         => $ledger->id,
      'name'       => $ledger->name,
      'type'       => $ledger->type,
      'currency'   => $ledger->currency,
      'version'    => $ledger->version,
      'inviteCode' => $ledger->type === Ledger::TYPE_GROUP ? $ledger->inviteCode() : null,
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
      'categories'        => array_map(fn($category) => self::formatCategory($category), $categories),
      'expenses'          => array_map(fn($expense) => self::_formatExpense($expense), $expenses),
      'recurringExpenses' => array_map(fn($recurring) => self::_formatRecurringExpense($recurring), $recurringExpenses),
      'settlements'       => array_map(fn($settlement) => self::_formatSettlement($settlement), $settlements),
    ];
  }

  private static function _buildFullLedgerWithoutExpenses(Ledger $ledger, array $allMembers, array $userMap, User $user): array {
    $members = array_filter($allMembers, static function ($member) use ($ledger) {
      return $member->ledgerId == $ledger->id;
    });

    $categories        = Category::where('ledgerId', $ledger->id)->order('sort ASC')->all();
    $recurringExpenses = RecurringExpense::where('ledgerId', $ledger->id)->all();
    $settlements       = Settlement::where('ledgerId', $ledger->id)->order('createAt DESC')->all();

    return [
      'id'         => $ledger->id,
      'name'       => $ledger->name,
      'type'       => $ledger->type,
      'currency'   => $ledger->currency,
      'version'    => $ledger->version,
      'inviteCode' => $ledger->type === Ledger::TYPE_GROUP ? $ledger->inviteCode() : null,
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
      'categories'        => array_map(fn($category) => self::formatCategory($category), $categories),
      'recurringExpenses' => array_map(fn($recurring) => self::_formatRecurringExpense($recurring), $recurringExpenses),
      'settlements'       => array_map(fn($settlement) => self::_formatSettlement($settlement), $settlements),
    ];
  }

  public static function formatExpense(Expense $expense): array {
    return self::_formatExpense($expense);
  }

  public static function formatRecurringExpense(RecurringExpense $recurring): array {
    return self::_formatRecurringExpense($recurring);
  }

  public static function formatSettlement(Settlement $settlement): array {
    return self::_formatSettlement($settlement);
  }

  public static function formatCategory(Category $category): array {
    return [
      'id'    => $category->id,
      'key'   => $category->key,
      'name'  => $category->name,
      'icon'  => $category->icon,
      'color' => $category->color,
      'sort'  => $category->sort,
    ];
  }

  private static function _formatExpense(Expense $expense): array {
    return [
      'id'              => $expense->id,
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
      'version'         => $expense->version,
    ];
  }

  private static function _formatSettlement(Settlement $settlement): array {
    return [
      'id'              => $settlement->id,
      'settledByUserId' => $settlement->settledByUserId,
      'transfers'       => $settlement->transfers,
      'currencySymbol'  => $settlement->currencySymbol,
      'createAt'        => $settlement->createAt->format('Y-m-d H:i:s'),
    ];
  }

  private static function _formatRecurringExpense(RecurringExpense $recurring): array {
    return [
      'id'                => $recurring->id,
      'categoryId'        => $recurring->categoryId,
      'amount'            => $recurring->amount,
      'frequencyType'     => $recurring->frequencyType,
      'frequencyValue'    => $recurring->frequencyValue,
      'memo'              => $recurring->memo,
      'isEnabled'         => $recurring->isEnabled == RecurringExpense::IS_ENABLED_YES,
      'latitude'          => $recurring->latitude,
      'longitude'         => $recurring->longitude,
      'address'           => $recurring->address,
      'paidByUserId'      => $recurring->paidByUserId,
      'lastTriggeredDate' => $recurring->lastTriggeredDate->getValue()
        ? $recurring->lastTriggeredDate->format('Y-m-d')
        : null,
    ];
  }
}

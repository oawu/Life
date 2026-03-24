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
        return [
          'id'    => $category->id,
          'key'   => $category->key,
          'name'  => $category->name,
          'icon'  => $category->icon,
          'color' => $category->color,
          'sort'  => (int)$category->sort,
        ];
      }, $categories),
      'expenses' => array_map(static function ($expense) {
        return self::_formatExpense($expense);
      }, $expenses),
      'recurringExpenses' => array_map(static function ($recurring) {
        return self::_formatRecurringExpense($recurring);
      }, $recurringExpenses),
      'settlements' => array_map(static function ($settlement) {
        return [
          'id'              => $settlement->id,
          'settledByUserId' => $settlement->settledByUserId,
          'transfers'       => $settlement->transfers,
          'currencySymbol'  => $settlement->currencySymbol,
          'createAt'        => $settlement->createAt->format('Y-m-d H:i:s'),
        ];
      }, $settlements),
    ];
  }

  public static function formatExpense(Expense $expense): array {
    return self::_formatExpense($expense);
  }

  public static function formatRecurringExpense(RecurringExpense $recurring): array {
    return self::_formatRecurringExpense($recurring);
  }

  public static function formatCategory(Category $category): array {
    return [
      'id'    => $category->id,
      'key'   => $category->key,
      'name'  => $category->name,
      'icon'  => $category->icon,
      'color' => $category->color,
      'sort'  => (int)$category->sort,
    ];
  }

  private static function _formatExpense(Expense $expense): array {
    return [
      'id'              => $expense->id,
      'categoryId'      => $expense->categoryId !== null ? (int)$expense->categoryId : null,
      'amount'          => (int)$expense->amount,
      'memo'            => $expense->memo,
      'date'            => $expense->date->format('Y-m-d H:i:s'),
      'latitude'        => $expense->latitude !== null ? (float)$expense->latitude : null,
      'longitude'       => $expense->longitude !== null ? (float)$expense->longitude : null,
      'address'         => $expense->address,
      'isSettled'       => $expense->isSettled == Expense::IS_SETTLED_YES,
      'paidByUserId'    => $expense->paidByUserId !== null ? (int)$expense->paidByUserId : null,
      'createdByUserId' => (int)$expense->createdByUserId,
    ];
  }

  private static function _formatRecurringExpense(RecurringExpense $recurring): array {
    return [
      'id'             => $recurring->id,
      'categoryId'     => $recurring->categoryId !== null ? (int)$recurring->categoryId : null,
      'amount'         => (int)$recurring->amount,
      'frequencyType'  => $recurring->frequencyType,
      'frequencyValue' => $recurring->frequencyValue,
      'memo'           => $recurring->memo,
      'isEnabled'      => $recurring->isEnabled == RecurringExpense::IS_ENABLED_YES,
      'latitude'       => $recurring->latitude !== null ? (float)$recurring->latitude : null,
      'longitude'      => $recurring->longitude !== null ? (float)$recurring->longitude : null,
      'address'        => $recurring->address,
      'paidByUserId'   => $recurring->paidByUserId !== null ? (int)$recurring->paidByUserId : null,
    ];
  }
}

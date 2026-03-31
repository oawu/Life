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

class Manifest {
  public function index() {
    $user = User::current();

    $memberRecords = LedgerMember::where('userId', $user->id)->all();
    $ledgerIds = array_map(fn($member) => $member->ledgerId, $memberRecords);

    if (empty($ledgerIds)) {
      return ['ledgers' => (object)[]];
    }

    // 預先載入所有相關 User（避免 N+1）
    $allMembers = LedgerMember::where('ledgerId', $ledgerIds)->all();
    $userIds = array_unique(array_map(fn($member) => $member->userId, $allMembers));

    $users   = User::where('id', $userIds)->all();
    $userMap = [];
    foreach ($users as $userItem) {
      $userMap[$userItem->id] = $userItem;
    }

    $ledgers            = Ledger::where('id', $ledgerIds)->all();
    $allExpenses        = Expense::select('id', 'version', 'ledgerId')->where('ledgerId', $ledgerIds)->all();
    $allCategories      = Category::where('ledgerId', $ledgerIds)->order('sort ASC')->all();
    $allRecurring       = RecurringExpense::where('ledgerId', $ledgerIds)->all();
    $allSettlements     = Settlement::where('ledgerId', $ledgerIds)->order('createAt DESC')->all();

    $result = [];
    foreach ($ledgers as $ledger) {
      $members = array_filter($allMembers, fn($member) => $member->ledgerId == $ledger->id);

      // 組裝 expense manifest 字串
      $ledgerExpenses = array_filter($allExpenses, fn($expense) => $expense->ledgerId == $ledger->id);
      $manifestParts = array_map(fn($expense) => $expense->id . '-' . $expense->version, $ledgerExpenses);
      $manifestStr = implode('|', $manifestParts);

      $categories = array_filter($allCategories, fn($category) => $category->ledgerId == $ledger->id);
      $recurringExpenses = array_filter($allRecurring, fn($recurring) => $recurring->ledgerId == $ledger->id);
      $settlements = array_filter($allSettlements, fn($settlement) => $settlement->ledgerId == $ledger->id);

      $result[(string)$ledger->id] = [
        'version'    => $ledger->version,
        'expenses'   => $manifestStr,
        'name'       => $ledger->name,
        'type'       => $ledger->type,
        'currency'   => $ledger->currency,
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
        'categories'        => array_values(array_map(fn($category) => State::formatCategory($category), $categories)),
        'recurringExpenses' => array_values(array_map(fn($recurring) => State::formatRecurringExpense($recurring), $recurringExpenses)),
        'settlements'       => array_values(array_map(fn($settlement) => State::formatSettlement($settlement), $settlements)),
      ];
    }

    return ['ledgers' => $result];
  }

  public function fetch(int $id) {
    $user = User::current();

    $ledger = Ledger::one('id', $id);

    if (!$ledger) {
      notFound('帳本不存在');
    }

    $member = LedgerMember::where('ledgerId', $id)->where('userId', $user->id)->one();

    if (!$member) {
      error('你不是此帳本的成員', 403);
    }

    list(
      'ids' => $ids,
    ) = Valid::check(Payload::getJson(), [
      'ids' => Valid::array('開銷 ID', Valid::uInt('ID')),
    ]);

    if (count($ids) > 200) {
      error('單次最多取得 200 筆', 400);
    }

    $expenses = Expense::where('ledgerId', $id)->where('id', $ids)->all();

    return ['expenses' => array_map(fn($expense) => State::formatExpense($expense), $expenses)];
  }
}

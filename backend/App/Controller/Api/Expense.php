<?php

namespace App\Controller\Api;

use \Valid;
use \Request\Payload;
use \App\Model\User;
use \App\Model\Ledger;
use \App\Model\LedgerMember;
use \App\Model\Expense as ExpenseModel;

class Expense {
  public function create(int $id) {
    $user   = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    $data    = self::_validateExpenseData();
    $expense = self::_createExpense($ledger, $user, $data);

    return ['expense' => State::formatExpense($expense)];
  }

  public function batch(int $id) {
    $user   = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    list(
      'expenses' => $expensesData,
    ) = Valid::check(Payload::getJson(), [
      'expenses' => Valid::array('開銷', Valid::any('開銷項目')),
    ]);

    // 驗證每筆開銷
    $validatedItems = [];
    foreach ($expensesData as $index => $data) {
      if (!is_array($data)) {
        error("第 {$index} 筆開銷格式錯誤", 400);
      }

      if (!isset($data['amount']) || !is_numeric($data['amount']) || (int)$data['amount'] <= 0) {
        error("第 {$index} 筆開銷金額無效", 400);
      }

      $validatedItems[] = [
        'ledgerId'        => $ledger->id,
        'categoryId'      => isset($data['categoryId']) ? (int)$data['categoryId'] : null,
        'amount'          => (int)$data['amount'],
        'memo'            => isset($data['memo']) && is_string($data['memo']) ? mb_substr($data['memo'], 0, 200) : '',
        'date'            => isset($data['date']) && is_string($data['date']) ? $data['date'] : date('Y-m-d H:i:s'),
        'latitude'        => isset($data['latitude']) && is_numeric($data['latitude']) ? $data['latitude'] : null,
        'longitude'       => isset($data['longitude']) && is_numeric($data['longitude']) ? $data['longitude'] : null,
        'address'         => isset($data['address']) && is_string($data['address']) ? mb_substr($data['address'], 0, 200) : null,
        'isSettled'       => ExpenseModel::IS_SETTLED_NO,
        'paidByUserId'    => isset($data['paidByUserId']) && is_numeric($data['paidByUserId']) ? (int)$data['paidByUserId'] : null,
        'createdByUserId' => $user->id,
      ];
    }

    $expenses = transaction(static function () use ($validatedItems) {
      $result = [];

      foreach ($validatedItems as $param) {
        $expense = ExpenseModel::create($param) ?? error('建立開銷失敗');
        $result[] = $expense;
      }

      return $result;
    });

    return ['expenses' => array_map(fn($expense) => State::formatExpense($expense), $expenses)];
  }

  public function update(int $id) {
    $user    = User::current();
    $expense = ExpenseModel::one('id', $id);

    if (!$expense) {
      notFound('開銷不存在');
    }

    self::_findLedgerAsMember($expense->ledgerId, $user->id);

    list(
      'categoryId' => $categoryId,
      'amount'     => $amount,
      'memo'       => $memo,
      'date'       => $date,
      'latitude'   => $latitude,
      'longitude'  => $longitude,
      'address'    => $address,
    ) = Valid::check(Payload::getJson(), [
      'categoryId' => Valid::uInt_('分類 ID')->nullOrNoKey(false),
      'amount'     => Valid::uInt_('金額')->nullOrNoKey(null),
      'memo'       => Valid::string_('備註')->max(200)->nullOrNoKey(null),
      'date'       => Valid::string_('日期')->nullOrNoKey(null),
      'latitude'   => Valid::string_('緯度')->nullOrNoKey(false),
      'longitude'  => Valid::string_('經度')->nullOrNoKey(false),
      'address'    => Valid::string_('地址')->max(200)->nullOrNoKey(false),
    ]);

    if ($categoryId !== false) {
      $expense->categoryId = $categoryId;
    }

    if ($amount !== null) {
      $expense->amount = $amount;
    }

    if ($memo !== null) {
      $expense->memo = $memo;
    }

    if ($date !== null) {
      $expense->date = $date;
    }

    if ($latitude !== false) {
      $expense->latitude = $latitude;
    }

    if ($longitude !== false) {
      $expense->longitude = $longitude;
    }

    if ($address !== false) {
      $expense->address = $address;
    }

    transaction(fn() => $expense->save());

    return ['expense' => State::formatExpense($expense)];
  }

  public function destroy(int $id) {
    $user    = User::current();
    $expense = ExpenseModel::one('id', $id);

    if (!$expense) {
      notFound('開銷不存在');
    }

    self::_findLedgerAsMember($expense->ledgerId, $user->id);

    transaction(fn() => $expense->delete());

    return ['success' => true];
  }

  // MARK: - Private

  private static function _validateExpenseData(): array {
    return Valid::check(Payload::getJson(), [
      'categoryId'    => Valid::uInt_('分類 ID')->nullOrNoKey(null),
      'amount'        => Valid::uInt('金額'),
      'memo'          => Valid::string_('備註')->max(200)->nullOrNoKey(''),
      'date'          => Valid::string_('日期')->nullOrNoKey(date('Y-m-d H:i:s')),
      'latitude'      => Valid::string_('緯度')->nullOrNoKey(null),
      'longitude'     => Valid::string_('經度')->nullOrNoKey(null),
      'address'       => Valid::string_('地址')->max(200)->nullOrNoKey(null),
      'paidByUserId'  => Valid::uInt_('付款人')->nullOrNoKey(null),
    ]);
  }

  private static function _createExpense(Ledger $ledger, User $user, array $data): ExpenseModel {
    $param = [
      'ledgerId'        => $ledger->id,
      'categoryId'      => $data['categoryId'],
      'amount'          => (int)$data['amount'],
      'memo'            => $data['memo'],
      'date'            => $data['date'],
      'latitude'        => $data['latitude'],
      'longitude'       => $data['longitude'],
      'address'         => $data['address'],
      'isSettled'       => ExpenseModel::IS_SETTLED_NO,
      'paidByUserId'    => $data['paidByUserId'],
      'createdByUserId' => $user->id,
    ];

    return transaction(fn() => ExpenseModel::create($param) ?? error('建立開銷失敗'));
  }

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

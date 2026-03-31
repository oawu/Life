<?php

namespace App\Controller\Api;

use \Valid;
use \Request\Payload;
use \App\Model\User;
use \App\Model\Ledger;
use \App\Model\LedgerMember;
use \App\Model\RecurringExpense as RecurringExpenseModel;

class RecurringExpense {
  public function create(int $id) {
    $user   = User::current();
    $ledger = self::_findLedgerAsMember($id, $user->id);

    list(
      'categoryId'     => $categoryId,
      'amount'         => $amount,
      'frequencyType'  => $frequencyType,
      'frequencyValue' => $frequencyValue,
      'memo'           => $memo,
      'latitude'       => $latitude,
      'longitude'      => $longitude,
      'address'        => $address,
      'paidByUserId'   => $paidByUserId,
    ) = Valid::check(Payload::getJson(), [
      'categoryId'     => Valid::uInt_('分類 ID')->nullOrNoKey(null),
      'amount'         => Valid::uInt('金額'),
      'frequencyType'  => Valid::enum('頻率類型', ['daily', 'weekly', 'monthly', 'yearly']),
      'frequencyValue' => Valid::any_('頻率參數')->nullOrNoKey(null),
      'memo'           => Valid::string_('備註')->max(200)->nullOrNoKey(''),
      'latitude'       => Valid::string_('緯度')->nullOrNoKey(null),
      'longitude'      => Valid::string_('經度')->nullOrNoKey(null),
      'address'        => Valid::string_('地址')->max(200)->nullOrNoKey(null),
      'paidByUserId'   => Valid::uInt_('付款人')->nullOrNoKey(null),
    ]);

    $param = [
      'ledgerId'        => $ledger->id,
      'categoryId'      => $categoryId,
      'amount'          => $amount,
      'frequencyType'   => $frequencyType,
      'frequencyValue'  => $frequencyValue,
      'memo'            => $memo,
      'isEnabled'       => RecurringExpenseModel::IS_ENABLED_YES,
      'latitude'        => $latitude,
      'longitude'       => $longitude,
      'address'         => $address,
      'paidByUserId'    => $paidByUserId,
      'createdByUserId' => $user->id,
    ];

    $recurring = transaction(fn() => RecurringExpenseModel::create($param) ?? error('建立固定開銷失敗'));

    return ['recurringExpense' => State::formatRecurringExpense($recurring)];
  }

  public function update(int $id) {
    $user      = User::current();
    $recurring = RecurringExpenseModel::one('id', $id);

    if (!$recurring) {
      notFound('固定開銷不存在');
    }

    self::_findLedgerAsMember($recurring->ledgerId, $user->id);

    list(
      'categoryId'     => $categoryId,
      'amount'         => $amount,
      'frequencyType'  => $frequencyType,
      'frequencyValue' => $frequencyValue,
      'memo'           => $memo,
      'isEnabled'      => $isEnabled,
      'latitude'       => $latitude,
      'longitude'      => $longitude,
      'address'        => $address,
      'paidByUserId'   => $paidByUserId,
    ) = Valid::check(Payload::getJson(), [
      'categoryId'     => Valid::uInt_('分類 ID')->nullOrNoKey(false),
      'amount'         => Valid::uInt_('金額')->nullOrNoKey(null),
      'frequencyType'  => Valid::enum_('頻率類型', ['daily', 'weekly', 'monthly', 'yearly'])->nullOrNoKey(null),
      'frequencyValue' => Valid::any_('頻率參數')->nullOrNoKey(false),
      'memo'           => Valid::string_('備註')->max(200)->nullOrNoKey(null),
      'isEnabled'      => Valid::bool_('是否啟用')->nullOrNoKey(null),
      'latitude'       => Valid::string_('緯度')->nullOrNoKey(false),
      'longitude'      => Valid::string_('經度')->nullOrNoKey(false),
      'address'        => Valid::string_('地址')->max(200)->nullOrNoKey(false),
      'paidByUserId'   => Valid::uInt_('付款人')->nullOrNoKey(false),
    ]);

    if ($categoryId !== false) {
      $recurring->categoryId = $categoryId;
    }

    if ($amount !== null) {
      $recurring->amount = $amount;
    }

    if ($frequencyType !== null) {
      $recurring->frequencyType = $frequencyType;
    }

    if ($frequencyValue !== false) {
      $recurring->frequencyValue = $frequencyValue;
    }

    if ($memo !== null) {
      $recurring->memo = $memo;
    }

    if ($isEnabled !== null) {
      $recurring->isEnabled = $isEnabled
        ? RecurringExpenseModel::IS_ENABLED_YES
        : RecurringExpenseModel::IS_ENABLED_NO;
    }

    if ($latitude !== false) {
      $recurring->latitude = $latitude;
    }

    if ($longitude !== false) {
      $recurring->longitude = $longitude;
    }

    if ($address !== false) {
      $recurring->address = $address;
    }

    if ($paidByUserId !== false) {
      $recurring->paidByUserId = $paidByUserId;
    }

    transaction(fn() => $recurring->save());

    return ['recurringExpense' => State::formatRecurringExpense($recurring)];
  }

  public function destroy(int $id) {
    $user      = User::current();
    $recurring = RecurringExpenseModel::one('id', $id);

    if (!$recurring) {
      notFound('固定開銷不存在');
    }

    self::_findLedgerAsMember($recurring->ledgerId, $user->id);

    transaction(fn() => $recurring->delete());

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

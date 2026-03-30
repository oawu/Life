<?php

namespace App\Controller\Cli;

use \App\Model\RecurringExpense;
use \App\Model\Expense;

class Recurring {
  public function trigger() {
    $today     = date('Y-m-d');
    $dayOfWeek = (int)date('w') + 1;
    $dayOfMonth = (int)date('j');
    $month     = (int)date('n');
    $daysInMonth = (int)date('t');
    $isLeapYear  = (int)date('L');

    $recurrings = RecurringExpense::where('isEnabled', RecurringExpense::IS_ENABLED_YES)
      ->whereGroup(function ($query) use ($today) {
        $query->where('lastTriggeredDate', null)
          ->orWhere('lastTriggeredDate', '<', $today);
      })
      ->all();

    $count = 0;

    foreach ($recurrings as $recurring) {
      if (!$this->_shouldTrigger($recurring, $dayOfWeek, $dayOfMonth, $month, $daysInMonth, $isLeapYear)) {
        continue;
      }

      $param = [
        'ledgerId'        => $recurring->ledgerId,
        'categoryId'      => $recurring->categoryId,
        'amount'          => $recurring->amount,
        'memo'            => $recurring->memo,
        'date'            => $today . ' 00:00:00',
        'latitude'        => $recurring->latitude,
        'longitude'       => $recurring->longitude,
        'address'         => $recurring->address,
        'isSettled'       => Expense::IS_SETTLED_NO,
        'paidByUserId'    => $recurring->paidByUserId,
        'createdByUserId' => $recurring->createdByUserId,
      ];

      transaction(static function () use ($param, $recurring, $today) {
        Expense::create($param) ?? error('建立開銷失敗');
        $recurring->lastTriggeredDate = $today;
        return $recurring->save();
      });

      $count++;
    }

    return '觸發完成，建立 ' . $count . ' 筆開銷';
  }

  private function _shouldTrigger(RecurringExpense $recurring, int $dayOfWeek, int $dayOfMonth, int $month, int $daysInMonth, int $isLeapYear): bool {
    $type  = $recurring->frequencyType;
    $value = $recurring->frequencyValue;

    if ($type === RecurringExpense::FREQUENCY_TYPE_DAILY) {
      return true;
    }

    if ($type === RecurringExpense::FREQUENCY_TYPE_WEEKLY) {
      if ($value === null) {
        return false;
      }
      $targetDay = isset($value['dayOfWeek']) ? (int)$value['dayOfWeek'] : 0;
      return $dayOfWeek === $targetDay;
    }

    if ($type === RecurringExpense::FREQUENCY_TYPE_MONTHLY) {
      if ($value === null) {
        return false;
      }
      $targetDay = isset($value['dayOfMonth']) ? (int)$value['dayOfMonth'] : 0;
      if ($targetDay > $daysInMonth) {
        return false;
      }
      return $dayOfMonth === $targetDay;
    }

    if ($type === RecurringExpense::FREQUENCY_TYPE_YEARLY) {
      if ($value === null) {
        return false;
      }
      $targetMonth = isset($value['month']) ? (int)$value['month'] : 0;
      $targetDay   = isset($value['day']) ? (int)$value['day'] : 0;
      if ($targetMonth === 2 && $targetDay === 29 && !$isLeapYear) {
        return false;
      }
      return $month === $targetMonth && $dayOfMonth === $targetDay;
    }

    return false;
  }
}

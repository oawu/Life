<?php

namespace App\Controller\Cli;

use \App\Model\RecurringExpense;
use \App\Model\Expense;

class Recurring {
  public function trigger() {
    $argvs = \Request::argvs();
    $date  = $argvs[0] ?? null;

    if ($date !== null) {
      $timestamp = strtotime($date);
      if ($timestamp === false) {
        return '日期格式錯誤：' . $date;
      }
    } else {
      $timestamp = time();
    }

    $today       = date('Y-m-d', $timestamp);
    $dayOfWeek   = (int)date('w', $timestamp) + 1;
    $dayOfMonth  = (int)date('j', $timestamp);
    $month       = (int)date('n', $timestamp);
    $daysInMonth = (int)date('t', $timestamp);
    $isLeapYear  = (int)date('L', $timestamp);

    $recurrings = RecurringExpense::where('isEnabled', RecurringExpense::IS_ENABLED_YES)
      ->whereGroup(fn($query) => $query->where('lastTriggeredDate', null)->orWhere('lastTriggeredDate', '<', $today))
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
        'memo'            => $this->_buildRecurringMemo($recurring),
        'date'            => $today . ' 00:00:00',
        'latitude'        => $recurring->latitude,
        'longitude'       => $recurring->longitude,
        'address'         => $recurring->address,
        'isSettled'       => Expense::IS_SETTLED_NO,
        'paidByUserId'    => $recurring->paidByUserId,
        'createdByUserId' => $recurring->createdByUserId,
        'version'         => 1,
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
      return $dayOfWeek === $value;
    }

    if ($type === RecurringExpense::FREQUENCY_TYPE_MONTHLY) {
      if ($value === null) {
        return false;
      }
      $targetDay = $value;
      if ($targetDay > $daysInMonth) {
        return false;
      }
      return $dayOfMonth === $targetDay;
    }

    if ($type === RecurringExpense::FREQUENCY_TYPE_YEARLY) {
      if ($value === null) {
        return false;
      }
      $targetMonth = $value['month'] ?? 0;
      $targetDay   = $value['day'] ?? 0;
      if ($targetMonth === 2 && $targetDay === 29 && !$isLeapYear) {
        return false;
      }
      return $month === $targetMonth && $dayOfMonth === $targetDay;
    }

    return false;
  }

  private function _buildRecurringMemo(RecurringExpense $recurring): string {
    $type  = $recurring->frequencyType;
    $value = $recurring->frequencyValue;

    $weekDays = ['', '日', '一', '二', '三', '四', '五', '六'];

    if ($type === RecurringExpense::FREQUENCY_TYPE_DAILY) {
      $freq = '每日';
    } elseif ($type === RecurringExpense::FREQUENCY_TYPE_WEEKLY) {
      $freq = '每週' . ($weekDays[$value] ?? '');
    } elseif ($type === RecurringExpense::FREQUENCY_TYPE_MONTHLY) {
      $freq = '每月 ' . $value . ' 日';
    } elseif ($type === RecurringExpense::FREQUENCY_TYPE_YEARLY) {
      $m   = $value['month'] ?? 0;
      $day = $value['day'] ?? 0;
      $freq = '每年 ' . $m . '/' . $day;
    } else {
      $freq = '';
    }

    $tag          = '由' . $freq . '固定開銷自動建立';
    $originalMemo = trim((string)$recurring->memo);

    if ($originalMemo === '') {
      return $tag;
    }

    return mb_substr($originalMemo . '（' . $tag . '）', 0, 200);
  }
}

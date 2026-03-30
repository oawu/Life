<?php

namespace App\Controller\Cli;

use \App\Lib\Worker as WorkerLib;

class Worker {
  public function test() {
    $lines = [];
    $lines[] = '=== Worker 測試 ===';
    $lines[] = '';

    // 1. GET /worker/status
    $lines[] = '--- GET /worker/status ---';

    $status = WorkerLib::status();

    if ($status === null) {
      $lines[] = '→ Worker 未啟動或無法連線';
      return implode("\n", $lines);
    }

    $lines[] = json_encode($status, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    $lines[] = '';

    // 2. POST /worker/notify
    $lines[] = '--- POST /worker/notify ---';

    WorkerLib::notify();

    $lines[] = '→ notify sent (fire-and-forget)';
    $lines[] = '';
    $lines[] = '→ Worker 連線正常';

    return implode("\n", $lines);
  }
}

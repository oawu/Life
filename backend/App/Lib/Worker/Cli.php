<?php

namespace App\Lib\Worker;

use \App\Lib\Worker;

class Cli {
  private $_cmd     = '';
  private $_queue   = null;
  private $_delay   = null;
  private $_timeout = null;

  /**
   * 設定原始命令
   */
  public function cmd(string $cmd): self {
    $this->_cmd = $cmd;
    return $this;
  }

  /**
   * 捷徑：php Public/index.php <route>
   */
  public function maple(string $route): self {
    $this->_cmd = 'php Public/index.php ' . $route;
    return $this;
  }

  /**
   * Named Queue 名稱
   */
  public function queue(string $queue): self {
    $this->_queue = $queue;
    return $this;
  }

  /**
   * 延遲秒數
   */
  public function delay(int $delay): self {
    $this->_delay = $delay;
    return $this;
  }

  /**
   * 超時秒數
   */
  public function timeout(int $timeout): self {
    $this->_timeout = $timeout;
    return $this;
  }

  /**
   * 執行，回傳 ['code' => int, 'response' => string]
   */
  public function exec(): array {
    $payload = ['cmd' => $this->_cmd];

    if ($this->_queue !== null) {
      $payload['queue'] = $this->_queue;
    }

    if ($this->_delay !== null) {
      $payload['delay'] = $this->_delay;
    }

    if ($this->_timeout !== null) {
      $payload['timeout'] = $this->_timeout;
    }

    return Worker::send('/exec/cli', $payload);
  }

  /**
   * Fire-and-forget，不等回應
   */
  public function fire(): void {
    $payload = ['cmd' => $this->_cmd];

    if ($this->_queue !== null) {
      $payload['queue'] = $this->_queue;
    }

    if ($this->_delay !== null) {
      $payload['delay'] = $this->_delay;
    }

    if ($this->_timeout !== null) {
      $payload['timeout'] = $this->_timeout;
    }

    Worker::sendAsync('/exec/cli', $payload);
  }
}

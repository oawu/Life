<?php

namespace App\Lib;

use \App\Lib\Worker\Cli;

abstract class Worker {
  private static function baseUrl(): ?string {
    $host = \Config::get('Worker', 'host');
    $port = \Config::get('Worker', 'port');

    if (!$host || !$port) {
      return null;
    }

    return 'http://' . $host . ':' . $port;
  }

  private static function cliToken(): string {
    return \Config::get('Worker', 'cliToken') ?: '';
  }

  /**
   * 核心 HTTP sender（POST + Bearer auth + JSON）
   *
   * @return array ['code' => int, 'response' => string]
   */
  public static function send(string $path, array $payload = [], int $timeout = 30): array {
    $baseUrl = self::baseUrl();

    if (!$baseUrl) {
      return ['code' => 0, 'response' => 'Worker not configured'];
    }

    $token = self::cliToken();
    $body  = json_encode($payload);

    $headers = ['Content-Type: application/json'];

    if ($token !== '') {
      $headers[] = 'Authorization: Bearer ' . $token;
    }

    $ch = curl_init($baseUrl . $path);
    curl_setopt_array($ch, [
      CURLOPT_POST           => true,
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_TIMEOUT        => $timeout,
      CURLOPT_CONNECTTIMEOUT => 5,
      CURLOPT_HTTPHEADER     => $headers,
      CURLOPT_POSTFIELDS     => $body,
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error    = curl_error($ch);
    curl_close($ch);

    if ($error) {
      return ['code' => 0, 'response' => $error];
    }

    return ['code' => $httpCode, 'response' => $response];
  }

  /**
   * Fire-and-forget POST（Bearer auth + JSON，100ms 超時）
   */
  public static function sendAsync(string $path, array $payload = []): void {
    $baseUrl = self::baseUrl();

    if (!$baseUrl) {
      return;
    }

    $token = self::cliToken();
    $body  = json_encode($payload);

    $headers = ['Content-Type: application/json'];

    if ($token !== '') {
      $headers[] = 'Authorization: Bearer ' . $token;
    }

    $ch = curl_init($baseUrl . $path);
    curl_setopt_array($ch, [
      CURLOPT_POST           => true,
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_TIMEOUT_MS     => 100,
      CURLOPT_NOSIGNAL       => 1,
      CURLOPT_HTTPHEADER     => $headers,
      CURLOPT_POSTFIELDS     => $body,
    ]);
    curl_exec($ch);
    curl_close($ch);
  }

  /**
   * Fire-and-forget POST /worker/notify（無 auth，100ms 超時）
   */
  public static function notify(): void {
    $baseUrl = self::baseUrl();

    if (!$baseUrl) {
      return;
    }

    $ch = curl_init($baseUrl . '/worker/notify');
    curl_setopt_array($ch, [
      CURLOPT_POST           => true,
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_TIMEOUT_MS     => 100,
      CURLOPT_NOSIGNAL       => 1,
    ]);
    curl_exec($ch);
    curl_close($ch);
  }

  /**
   * GET /worker/status，回傳解碼後的 array 或 null
   */
  public static function status(): ?array {
    $baseUrl = self::baseUrl();

    if (!$baseUrl) {
      return null;
    }

    $ch = curl_init($baseUrl . '/worker/status');
    curl_setopt_array($ch, [
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_TIMEOUT        => 3,
      CURLOPT_CONNECTTIMEOUT => 2,
    ]);

    $response = curl_exec($ch);
    $error    = curl_error($ch);
    curl_close($ch);

    if ($error || !$response) {
      return null;
    }

    $data = json_decode($response, true);

    return is_array($data) ? $data : null;
  }

  /**
   * 回傳 Cli builder
   */
  public static function cli(): Cli {
    return new Cli();
  }
}

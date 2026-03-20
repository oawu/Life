<?php

namespace App\Lib;

class Jwt {

  const HS256 = ['alg' => 'HS256', 'function' => 'hashHmac', 'algorithm' => 'SHA256'];
  const HS384 = ['alg' => 'HS384', 'function' => 'hashHmac', 'algorithm' => 'SHA384'];
  const HS512 = ['alg' => 'HS512', 'function' => 'hashHmac', 'algorithm' => 'SHA512'];
  const RS256 = ['alg' => 'RS256', 'function' => 'openssl', 'algorithm' => 'SHA256'];
  const RS384 = ['alg' => 'RS384', 'function' => 'openssl', 'algorithm' => 'SHA384'];
  const RS512 = ['alg' => 'RS512', 'function' => 'openssl', 'algorithm' => 'SHA512'];
  const ALGS  = [self::HS256, self::HS384, self::HS512, self::RS256, self::RS384, self::RS512];

  public static $leeway = 0;
  public static $timestamp = null;

  private static function base64UrlEncode($data): string {
    return rtrim(strtr(base64_encode(is_array($data) ? json_encode($data) : $data), '+/', '-_'), '=');
  }

  private static function base64UrlDecode(string $input): string {
    $remainder = strlen($input) % 4;

    if ($remainder) {
      $input .= str_repeat('=', 4 - $remainder);
    }

    return base64_decode(strtr($input, '-_', '+/'));
  }

  private static function hashHmac(string $data, $key, string $algorithm): string {
    return hash_hmac($algorithm, $data, $key, true);
  }

  private static function hashHmacVerify(string $data, string $signature, $key, string $algorithm): bool {
    return hash_equals($signature, self::hashHmac($data, $key, $algorithm));
  }

  private static function openssl(string $data, $key, string $algorithm) {
    $signature = '';
    return openssl_sign($data, $signature, $key, $algorithm) ? $signature : null;
  }

  private static function opensslVerify(string $data, string $signature, $key, string $algorithm): bool {
    return openssl_verify($data, $signature, $key, $algorithm) === 1;
  }

  public static function encode(array $payload, $key, array $method) {
    $function = $method['function'];
    $check = $function === 'openssl' ? 'openssl_sign' : 'hash_hmac';

    if (!function_exists($check)) {
      return null;
    }

    $header  = self::base64UrlEncode(['typ' => 'JWT', 'alg' => $method['alg']]);
    $payload = self::base64UrlEncode($payload);
    $signature = self::$function($header . '.' . $payload, $key, $method['algorithm']);

    if ($signature === null) {
      return null;
    }

    return $header . '.' . $payload . '.' . self::base64UrlEncode($signature);
  }

  public static function decode(string $jwt, $key) {
    $tokens = explode('.', $jwt);

    if (count($tokens) !== 3) {
      return null;
    }

    list($base64Header, $base64Payload, $base64Signature) = $tokens;

    $header = json_decode(self::base64UrlDecode($base64Header), true);

    if (!is_array($header)) {
      return null;
    }

    $payload = json_decode(self::base64UrlDecode($base64Payload), true);

    if (!is_array($payload)) {
      return null;
    }

    $signature = self::base64UrlDecode($base64Signature);

    if ($signature === false) {
      return null;
    }

    if (!isset($header['alg'])) {
      return null;
    }

    $alg = $header['alg'];

    if (!in_array($alg, array_column(self::ALGS, 'alg')) || !defined(self::class . '::' . $alg)) {
      return null;
    }

    $method = constant(self::class . '::' . $alg);
    $function = $method['function'];
    $check = $function === 'openssl' ? 'openssl_verify' : 'hash_hmac';

    if (!function_exists($check)) {
      return null;
    }

    $verify = $function . 'Verify';

    if (!self::$verify($base64Header . '.' . $base64Payload, $signature, $key, $method['algorithm'])) {
      return null;
    }

    $timestamp = self::$timestamp ?? time();

    if (isset($payload['nbf']) && $payload['nbf'] > ($timestamp + self::$leeway)) {
      return null;
    }

    if (isset($payload['iat']) && $payload['iat'] > ($timestamp + self::$leeway)) {
      return null;
    }

    if (isset($payload['exp']) && ($timestamp - self::$leeway) >= $payload['exp']) {
      return null;
    }

    return $payload;
  }
}

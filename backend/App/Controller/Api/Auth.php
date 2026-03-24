<?php

namespace App\Controller\Api;

use \Config;
use \Valid;
use \Request\Payload;
use \App\Lib\Jwt;
use \App\Model\User;

class Auth {
  public function appleCallback() {
    list(
      'identityToken' => $identityToken,
      'fullName'      => $fullName,
      'isDev'         => $isDev,
    ) = Valid::check(Payload::getJson(), [
      'identityToken' => Valid::string('Identity Token')->min(1),
      'fullName'      => Valid::string_('Full Name')->max(190)->nullOrNoKey(null),
      'isDev'         => Valid::bool_('isDev')->nullOrNoKey(false),
    ]);

    if ($isDev && ENVIRONMENT !== 'Production') {
      return self::_devLogin($identityToken);
    }

    // 解碼 identityToken header 取得 kid
    $tokenParts = explode('.', $identityToken);

    if (count($tokenParts) !== 3) {
      error('Invalid identity token format', 400);
    }

    $headerJson = base64_decode(strtr($tokenParts[0], '-_', '+/'));
    $header = json_decode($headerJson, true);

    if (!isset($header['kid'])) {
      error('Missing kid in token header', 400);
    }

    $kid = $header['kid'];

    // 從 Apple JWKS 取得公鑰
    $jwksJson = self::_curlGet('https://appleid.apple.com/auth/keys');

    if ($jwksJson === null || !isset($jwksJson['keys'])) {
      error('Failed to fetch Apple public keys', 500);
    }

    $publicKey = null;
    foreach ($jwksJson['keys'] as $key) {
      if ($key['kid'] === $kid) {
        $publicKey = $key;
        break;
      }
    }

    if ($publicKey === null) {
      error('Matching Apple public key not found', 400);
    }

    // JWK 轉 PEM
    $pem = self::_jwkToPem($publicKey);

    if ($pem === null) {
      error('Failed to convert Apple public key', 500);
    }

    // 用 RS256 驗證 identityToken
    $payload = Jwt::decode($identityToken, $pem);

    if ($payload === null) {
      error('Invalid or expired identity token', 401);
    }

    // 驗證 iss 和 aud
    if (!isset($payload['iss']) || $payload['iss'] !== 'https://appleid.apple.com') {
      error('Invalid token issuer', 401);
    }

    $config = Config::get('Auth', 'apple');

    $bundleIds = (array)$config['bundleId'];
    if (!isset($payload['aud']) || !in_array($payload['aud'], $bundleIds)) {
      error('Invalid token audience', 401);
    }

    if (!isset($payload['sub'])) {
      error('Missing subject in token', 401);
    }

    $appleId = $payload['sub'];
    $email = $payload['email'] ?? '';

    // 查找或建立 User
    $user = User::one('appleId', $appleId);

    if ($user) {
      // 更新資料
      $param = [];

      if ($fullName !== null && $fullName !== '') {
        $param['name'] = $fullName;
      }

      if ($email !== '' && $user->email === '') {
        $param['email'] = $email;
      }

      if (!empty($param)) {
        $user->set($param);

        transaction(static function () use ($user) {
          return $user->save();
        });
      }
    } else {
      $name = $fullName ?? '';
      if ($name === '' && $email !== '') {
        $name = explode('@', $email)[0];
      }

      $param = [
        'appleId' => $appleId,
        'email'   => $email,
        'name'    => $name,
        'status'  => User::STATUS_ACTIVE,
      ];

      $user = transaction(static function () use ($param) {
        return User::create($param) ?? error('建立用戶失敗');
      });
    }

    return $user->issueToken();
  }

  public function me() {
    $user = User::current();

    return ['user' => $user->toSafeArray()];
  }

  public function updateProfile() {
    $user = User::current();

    list(
      'name'           => $name,
      'carrierNumber'  => $carrierNumber,
    ) = Valid::check(Payload::getJson(), [
      'name'           => Valid::string_('名稱')->max(190)->nullOrNoKey(null),
      'carrierNumber'  => Valid::string_('載具號碼')->max(10)->nullOrNoKey(null),
    ]);

    if ($name === null && $carrierNumber === null) {
      return ['user' => $user->toSafeArray()];
    }

    if ($name !== null) {
      $user->name = $name;
    }

    if ($carrierNumber !== null) {
      $user->carrierNumber = $carrierNumber;
    }

    transaction(static function () use ($user) {
      return $user->save();
    });

    return ['user' => $user->toSafeArray()];
  }

  private static function _devLogin(string $email): array {
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
      error('Invalid email format', 400);
    }

    $user = User::one('email', $email);

    if ($user) {
      return $user->issueToken();
    }

    $param = [
      'appleId' => 'dev_' . md5($email),
      'email'   => $email,
      'name'    => explode('@', $email)[0],
      'status'  => User::STATUS_ACTIVE,
    ];

    $user = transaction(static function () use ($param) {
      return User::create($param) ?? error('建立用戶失敗');
    });

    return $user->issueToken();
  }

  private static function _curlGet(string $url) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_TIMEOUT        => 10,
    ]);

    $response = curl_exec($ch);
    curl_close($ch);

    if ($response === false) {
      return null;
    }

    return json_decode($response, true);
  }

  private static function _jwkToPem(array $jwk) {
    if (!isset($jwk['n']) || !isset($jwk['e'])) {
      return null;
    }

    $modulus = self::_base64UrlDecode($jwk['n']);
    $exponent = self::_base64UrlDecode($jwk['e']);

    // ASN.1 DER 編碼
    $modulus = "\0" . $modulus;
    $modulusLen = strlen($modulus);
    $exponentLen = strlen($exponent);

    $modulusDer = self::_asn1Length($modulusLen) . $modulus;
    $exponentDer = self::_asn1Length($exponentLen) . $exponent;

    $sequence = "\x02" . $modulusDer . "\x02" . $exponentDer;
    $sequenceDer = "\x30" . self::_asn1Length(strlen($sequence)) . $sequence;

    $bitString = "\x00" . $sequenceDer;
    $bitStringDer = "\x03" . self::_asn1Length(strlen($bitString)) . $bitString;

    // RSA OID: 1.2.840.113549.1.1.1
    $oid = "\x30\x0d\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01\x05\x00";

    $publicKeyDer = "\x30" . self::_asn1Length(strlen($oid . $bitStringDer)) . $oid . $bitStringDer;

    $pem = "-----BEGIN PUBLIC KEY-----\n";
    $pem .= chunk_split(base64_encode($publicKeyDer), 64, "\n");
    $pem .= "-----END PUBLIC KEY-----";

    return $pem;
  }

  private static function _base64UrlDecode(string $input): string {
    $remainder = strlen($input) % 4;

    if ($remainder) {
      $input .= str_repeat('=', 4 - $remainder);
    }

    return base64_decode(strtr($input, '-_', '+/'));
  }

  private static function _asn1Length(int $length): string {
    if ($length < 0x80) {
      return chr($length);
    }

    $temp = ltrim(pack('N', $length), "\x00");
    return chr(0x80 | strlen($temp)) . $temp;
  }
}

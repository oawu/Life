# 通用編碼規範

適用於所有語言（JavaScript、PHP 等）。

## if 語句必須使用大括號

禁止單行 if 語句，必須使用大括號換行：

```javascript
// ✗ 錯誤：單行 if
if (title !== undefined) Alert._shared.title(title)
if (error) return

// ✓ 正確：使用大括號換行
if (title !== undefined) {
  Alert._shared.title(title)
}

if (error) {
  return
}
```

```php
// ✗ 錯誤：單行 if
if ($user === null) return;
if ($album->type === 'folder') $password = null;

// ✓ 正確：使用大括號換行
if ($user === null) {
  return;
}

if ($album->type === 'folder') {
  $password = null;
}
```

## 變數命名清晰度

變數名稱在不會造成衝突的前提下，應寫完整、有意義的名稱，禁止使用單字母、首字母縮寫或過度簡寫：

```javascript
// ✗ 錯誤：太簡略
const a = Alert('標題', '訊息')
const m = DropdownMenu(event)
const r = await Api('/api/album').get()

// ✓ 正確：語意清晰
const passwordAlert = Alert('標題', '訊息')
const menu = DropdownMenu(event)
const response = await Api('/api/album').get()
```

```php
// ✗ 錯誤：單字母或首字母縮寫
$a  = Album::one('id', $id);
$u  = User::current();
$sa = ShowcaseAlbum::one('id', $id);
$sc = ShowcaseCollection::one('id', $id);

// ✓ 正確：語意清晰
$album              = Album::one('id', $id);
$user               = User::current();
$showcaseAlbum      = ShowcaseAlbum::one('id', $id);
$showcaseCollection = ShowcaseCollection::one('id', $id);
```

**例外**：迴圈變數（`i`, `j`, `$i`, `$j`）、callback 參數等慣用縮寫可以接受。

## 順手修正不符合規範的命名

修改既有檔案時，若發現不符合規範的命名（如全大寫常數 `_CONCURRENCY` 應改為 `_concurrency`），順手一併修正為正確風格。

## 條件判斷：先排除再處理

優先處理可提前回傳的情況（early return），減少巢狀層級，提高可讀性：

```php
// ✓ 正確：先排除
$user = User::one('email', $email);

if ($user) {
  return $user->issueToken();
}

// 以下為建立新用戶的邏輯...

// ✗ 錯誤：用否定條件包裝主要邏輯
$user = User::one('email', $email);

if (!$user) {
  // 一大段建立邏輯...
}

return $user->issueToken();
```

```javascript
// ✓ 正確：先排除
const album = albums.find(a => a.id === id)

if (!album) {
  Toastr.failure('找不到相簿')
  return
}

// 以下為主要邏輯...

// ✗ 錯誤：否定條件包裝
const album = albums.find(a => a.id === id)

if (album) {
  // 一大段主要邏輯...
} else {
  Toastr.failure('找不到相簿')
}
```

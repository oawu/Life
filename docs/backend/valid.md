# 驗證（Valid）

## 使用方式

搭配 `list()` 解構取得驗證後的值：

```php
use \Valid;
use \Request\Payload;

list(
  'code' => $code,
  'name' => $name,
) = Valid::check(Payload::getJson(), [
  'code' => Valid::string('Code')->min(1),
  'name' => Valid::string('Name')->min(1)->max(100),
]);
```

驗證失敗時，由 Api Middleware 設定的 `Valid::setIfError` 自動呼叫 `error()` 中止流程。

## 驗證規則

### 必填 vs 可選

尾綴加 `_` 表示可選（沒 key 或值為 null 時回傳 null）：

```php
'name'   => Valid::string('名稱'),     // 必填
'avatar' => Valid::string_('頭像'),    // 可選，預設 null
```

### 可選 + 預設值

搭配 `nullOrNoKey($default)` 給予預設值（而非 null）：

```php
'isDev' => Valid::bool_('isDev')->nullOrNoKey(false),
// { "isDev": true }  → true
// { "isDev": null }  → false
// {}（沒傳）          → false
```

相關方法：

| 方法 | 觸發條件 |
|------|---------|
| `ifNull($val)` | 值為 null 時 |
| `ifNoKey($val)` | key 不存在時 |
| `nullOrNoKey($val)` | 以上兩者合一 |

### 常用規則

| 方法 | 說明 | 參數 |
|------|------|------|
| `Valid::string($title)` | 字串 | 標題 |
| `Valid::int($title)` | 整數 | 標題 |
| `Valid::id($title)` | ID（正整數，min=1） | 標題 |
| `Valid::float($title)` | 浮點數 | 標題 |
| `Valid::uInt($title)` | 無號整數（min=0） | 標題 |
| `Valid::bool($title)` | 布林值 | 標題 |
| `Valid::email($title)` | Email | 標題 |
| `Valid::url($title)` | URL | 標題 |
| `Valid::date($title)` | 日期 | 標題 |
| `Valid::datetime($title)` | 日期時間 | 標題 |
| `Valid::enum($title, $items)` | 列舉 | 標題, 允許值陣列 |
| `Valid::uploadFile($title)` | 上傳檔案 | 標題 |
| `Valid::array($title, $rule)` | 陣列 | 標題, **元素驗證規則（必要）** |
| `Valid::object($title, $rules)` | 物件（巢狀規則） | 標題, 規則陣列 |
| `Valid::any($title)` | 任意值 | 標題 |

### 鏈式約束

```php
// 字串：min / max 為長度限制
Valid::string('名稱')->min(1)->max(100)

// 數值：min / max 為數值範圍
Valid::int('年齡')->min(0)->max(150)
Valid::uInt('數量')->max(999)

// 列舉
Valid::enum('狀態', ['pending', 'active', 'disabled'])

// 陣列：最少元素數
Valid::array('項目', Valid::id('ID'))->minCount(1)
```

### isStrict

`isStrict` 控制是否允許字串數字自動轉型。**僅對數值型規則有效**：

| 規則類型 | isStrict 是否有效 | 說明 |
|----------|:-:|------|
| `int` / `uInt` / `float` / `id` | ✓ | 預設嚴格，`'1'` 會失敗；加 `isStrict(false)` 可自動轉型 |
| `enum`（整數 allowed values） | ✓ | 允許值為整數時，`isStrict(false)` 允許字串 `"0"` 匹配整數 `0` |
| `string` / `email` / `url` | ✗ | 輸入本身就是字串，isStrict 無意義 |
| `enum`（字串 allowed values） | ✗ | 允許值和輸入都是字串，isStrict 無意義 |
| `bool` / `array` / `object` / `any` | ✗ | 不適用 |

```php
// 嚴格模式（預設）：'1' → 驗證失敗
Valid::int('數量')

// 寬鬆模式：'1' → 自動轉為 1
Valid::int('數量')->isStrict(false)
```

### enum 搭配 Model const

使用 `array_keys()` 取得允許值，確保與 Model 定義同步：

```php
// ✓ 正確：搭配 Model const
Valid::enum('類型', array_keys(Album::TYPE))
Valid::enum('狀態', array_keys(Photo::IS_FAVORITE))

// ✗ 錯誤：硬編碼
Valid::enum('類型', ['folder', 'album'])
```

**注意**：若 const 的 key 是整數（如 `IS_FAVORITE = [0 => '否', 1 => '是']`），`array_keys()` 回傳 `[0, 1]`。此時 `isStrict` 的需求取決於資料來源：

- **JSON Body**：`json_decode` 後已是整數，**不需要** `isStrict(false)`
- **Query String**：值為字串 `"0"`，**需要** `isStrict(false)` 才能匹配整數 `0`

```php
// JSON Body — 不需要 isStrict(false)
Valid::enum('喜好狀態', array_keys(Photo::IS_FAVORITE))

// Query String — 整數 enum 需要 isStrict(false)
Valid::enum_('類型', [0, 1, 2])->isStrict(false)->nullOrNoKey(0)
```

### array 必須指定元素規則

`Valid::array($title, $rule)` 的第二個參數 `$rule`（元素驗證規則）是**必要的**。

```php
// ✓ 正確：指定元素規則
Valid::array('照片 ID', Valid::id('ID'))
Valid::array('項目', Valid::string('Key')->min(1)->max(50))
Valid::array_('條碼', Valid::string('條碼')->min(1))->nullOrNoKey([])

// ✓ 正確：元素為任意值（不驗證元素型別）
Valid::array_('佈局項目', Valid::any('項目'))->nullOrNoKey([])

// ✓ 正確：元素為巢狀物件
Valid::array('條碼計數', Valid::object('項目', [
  'barcode' => Valid::string('條碼')->min(1),
  'count'   => Valid::uInt('數量'),
]))

// ✗ 錯誤：缺少第二個參數
Valid::array_('佈局項目')->nullOrNoKey([])
```

## 全域錯誤處理

由 Api Middleware 統一設定，不需要在每次 `check` 時傳入 callback：

```php
// App/Middleware/Api.php 已設定
Valid::setIfError(static function(string $error, ?int $code = null) {
  error($error, $code ?? 400);
});
```

## 搭配不同資料來源

### JSON Body（`Payload::getJson()`）

`json_decode` 後型別已正確（數字是 `int`/`float`、布林是 `bool`），數值型規則**不需要** `isStrict(false)`：

```php
list(
  'name'       => $name,
  'status'     => $status,
  'isFavorite' => $isFavorite,
) = Valid::check(Payload::getJson(), [
  'name'       => Valid::string('名稱')->min(1)->max(255),
  'status'     => Valid::uInt('狀態'),                                   // JSON 中 0 已是 int
  'isFavorite' => Valid::enum('喜好狀態', array_keys(Photo::IS_FAVORITE)), // JSON 中整數 enum 也不需要
]);
```

### Query String（`Request::queries()`）

Query String 的值**皆為字串型態**（如 `?limit=100` 中 `"100"` 是字串）。

**數值型規則必須加 `->isStrict(false)`**，否則驗證會失敗。**字串型規則不受影響**：

```php
use \Request;

list(
  'limit'  => $limit,
  'status' => $status,
  'type'   => $type,
  'name'   => $name,
) = Valid::check(Request::queries(), [
  'limit'  => Valid::uInt_('每頁數量')->isStrict(false)->nullOrNoKey(null),     // 數值型：需要
  'status' => Valid::enum_('狀態', array_keys(Job::STATUS))->nullOrNoKey(null), // 字串 enum：不需要
  'type'   => Valid::enum_('類型', [0, 1, 2])->isStrict(false)->nullOrNoKey(0), // 整數 enum：需要
  'name'   => Valid::string_('名稱')->max(255)->nullOrNoKey(null),              // 字串型：不需要
]);
```

### 上傳檔案（`Payload::getFiles()`）

搭配 `Valid::uploadFile()` 驗證，禁止直接存取 `$_FILES`：

```php
list(
  'avatar' => $file,
) = Valid::check(Payload::getFiles(), [
  'avatar' => Valid::uploadFile('頭像')->maxSize(5 * 1024 * 1024),
]);
```

## isStrict 決策表

| 資料來源 | 規則類型 | 需要 isStrict(false)? | 原因 |
|----------|----------|:-:|------|
| JSON Body | 數值型（int/uInt/float/id） | ✗ | JSON 解碼後已是正確型別 |
| JSON Body | enum（整數 allowed） | ✗ | JSON 解碼後已是整數 |
| JSON Body | enum（字串 allowed） | ✗ | 字串對字串 |
| JSON Body | string / bool / array | ✗ | 型別已正確或不適用 |
| Query String | 數值型（int/uInt/float/id） | **✓** | Query 值為字串，需要轉型 |
| Query String | enum（整數 allowed） | **✓** | Query 值為字串 `"0"`，需匹配整數 `0` |
| Query String | enum（字串 allowed） | ✗ | 字串對字串，天然匹配 |
| Query String | string | ✗ | Query 值本身就是字串 |

**口訣**：Query String + 數值（含整數 enum）→ 加 `isStrict(false)`；其餘都不加。

## 常見錯誤

```php
// ✗ 錯誤 1：array 缺少元素規則
Valid::array_('佈局項目')->nullOrNoKey([])
// ✓ 正確
Valid::array_('佈局項目', Valid::any('項目'))->nullOrNoKey([])

// ✗ 錯誤 2：JSON Body 加了不必要的 isStrict(false)
// JSON 解碼後型別已正確，不需要轉型
Valid::uInt('狀態')->isStrict(false)
Valid::enum('喜好狀態', array_keys(Photo::IS_FAVORITE))->isStrict(false)
// ✓ 正確
Valid::uInt('狀態')
Valid::enum('喜好狀態', array_keys(Photo::IS_FAVORITE))

// ✗ 錯誤 3：string / enum（字串 allowed）加了 isStrict(false)
// isStrict 對字串型規則無效，寫了也沒作用
Valid::string('照片 ID')->min(1)->isStrict(false)
Valid::enum('狀態', ['pending', 'active'])->isStrict(false)
// ✓ 正確
Valid::string('照片 ID')->min(1)
Valid::enum('狀態', ['pending', 'active'])

// ✗ 錯誤 4：Query String 數值型忘了 isStrict(false)
// Query 值為字串 "100"，嚴格模式下 int 驗證會失敗
Valid::uInt_('每頁數量')->nullOrNoKey(null)
// ✓ 正確
Valid::uInt_('每頁數量')->isStrict(false)->nullOrNoKey(null)

// ✗ 錯誤 5：enum 硬編碼允許值
Valid::enum('類型', ['folder', 'album'])
Valid::enum('喜好狀態', [0, 1])
// ✓ 正確：使用 Model const
Valid::enum('類型', array_keys(Album::TYPE))
Valid::enum('喜好狀態', array_keys(Photo::IS_FAVORITE))
```

## 完整範例

### JSON Body

```php
list(
  'title'      => $title,
  'status'     => $status,
  'isFavorite' => $isFavorite,
  'note'       => $note,
  'ids'        => $ids,
  'items'      => $items,
) = Valid::check(Payload::getJson(), [
  'title'      => Valid::string('標題')->min(1)->max(190),
  'status'     => Valid::enum('狀態', array_keys(Album::ACCESS)),
  'isFavorite' => Valid::enum('喜好狀態', array_keys(Photo::IS_FAVORITE)),
  'note'       => Valid::string_('備註')->max(500),
  'ids'        => Valid::array('照片 ID', Valid::id('ID')),
  'items'      => Valid::array_('佈局項目', Valid::any('項目'))->nullOrNoKey([]),
]);
```

### Query String

```php
list(
  'limit'  => $limit,
  'nextId' => $nextId,
  'status' => $status,
  'type'   => $type,
  'name'   => $name,
) = Valid::check(Request::queries(), [
  'limit'  => Valid::uInt_('每頁數量')->isStrict(false)->nullOrNoKey(null),
  'nextId' => Valid::uInt_('游標 ID')->isStrict(false)->nullOrNoKey(null),
  'status' => Valid::enum_('狀態', array_keys(Job::STATUS))->nullOrNoKey(null),
  'type'   => Valid::enum_('類型', [0, 1, 2])->isStrict(false)->nullOrNoKey(0),
  'name'   => Valid::string_('名稱')->max(255)->nullOrNoKey(null),
]);
```

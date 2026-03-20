# ORM（Maple-ORM 9）

Maple 使用 Active Record 模式的 ORM，Model 類別直接對應資料表。

官方文件：[Maple-ORM Gitbook](https://oawu.gitbook.io/maple-orm/)，原始碼位於容器內 `~/Workspace/Maple-ORM/`。

---

## 定義 Model

Model 放在 `App/Model/`，繼承 `\Orm\Model`：

```php
<?php

namespace App\Model;

class User extends \Orm\Model {
  // 建立後回呼（依序執行，中途失敗即停止，不影響新增結果）
  static $afterCreates = ['afterCreate'];

  // 刪除後回呼（依序執行，中途失敗即停止，不影響刪除結果）
  static $afterDeletes = ['afterDelete'];

  // 關聯方法
  public function albums() {
    return $this->hasMany(Album::class);
  }

  public function role() {
    return $this->belongsTo(Role::class);
  }

  private function afterCreate($model) {
    // 建立後執行...
    return $model;
  }
}
```

### Enum 欄位定義為 const

資料表的 enum 值統一在 Model 以 `const` 定義，方便全域引用、避免硬編碼字串：

```php
class Album extends \Orm\Model {
  const TYPE_FOLDER = 'folder';
  const TYPE_ALBUM = 'album';
  const TYPE = [
    self::TYPE_FOLDER => '資料夾',
    self::TYPE_ALBUM => '相簿',
  ];

  const ACCESS_PUBLIC = 'public';
  const ACCESS_PRIVATE = 'private';
  const ACCESS = [
    self::ACCESS_PUBLIC => '公開',
    self::ACCESS_PRIVATE => '私密',
  ];
}
```

**命名規則**：`{欄位名稱大寫}_{值大寫}` 為個別值，`{欄位名稱大寫}` 為對照表陣列（key 為值、value 為中文說明）。

**使用方式**：

```php
// 比較
if ($album->type === Album::TYPE_FOLDER) { ... }

// 驗證規則（取 keys 作為 enum 選項）
Valid::enum('類型', array_keys(Album::TYPE))
```

### 命名對應

| 模式 | 資料表 | 欄位 | 外鍵 |
|------|--------|------|------|
| CamelCase（預設） | `User`（單數大駝峰） | `createAt`（小駝峰） | `userId` |
| snake_case | `users`（複數蛇形） | `create_at`（蛇形） | `user_id` |

### 綁定上傳欄位

在 Model 類別下方使用 `bindFile` 或 `bindImage`：

```php
class Photo extends \Orm\Model {
  static $_binds = [];
}

// 綁定檔案上傳
Photo::bindFile('attachment');

// 綁定圖片上傳（含版本）
Photo::bindImage('image', function($uploader) {
  $uploader->addVersion('w100')->setMethod('resize')->setArgs(100, 100, 'width');
  $uploader->addVersion('c120x120')->setMethod('adaptiveResizeQuadrant')->setArgs(120, 120, 'c');
});
```

---

## CRUD 操作

### 新增（Create）

```php
// 單筆新增（成功回傳 Model，失敗回傳 null）
$user = User::create([
  'name' => 'OA',
  'age' => 18,
]);

// 允許特定欄位（白名單）
$user = User::create($requestData, ['name', 'email']);

// 批次新增（成功回傳筆數，失敗回傳 null）
$count = User::creates([
  ['name' => 'A', 'age' => 18],
  ['name' => 'B', 'age' => 28],
], 50);  // 第二參數：每批筆數（預設 50）

// 指定資料庫
$count = User::creates($datas, 10, 'db2');
```

### 查詢（Read）

```php
// 取得全部
$users = User::all();

// 取得單筆（by primary key）
$user = User::one(1);        // id = 1
$user = User::first(1);      // 同 one
$user = User::last();         // 最後一筆（反轉排序）

// IN 查詢
$users = User::all([1, 3]);   // id IN (1, 3)

// 條件查詢
$user = User::one('name', 'OA');
$user = User::one(['name' => 'OA', 'status' => 'active']);

// 計數
$count = User::count();
$count = User::where('status', 'active')->count();
```

**回傳型別：**
- `one` / `first` / `last` → Model 物件 或 `null`
- `all` → Model 陣列 或 `[]`
- `count` → int 或 `null`

### 更新（Update）

```php
// 單筆更新（成功回傳 Model，失敗回傳 null）
$user->name = 'New Name';
$user->save();

// 批次設定（不儲存）
$user->set(['name' => 'New', 'email' => 'new@example.com']);

// 白名單過濾（第二參數 allow，外部資料來源時建議使用）
$user->set($data, ['name', 'email']);

// 白名單 + 自動 save（第三參數 true）
$user->set($data, ['name', 'email'], true);

// 批次更新（不需先取出，成功回傳筆數，失敗回傳 null）
User::where('status', 'pending')->updates(['status' => 'active']);
```

### 刪除（Delete）

```php
// 單筆刪除
$user->delete();

// 批次刪除（成功回傳筆數，失敗回傳 null）
User::where('status', 'inactive')->deletes();

// 清空資料表
User::truncate();
```

---

## 查詢建構器（Builder）

鏈式呼叫建構複雜查詢，順序為：

```
Model::
  [where, whereIn, whereNotIn, whereBetween, whereGroup, select, order, group, having, limit, offset, byKey, relation]
  [where, ..., orWhere, orWhereIn, orWhereNotIn, orWhereBetween, whereGroup, orWhereGroup]*
  [one, first, last, all, count, updates, deletes]()
```

### where 條件

```php
// 等於
->where('name', 'OA')
->where('id', 1)

// 比較運算
->where('age', '>=', 18)
->where('name', '!=', null)       // IS NOT NULL
->where('name', null)             // IS NULL

// IN / NOT IN
->where('id', [1, 2, 3])          // IN
->whereIn('id', [1, 2, 3])        // 同上
->whereNotIn('id', [4, 5])        // NOT IN

// BETWEEN
->whereBetween('age', 18, 30)

// LIKE
->where('name', 'LIKE', '%OA%')

// 關聯陣列（多條件 AND）
->where(['name' => 'OA', 'status' => 'active'])

// OR 條件
->where('status', 'active')->orWhere('status', 'pending')
->orWhereIn('id', [1, 2])
->orBetween('age', 18, 30)

// 條件分組（whereGroup / orWhereGroup）
// 用 callback 建立一組條件，括號包裹後以 AND / OR 合併
// 支援巢狀：callback 內可再使用 whereGroup / orWhereGroup

// 範例：(albumId < 5) OR (albumId = 5 AND id < 100)
->whereGroup(function ($q) {
    $q->where('albumId', '<', 5)
      ->orWhereGroup(function ($q2) {
          $q2->where('albumId', 5)
            ->where('id', '<', 100);
      });
})

// 產生 SQL：WHERE ... AND ((albumId < ?) OR ((albumId = ?) AND (id < ?)))
```

### 排序、分頁、分組

```php
->order('createAt DESC')
->order('name ASC', 'id DESC')    // 多欄排序
->limit(10)
->offset(20)
->group('status')
->having('COUNT(*) > 1')
```

### 欄位選取

```php
->select('id', 'name')
->select('COUNT(*) as total')
```

### 結果分組（byKey）

```php
// 以指定欄位作為 key 分組結果
$grouped = User::byKey('id')->all();
// 回傳: [1 => [User], 2 => [User], ...]
```

### 鎖定查詢

```php
->lockForUpdate()    // SELECT ... FOR UPDATE
```

---

## 關聯（Relations）

### 定義關聯

| 方法 | 類型 | 回傳 |
|------|------|------|
| `hasMany` | 一對多 | Model 陣列 / `[]` |
| `hasOne` | 一對一（取第一筆） | Model / `null` |
| `belongsTo` | 反向一對一 | Model / `null` |
| `belongsToMany` | 反向一對多 | Model 陣列 / `[]` |

```php
class User extends \Orm\Model {
  public function articles() {
    return $this->hasMany(Article::class);
    // 完整寫法：$this->hasMany(Article::class, 'userId', 'id')
  }

  public function article() {
    return $this->hasOne(Article::class);
  }
}

class Article extends \Orm\Model {
  public function user() {
    return $this->belongsTo(User::class);
    // 完整寫法：$this->belongsTo(User::class, 'userId', 'id')
  }
}
```

### 存取關聯

```php
// 當變數使用 → 自動查詢（第二次存取使用快取）
$user->articles;     // Model 陣列
$user->article;      // Model 或 null

// 當函式使用 → 回傳 Builder，可加條件
$user->articles()->where('pageView', '>', 20)->all();
```

### 預載入（Eager Loading）

避免 N+1 問題：

```php
// 沒有預載入：1 + N 次 Query
$users = User::all();
foreach ($users as $user) {
  $user->articles;  // 每個 user 各下一次 Query
}

// 使用預載入：只需 2 次 Query（改用 WHERE IN）
$users = User::relation('articles')->all();
foreach ($users as $user) {
  $user->articles;  // 已預先載入，不會再下 Query
}
```

### 自訂外鍵

```php
// 預設外鍵為：小寫表名 + Id（CamelCase 模式）
// 例：User → userId，Article → articleId

// 自訂：第二參數 = Foreign Key，第三參數 = Primary Key
public function albums() {
  return $this->hasMany(Album::class, 'ownerId', 'id');
}
```

---

## 交易（Transaction）

```php
use \Orm\Helper;

$errors = null;
$result = Helper::transaction(null, function() {
  $user = User::create(['name' => 'OA']);
  if (!$user) {
    Helper::rollback('建立用戶失敗');
  }

  $album = Album::create(['title' => 'My Album', 'userId' => $user->id]);
  if (!$album) {
    Helper::rollback('建立相簿失敗');
  }

  return true;
}, $errors);

if ($errors) {
  // 交易失敗，$errors 為錯誤訊息陣列
}
```

**規則：** closure 回傳值為 falsy（`null`、`false`、`0`、`[]`、`""`、`"0"`）會自動 rollback。

---

## Plugin 系統

ORM 內建 Plugin 自動處理特殊欄位型別。

### DateTime

`datetime`、`timestamp`、`date`、`time` 型別自動轉為 DateTime Plugin：

```php
$user = User::one(1);

// 取得格式化字串
echo $user->createAt;                    // "2026-01-15 10:30:00"
echo $user->createAt->format('Y/m/d');   // "2026/01/15"
echo $user->createAt->format('U');       // timestamp
echo $user->createAt->format('c');       // ISO 8601
echo $user->createAt->unix();            // Unix timestamp（int）

// API 回應時，使用 format() 輸出字串
return ['updateAt' => $user->updateAt->format('Y-m-d H:i:s')];

// 更新時 updateAt 自動更新
$user->name = 'New';
$user->save();  // updateAt 自動更新為當前時間
```

### File Uploader

`varchar` 欄位綁定為檔案上傳：

```php
// 上傳方式（三種格式）
$task->zip = '/path/to/file.zip';         // 本地檔案路徑
$task->zip = 'https://example.com/f.zip'; // URL 下載
$task->zip = $_FILES['file'];             // PHP 上傳檔案
$task->zip = '';                          // 清除檔案（null 也可）
$task->save();

// 取得 URL
echo $task->zip->getUrl();
// http://base.url/Storage/Task/zip/0000/0001/fe01ce2a7fbac8fafaed7c982a04e229.zip

// 另存為
$task->zip->saveAs('/path/to/dest.zip');
```

**儲存路徑結構：** `/{baseDirs}/{資料表}/{欄位}/{id 36進位前4碼}/{id 36進位後4碼}/{md5}.{副檔名}`

### Image Uploader

圖片上傳支援多版本縮圖：

```php
// 綁定時設定版本
User::bindImage('avatar', function($image) {
  $image->addVersion('w100')->setMethod('resize')->setArgs(100, 100, 'width');
  $image->addVersion('rotate')->setMethod('rotate')->setArgs(45);
});

// 上傳（同 File，三種格式）
$user->avatar = $_FILES['avatar'];
$user->save();

// 取得各版本 URL
$user->avatar->getUrl();           // 原圖
$user->avatar->getUrl('w100');     // w100 版本（前綴 w100_）
$user->avatar->getUrl('rotate');   // rotate 版本

// toArray 回傳所有版本 URL 陣列
$user->avatar->toArray();
```

### 上傳器設定

```php
// 全域設定（所有上傳器共用）
\Orm\Model::setUploader(function($uploader) {
  $uploader->setDriver('Local', ['storage' => PATH_PUBLIC]);
  $uploader->setBaseDir('Storage');
  $uploader->setBaseUrl('http://127.0.0.1/');
  $uploader->setDefaultUrl('http://127.0.0.1/404.png');
  $uploader->setTmpDir(sys_get_temp_dir() . DIRECTORY_SEPARATOR);
  $uploader->setNamingSort('md5', 'random', 'origin');
});

// 個別設定（在 bindFile/bindImage 的 callback 中覆蓋）
Task::bindFile('zip', function($uploader) {
  $uploader->setDriver('S3', [
    'bucket' => '', 'access' => '', 'secret' => '',
    'region' => 'ap-northeast-1', 'acl' => 'public-read',
  ]);
});

// 縮圖引擎（Image Uploader 必設）
\Orm\Model::setImageThumbnail(fn($file) => \Orm\Core\Thumbnail\Imagick::create($file));
// 或使用 Gd：fn($file) => \Orm\Core\Thumbnail\Gd::create($file)
```

### Binary

`binary` 型別自動轉為 Binary Plugin：

```php
echo $model->data;                // base64 編碼字串
$model->data->getValue();         // 原始二進位值
```

---

## 輸出

ORM 會依據資料表欄位型別自動轉型（`int`、`float` 等），存取屬性時已是正確的 PHP 型別，不需要手動 `(int)` 轉型。時間欄位會轉為 DateTime Plugin，需使用 `->format()` 或 `->unix()` 取值。

```php
// 自動轉型，不需手動 cast
$user->id;        // int（非 string）
$user->sort;      // int

// DateTime Plugin，使用 format() 取字串
$user->createAt->format('Y-m-d H:i:s');  // "2026-01-15 10:30:00"
$user->createAt->unix();                  // 1736934600
```

禁止覆寫 Model 的 `toArray()`，不同 API 需要不同回應欄位，應在 Controller 直接組裝。

```php
// 內建 toArray()（Plugin 轉為可讀值）
$array = $user->toArray();

// 原始值（Plugin 回傳原始值）
$array = $user->toArray(true);
```

---

## 初始設定

### 資料庫連線

```php
\Orm\Model::setConfig('', \Orm\Core\Config::create()
  ->setHostname('127.0.0.1')
  ->setUsername('root')
  ->setPassword('password')
  ->setDatabase('pix'));
```

支援多組資料庫（讀寫分離）：

```php
\Orm\Model::setConfig('read', \Orm\Core\Config::create()->...);
\Orm\Model::setConfig('write', \Orm\Core\Config::create()->...);

// 使用時指定
$user = User::one(1);           // 預設 db
$user = User::db('read')->one(1); // 指定 db
```

### Model 命名空間

```php
\Orm\Model::setNamespace('App\Model');
```

### 命名慣例

```php
\Orm\Model::setCaseTable(\Orm\Model::CASE_CAMEL);   // User（預設）
\Orm\Model::setCaseColumn(\Orm\Model::CASE_CAMEL);   // createAt（預設）
```

### Log 與除錯

```php
// 不可允許的錯誤
\Orm\Model::setErrorFunc(function(...$args) { /* ... */ });

// SQL Query Log
\Orm\Model::setQueryLogFunc(function($db, $sql, $vals, $status, $during) { /* ... */ });
$lastQuery = \Orm\Model::getLastQueryLog();

// 可允許的錯誤 Log
\Orm\Model::setLogFunc(function($message) { /* ... */ });
$lastLog = \Orm\Model::getLastLog();

// MetaData 快取
\Orm\Model::setCacheFunc('MetaData', fn($key, $closure) => $closure());
```

### Hashids

ID 混淆（用於上傳器檔案路徑）：

```php
\Orm\Model::setHashids(8, 'salt', 'abcdefghijklmnopqrstuvwxyz1234567890');
```

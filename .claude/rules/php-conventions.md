# PHP 後端開發規範

## 執行環境

**PHP 版本：7.4.33 或以上**，開發時務必確認語法與函式相容此版本，禁止使用 PHP 8.0+ 才有的特性（如 named arguments、union types、match、nullsafe operator `?->` 等）。

本機無 PHP，所有 PHP 指令必須透過 Docker 容器執行：

```bash
docker exec php zsh -c "cd ~/Workspace/32_Life/backend && <command>"
```

**重要：** 容器內使用 **zsh**，不要用 bash。

## Migration 檔案命名

Migration 檔案命名必須遵守 CLI 指令（`php Maple.php create -I`）產生的格式：`{3位版本號}-{type} {name} {action} {column}.php`，禁止自創命名：

```bash
# CLI 指令與對應檔名
php Maple.php create -I create User              → 001-create User.php
php Maple.php create -I alter User add token      → 002-alter User add token.php
php Maple.php create -I alter User drop avatar    → 003-alter User drop avatar.php

# ✗ 錯誤：自創命名
002-UserAddToken.php
002-add-token-to-user.php

# ✓ 正確：遵守 CLI 格式
002-alter User add token.php
```

## 資料表必備欄位

所有資料表都必須包含 `id`、`updateAt`、`createAt` 三個欄位，無例外：

```php
// Migration create 範例
$this->create('User', function ($table) {
  $table->column('id')->int()->unsigned()->ai()->comment('PK');
  // ... 其他欄位 ...
  $table->column('updateAt')->datetime()->default('CURRENT_TIMESTAMP')->on('update', 'CURRENT_TIMESTAMP')->comment('更新時間');
  $table->column('createAt')->datetime()->default('CURRENT_TIMESTAMP')->comment('建立時間');
});
```

## 框架：Maple 9

- MVC 架構
- 應用程式碼在 `App/`（Controller、Middleware、Model、View）
- 路由定義在 `Router/Main.php`
- 設定檔在 `Config/`，環境覆蓋在 `Config/Local/`
- `System/` 為框架核心，**禁止修改**

## 命名空間

```
App/Controller/Main.php       → namespace App\Controller;
App/Controller/Api/User.php   → namespace App\Controller\Api;
App/Middleware/Cors.php        → namespace App\Middleware;
App/Model/User.php            → namespace App\Model;
```

## Controller 與 Model 同名時的別名

修改 PHP 檔案前，先讀頂部 `use` 語句確認 Model 別名：

```php
// Controller 本身叫 Photo，Model 必須用別名
use \App\Model\Photo as PhotoModel;

// ✓ 正確
$photo = PhotoModel::one($id);

// ✗ 錯誤：Photo 指向 Controller 自身
$photo = Photo::one($id);
```

### use 語句統一 `\` 開頭

```php
// ✓ 正確
use \App\Model\User;
use \App\Lib\Jwt;
use \Valid;

// ✗ 錯誤：缺少前綴 \
use App\Model\User;
use App\Lib\Jwt;
```

## CLI 指令速查

```bash
php Maple.php init Local        # 初始化
php Maple.php create -I         # 新增 Migration
php Maple.php create -M         # 新增 Model
php Maple.php migration         # 執行 Migration
php Maple.php migration -R      # 重置 Migration（⚠️ 禁止執行，除非用戶明確允許）
```

## Null 合併運算子（`??`）

單層 `??` 可以使用，但禁止串接兩個以上，改用 `if/elseif` 拆開：

```php
// ✓ 正確：單層
$name = $data['name'] ?? '';

// ✗ 錯誤：兩個以上串接，難以閱讀
$value = $a ?? $b ?? '';

// ✓ 正確：拆開寫
$value = '';
if (isset($a)) {
  $value = $a;
} elseif (isset($b)) {
  $value = $b;
}
```

## Nullable 型別宣告

使用 `?type` 語法，不要用 `type = null`：

```php
// ✓ 正確
public function s3Path(?string $version = null): string

// ✗ 錯誤
public function s3Path(string $version = null): string
```

## 錯誤處理

使用全域函式中止流程，不要用 `Response::setCode()` + `Response::output()` + `exit`：

| 函式 | 用途 | 預設 code |
|------|------|-----------|
| `error($message, $code)` | 一般錯誤（驗證失敗、權限不足等） | null |
| `notFound($message)` | 找不到資料 | 404 |

```php
// 一般錯誤
error('Missing authorization code', 400);
error('Account is disabled', 403);

// 找不到資料
notFound('User not found');
```

## 請求參數驗證：禁止直接存取 `$_GET` / `$_POST`

禁止直接使用 `$_GET`、`$_POST` 等超全域變數，一律透過框架方法取得並搭配 `Valid::check()` 驗證：

| 來源 | 取得方式 |
|------|----------|
| Query String | `Request::queries()` |
| JSON Body | `Payload::getJson()` |

**注意**：Query String 值皆為字串型態，數值型驗證必須加 `->isStrict(false)` 允許自動轉型（詳見 `docs/backend/valid.md`）。JSON Body 經 `json_decode` 後型別已正確，不需要加。

```php
// ✗ 錯誤：直接存取 $_GET
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 0;
$name  = $_GET['name'] ?? '';

// ✓ 正確：透過 Valid::check 驗證（Query String 需 isStrict(false)）
list(
  'limit' => $limit,
  'name'  => $name,
) = Valid::check(Request::queries(), [
  'limit' => Valid::uInt_('每頁數量')->isStrict(false)->nullOrNoKey(null),
  'name'  => Valid::string_('名稱')->max(255)->nullOrNoKey(null),
]);
```

## 檔案上傳驗證：禁止直接存取 `$_FILES`

禁止直接使用 `$_FILES`，一律透過 `Payload::getFiles()` 搭配 `Valid::uploadFile()` 驗證：

```php
// ✗ 錯誤：直接存取 $_FILES
$file = $_FILES['banner'];

// ✓ 正確：透過 Valid::check + uploadFile 驗證
list(
  'banner' => $file,
) = Valid::check(Payload::getFiles(), [
  'banner' => Valid::uploadFile('Banner')->maxSize(10 * 1024 * 1024),
]);
```

## Valid 使用注意事項

完整文件：`docs/backend/valid.md`。以下列出容易犯的錯誤：

### array 必須指定元素規則

`Valid::array($title, $rule)` 第二個參數是**必要的**，元素不需要型別驗證時用 `Valid::any()`：

```php
// ✗ 錯誤：缺少 $rule
Valid::array_('佈局項目')->nullOrNoKey([])

// ✓ 正確
Valid::array_('佈局項目', Valid::any('項目'))->nullOrNoKey([])
Valid::array('照片 ID', Valid::id('ID'))
```

### isStrict(false) 只在需要時加

**口訣**：Query String + 數值型（含整數 enum）→ 加；其餘不加。

```php
// ✗ 錯誤：JSON Body 不需要 isStrict(false)
Valid::enum('喜好狀態', array_keys(Photo::IS_FAVORITE))->isStrict(false)

// ✗ 錯誤：string 型 isStrict 無效
Valid::string('照片 ID')->min(1)->isStrict(false)

// ✓ 正確：Query String 數值型才需要
Valid::uInt_('每頁數量')->isStrict(false)->nullOrNoKey(null)
Valid::enum_('類型', [0, 1, 2])->isStrict(false)->nullOrNoKey(0)
```

### enum 搭配 Model const

```php
// ✓ 正確：使用 array_keys + Model const
Valid::enum('類型', array_keys(Album::TYPE))

// ✗ 錯誤：硬編碼
Valid::enum('類型', ['folder', 'album'])
```

## Plugin 欄位值判斷：一律使用 `getValue()`

ORM 的 Plugin 欄位（`datetime`/`date`/`time`、`bindImage`/`bindFile`）永遠回傳 Plugin 物件，不能直接用 `!== null` 或 `=== ''` 判斷。必須透過 `getValue()` 取得原始值：

```php
// ✗ 錯誤：Plugin 物件永遠存在，直接比較永遠為 true
if ($user->banner !== null) { ... }
if ($user->banner !== '') { ... }

// ✓ 正確：透過 getValue() 檢查原始值
if ($user->banner->getValue()) { ... }
$url = $user->banner->getValue() ? $user->banner->getUrl('w1920') : '';

// DateTime 同理
if ($user->deletedAt->getValue() !== null) { ... }
```

## 方法別名優先使用簡短版

框架中許多方法有多個別名（如 `setMinLength` / `minLength` / `min`），一律使用最簡短的版本：

```php
// ✓ 正確
Valid::string('名稱')->min(1)->max(100)
Valid::int('數量')->isStrict(false)

// ✗ 錯誤：冗長
Valid::string('名稱')->setMinLength(1)->setMaxLength(100)
Valid::int('數量')->setIsStrict(false)
```

## Controller 方法簽名

Controller 方法只接收路由參數，不接收 Middleware 傳遞的變數。當前用戶透過 `User::current()` 取得：

```php
// ✓ 正確：只保留路由參數，路由有指定型別（如 uint）則加上型態宣告
public function show(int $id) {
  $user = User::current();
}

public function create() {
  $user = User::current();
}

// ✗ 錯誤：從 Middleware 接收 $user
public function show($id, $user) { ... }
public function create($user) { ... }
```

## Model 的 enum / 布林欄位使用 const

資料表的 enum 值及布林（tinyint）欄位統一在 Model 以 `const` 定義，禁止在 Controller / Middleware 中硬編碼：

```php
// ===== enum 欄位 =====
class Album extends \Orm\Model {
  const TYPE_FOLDER = 'folder';
  const TYPE_ALBUM = 'album';
  const TYPE = [
    self::TYPE_FOLDER => '資料夾',
    self::TYPE_ALBUM => '相簿',
  ];
}

// ✓ 正確：使用 const
if ($type === Album::TYPE_FOLDER) { ... }
Valid::enum('類型', array_keys(Album::TYPE))

// ✗ 錯誤：硬編碼字串
if ($type === 'folder') { ... }
Valid::enum('類型', ['folder', 'album'])

// ===== 布林（tinyint）欄位 =====
class Photo extends \Orm\Model {
  const HAS_GPS_NO  = 0;
  const HAS_GPS_YES = 1;
  const HAS_GPS = [
    self::HAS_GPS_NO  => '無',
    self::HAS_GPS_YES => '有',
  ];
}

// ✓ 正確：使用 const 比較，結果為 bool
$hasGps = $photo->hasGps == Photo::HAS_GPS_YES;
Photo::where('hasGps', Photo::HAS_GPS_YES)->all();

// ✗ 錯誤：直接 (bool) 轉型或硬編碼數字
$hasGps = (bool)$photo->hasGps;
Photo::where('hasGps', 1)->all();
```

## API 回應格式：在 Controller 組裝

禁止覆寫 Model 的 `toArray()`，不同 API 可能需要不同欄位，直接在 Controller 組裝回應：

```php
// ✗ 錯誤：覆寫 Model 的 toArray()
class Album extends \Orm\Model {
  public function toArray(): array {
    return ['id' => $this->id, ...];
  }
}
return ['album' => $album->toArray()];

// ✓ 正確：在 Controller 直接組裝
return ['album' => [
  'id' => $album->id,
  'name' => $album->name,
  'updateAt' => $album->updateAt->format('Y-m-d H:i:s'),
]];
```

## 關聯式陣列 `=>` 對齊

所有關聯式陣列，將 `=>` 對齊方便瀏覽。適用場景包括：`list()` 解構、`Valid::check()` 規則、`$param` 組裝、`curl_setopt_array`、函式參數等。

```php
// ✓ 正確：對齊 =>
$param = [
  'googleId' => 'dev_' . md5($email),
  'email'    => $email,
  'name'     => explode('@', $email)[0],
  'status'   => User::STATUS_ACTIVE,
];

list(
  'type'        => $type,
  'name'        => $name,
  'description' => $description,
) = Valid::check(Payload::getJson(), [
  'type'        => Valid::enum('類型', array_keys(Album::TYPE)),
  'name'        => Valid::string('名稱')->min(1)->max(255),
  'description' => Valid::string_('描述')->max(500)->nullOrNoKey(null),
]);

// ✗ 錯誤：=> 未對齊
$param = [
  'googleId' => 'dev_' . md5($email),
  'email' => $email,
  'name' => explode('@', $email)[0],
  'status' => User::STATUS_ACTIVE,
];
```

## JSON 欄位：使用 ORM 自動序列化

ORM 對 DB 定義為 `json` 型別的欄位自動處理序列化（讀取時 `json_decode`、寫入時 `json_encode`），直接用 PHP array 操作即可，禁止手動 `json_encode` / `json_decode`：

```php
// ✓ 正確：直接用 array
$photo->failedReasons = [['at' => '...', 'error' => '...']];
$photo->save();

$reasons = $photo->failedReasons;  // 自動得到 array
$reasons[] = $newEntry;
$photo->failedReasons = $reasons;

// ✗ 錯誤：手動 json_encode / json_decode
$photo->failedReasons = json_encode($reasons, JSON_UNESCAPED_UNICODE);
$reasons = json_decode($photo->failedReasons, true);
```

**前提**：欄位在 Migration 中必須定義為 `json` 型別。`text` 型別不會自動處理，需儲存 JSON 資料時應使用 `json` 型別。

## DateTime 欄位：透過 Plugin `getValue()` 檢查 null

ORM 的 `datetime`/`date`/`time` 欄位永遠回傳 `DateTime` Plugin 物件（即使 DB 值為 NULL），不能直接用 `!== null` 判斷。必須透過 `getValue()` 取得原始值：

```php
// ✗ 錯誤：永遠為 true，因為 Plugin 物件永遠存在
if ($user->deletedAt !== null) { ... }

// ✓ 正確：透過 getValue() 檢查原始值
if ($user->deletedAt->getValue() !== null) { ... }

// ✓ 正確：格式化輸出（內部為 null 時回傳 null）
$user->createAt->format('Y-m-d H:i:s')

// ✓ 正確：DB 查詢層級不受影響，直接用 null
User::where('deletedAt', null)->all();
```

---

## 資料寫入習慣

### 使用 `transaction()` 包裝寫入操作

所有 `create()`、`save()` 等 DB 寫入操作應用 `transaction()` 包裝，資料準備放在外面。

**⚠️ transaction closure 必須 return truthy 值，否則會 rollback。** 忘記寫 `return` 等同回傳 `null`（falsy），所有寫入都會被回滾。這是最容易犯的錯誤——尤其是多步寫入（迴圈、條件分支）時，容易忘記在最後加 `return`。

```php
// ✓ 正確：參數先組好，transaction 只負責寫入
$param = [
  'name' => $data['name'],
  'email' => $data['email'],
];

$user = transaction(static function () use ($param) {
  return User::create($param);
});

// ✗ 錯誤：忘記 return → 回傳 null → rollback，寫入全部無效
transaction(static function () use ($user) {
  $user->save();
});
```

### 使用 allow 過濾外部資料

當資料來源的 key 不確定（如外部 API 回傳），用 `create()` 或 `set()` 的第二參數 allow 過濾：

```php
// create 白名單
$user = transaction(static function () use ($param) {
  return User::create($param, ['name', 'email', 'status']);
});

// set 白名單（不自動 save，進 transaction 再 save）
$user->set($param, ['name', 'avatar', 'email']);

transaction(static function () use ($user) {
  return $user->save();
});
```

自己組裝的資料（key 確定）不需要 allow。

### 資料準備放在 `transaction()` 外面

屬性設定、讀取查詢等非寫入操作放在外面，`transaction()` 內只放寫入動作（`save()`、`create()`、`delete()`）。例外：寫入之間有相依性（如 `create` 後取 id 給下一筆）才放裡面：

```php
// ✓ 正確：屬性設定、讀取在外
$job->status = JobModel::STATUS_DONE;
$job->endAt  = date('Y-m-d H:i:s');

transaction(static function () use ($job) {
  return $job->save();
});

// ✓ 正確：寫入間有相依性，放在 transaction 內
transaction(static function () use ($param, $obj2) {
  $obj1 = Table1::create($param) ?? error('建立失敗');
  $obj2->obj1Id = $obj1->id;
  return $obj2->save();
});

// ✗ 錯誤：無相依性的屬性設定放在 transaction 裡面
transaction(static function () use ($job) {
  $job->status = JobModel::STATUS_DONE;
  $job->endAt  = date('Y-m-d H:i:s');
  return $job->save();
});
```

### 同一動作的多步寫入整併為一個 `transaction()`

屬於同一動作的多個寫入操作應合併在同一個 `transaction()` 中，每步用 `?? error()` 保護，最後一步直接 return：

```php
// ✓ 正確：同一動作整併為一個 transaction，屬性設定在外
$job->status = JobModel::STATUS_DONE;
$job->endAt  = date('Y-m-d H:i:s');

transaction(static function () use ($photo, $job) {
  $photo->delete() ?? error('刪除照片失敗');
  return $job->save();
});

// ✓ 正確：最後一步在迴圈或條件分支內時，用 return true 結尾
transaction(static function () use ($user, $items) {
  ShowcaseAlbum::where('userId', $user->id)->delete();

  foreach ($items as $param) {
    ShowcaseAlbum::create($param) ?? error('建立失敗');
  }

  return true;
});

// ✗ 錯誤：同一動作拆成多個 transaction
transaction(static function () use ($photo) {
  return $photo->delete();
});

transaction(static function () use ($job) {
  $job->status = JobModel::STATUS_DONE;
  $job->endAt  = date('Y-m-d H:i:s');
  return $job->save();
});
```

## 外鍵命名規範

外鍵欄位必須使用完整表名（小駝峰）+ `Id`，不可縮寫：

```php
// ✓ 正確：完整表名
$showcaseAlbum->showcaseCollectionId  // 引用 ShowcaseCollection 表
$photo->albumId                       // 引用 Album 表

// ✗ 錯誤：縮寫表名
$showcaseAlbum->showcaseId            // 無法辨識引用哪張表
```

---

## 注意事項

- `Config/Local/` 被 .gitignore 排除，不要提交
- `System/_Env.php` 和 `System/_Key.php` 由 `init` 產生，不要提交
- `File/` 目錄（Log、Cache、Tmp）不要提交

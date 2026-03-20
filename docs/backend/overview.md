# 後端框架總覽

## Maple 9（PHP）

Maple 是 OA Wu 開發的 PHP 框架，採用 MVC 架構。本專案運行於 **PHP 7.4.33 或以上**，開發時須確保語法相容此版本。

### 核心特色

- 指令控制框架（CLI）
- Migration 資料庫管理
- Active Record ORM（[Maple-ORM](https://github.com/oawu/Maple-ORM)）
- 驗證系統（Valid）
- 檔案/圖片上傳（Local / S3）

---

## 執行環境

本機無 PHP 環境，透過 Docker 容器執行：

```bash
# 非互動模式（推薦，用於 Claude 執行指令）
docker exec php zsh -c "cd ~/Workspace/32_Life/backend && <command>"

# 互動模式
docker exec -it php zsh
cd ~/Workspace/32_Life/backend
```

---

## 目錄結構

```
backend/
├── Maple.php          # CLI 入口
├── Public/            # Web 入口
│   ├── index.php      # HTTP 入口
│   ├── .htaccess      # Apache URL Rewrite
│   └── Storage/       # 上傳檔案儲存
├── App/               # 應用程式碼
│   ├── Controller/    # 控制器
│   ├── Lib/           # 自訂工具類別
│   ├── Middleware/     # 中介層
│   ├── Model/         # 資料模型（ORM）
│   └── View/          # 視圖
├── Router/            # 路由定義
│   ├── Main.php       # 主路由檔
│   └── Cli.php        # CLI 路由
├── Config/            # 設定檔
│   ├── MySql.php      # 資料庫（預設）
│   ├── Model.php      # Model 上傳設定（預設）
│   ├── S3.php         # S3 儲存設定（預設）
│   ├── Cache.php      # 快取設定
│   ├── Migration.php  # Migration 設定
│   └── Local/         # 本地環境覆蓋設定（.gitignore）
│       ├── MySql.php
│       └── Model.php
├── Migration/         # Migration 檔案
├── File/              # 執行時產生的檔案
│   ├── Log/           # 日誌
│   └── Cache/         # 檔案快取
└── System/            # 框架核心（勿修改）
```

---

## CLI 指令

所有指令需在 `backend/` 目錄下執行：

```bash
# 初始化（依環境）
php Maple.php init Local          # 本地
php Maple.php init Development    # 開發
php Maple.php init Production     # 正式

# Migration（詳見 migration.md）
php Maple.php create -I create User       # 新增建表 Migration
php Maple.php create -I alter User add email  # 新增欄位 Migration
php Maple.php create -M User              # 新增 Model 檔案
php Maple.php create -M User -P avatar    # 新增 Model + 圖片欄位
php Maple.php migration                   # 執行 Migration（更新至最新）
php Maple.php migration -R                # 重置 Migration
```

---

## 設定檔分層

設定檔採用環境分層覆蓋機制：

1. `Config/MySql.php` — 預設設定
2. `Config/Local/MySql.php` — 本地覆蓋（被 .gitignore 排除）

`init` 指令會自動在 `Config/{環境}/` 下建立對應的覆蓋設定檔。

### 讀取設定

```php
use \Config;

// 讀取整個設定檔
$config = Config::get('MySql');

// 讀取巢狀值
$host = Config::get('MySql', 'hostname');
$clientId = Config::get('Auth', 'google', 'clientId');
```

### 自訂設定檔

在 `Config/Local/` 下新增 PHP 檔案，回傳陣列即可：

```php
// Config/Local/Auth.php
<?php
return [
  'google' => [
    'clientId' => 'xxx',
    'clientSecret' => 'xxx',
    'redirectUri' => 'http://127.0.0.1:7100/auth/login',
  ],
];
```

---

## App/Lib

（待開發後補齊）

---

## 全域常數

| 常數 | 來源 | 說明 |
|------|------|------|
| `KEY` | `System/_Key.php` | 加密金鑰（`init` 自動生成，勿提交） |
| `ENVIRONMENT` | `System/_Env.php` | 執行環境（Local / Development / Production） |

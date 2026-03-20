# API 路由表

所有 API 路由前綴為 `/api`，經過 `Api` + `Cors` Middleware。

## 公開路由

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| POST | auth/apple/callback | Api\Auth@appleCallback | Apple Sign In 回調 |

## 需認證路由

經過 `Auth` Middleware，需帶 `Authorization: Bearer <token>` header。

| 方法 | 路由 | Controller | 說明 |
|------|------|-----------|------|
| GET | auth/me | Api\Auth@me | 取得當前用戶 |

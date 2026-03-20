# Worker 架構總覽

（待建立 Worker 後補齊）

## 技術棧

- Node.js 18+
- pm2 常駐服務
- Express HTTP API

## 目錄結構

```
worker/
├── src/
│   ├── index.js         # 入口
│   ├── routes/          # HTTP 路由
│   ├── core/            # 核心模組
│   ├── processors/      # 處理器
│   ├── services/        # 服務模組
│   └── controllers/     # Controller 參數
├── package.json
└── ecosystem.config.js  # pm2 設定
```

## HTTP 端點

| 方法 | 路由 | 說明 |
|------|------|------|
| | | |

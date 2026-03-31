/**
 * Life Worker Service 入口
 *
 * - HTTP server（路由委派給 Router）
 * - 啟動 Dispatcher
 * - Graceful shutdown
 */

const http = require('http')
const config = require('./core/config')
const dispatcher = require('./core/dispatcher')
const router = require('./core/router')
const routes = require('./routes/main')
const logger = require('./core/logger')
const db = require('./core/db')
const execCli = require('./services/exec-cli')
const scheduler = require('./services/scheduler')

const _workerLog = logger.create('main')

const workerConfig = config.getConfig('Worker') || {}
const PORT = workerConfig.port || 8700

// 設定 auth token
if (workerConfig.cliToken) {
  router.setAuthToken(workerConfig.cliToken)
}

// 註冊路由
routes.register()

const server = http.createServer((req, res) => {
  router.handle(req, res)
})

const _rss = () => Math.round(process.memoryUsage().rss / 1024 / 1024)

const start = async () => {
  const env = config.env()
  console.log('[Worker] Starting... (env=' + env + ', rss=' + _rss() + 'MB, pid=' + process.pid + ')')
  _workerLog.info('Starting (env=' + env + ', rss=' + _rss() + 'MB, pid=' + process.pid + ')')

  // dispatcher 暫停啟動（目前無 Job 類型，Job 表尚未建立）
  // await dispatcher.start()
  scheduler.start()

  server.listen(PORT, '0.0.0.0', () => {
    console.log('[Worker] HTTP server listening on 0.0.0.0:' + PORT)
    _workerLog.info('HTTP server listening on 0.0.0.0:' + PORT)
  })
}

const shutdown = async (signal) => {
  console.log('[Worker] Shutting down... (signal=' + signal + ', rss=' + _rss() + 'MB, uptime=' + Math.round(process.uptime()) + 's)')
  _workerLog.info('Shutting down (signal=' + signal + ', rss=' + _rss() + 'MB, uptime=' + Math.round(process.uptime()) + 's)')

  // 1. 停止接收新 Job
  dispatcher.stop()

  // 2. 關閉 HTTP server
  server.close()

  // 3. 終止執行中的 child processes
  execCli.killAll()

  // 4. 停止排程
  scheduler.stop()

  // 5. 等待 Logger 寫入完成
  await logger.waitFinish()

  // 6. 關閉 DB
  await db.close()

  console.log('[Worker] Stopped. (rss=' + _rss() + 'MB)')
  process.exit(0)
}

process.on('SIGINT', () => shutdown('SIGINT'))
process.on('SIGTERM', () => shutdown('SIGTERM'))

process.on('uncaughtException', (err) => {
  const mem = Math.round(process.memoryUsage().rss / 1024 / 1024)
  console.error('[Worker] uncaughtException (rss=' + mem + 'MB):', err.message, err.stack)
  _workerLog.error('uncaughtException (rss=' + mem + 'MB): ' + err.message)
  process.exit(1)
})

process.on('unhandledRejection', (reason) => {
  const mem = Math.round(process.memoryUsage().rss / 1024 / 1024)
  const msg = reason instanceof Error ? reason.message : String(reason)
  console.error('[Worker] unhandledRejection (rss=' + mem + 'MB):', msg)
  _workerLog.error('unhandledRejection (rss=' + mem + 'MB): ' + msg)
})

process.on('exit', (code) => {
  const mem = Math.round(process.memoryUsage().rss / 1024 / 1024)
  console.log('[Worker] exit code=' + code + ' rss=' + mem + 'MB')
})

start().catch((err) => {
  console.error('[Worker] Fatal:', err.message)
  process.exit(1)
})

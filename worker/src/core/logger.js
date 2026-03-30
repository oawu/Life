/**
 * 分類日誌系統
 *
 * - 分類輸出（App / Request）
 * - 每日自動建新檔（YYYYMMDD.log）
 * - 非同步佇列寫入，防止檔案衝突
 * - waitFinish() 優雅關閉
 */

const fs = require('fs')
const path = require('path')
const config = require('./config')
const time = require('./time')

const LOG_DIR = path.join(config.BACKEND_DIR, 'File', 'Log', 'Worker')
const QUEUE_WARN_THRESHOLD = 1000

// 各分類對應子目錄名（皆在 File/Log/Worker/ 下）
const CATEGORIES = {
  main: 'App',
  request: 'Request',
}

// 寫入佇列（序列化寫入，防止同一檔案衝突）
let _queue = []
let _writing = false
let _waitResolve = null

/**
 * 確保目錄存在
 */
const _ensureDir = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true })
  }
}

/**
 * 處理佇列中的寫入任務
 */
const _flush = async () => {
  if (_writing || _queue.length === 0) {
    return
  }

  _writing = true

  while (_queue.length > 0) {
    const { filePath, line } = _queue.shift()

    try {
      await fs.promises.appendFile(filePath, line + '\n', 'utf-8')
    } catch (err) {
      console.error('[Logger] Write error:', err.message)
    }
  }

  _writing = false

  // 如果有人在等 waitFinish
  if (_queue.length === 0 && _waitResolve) {
    _waitResolve()
    _waitResolve = null
  }
}

/**
 * 寫入日誌
 */
const _log = (category, level, message) => {
  const dirName = CATEGORIES[category]

  if (!dirName) {
    return
  }

  const dir = path.join(LOG_DIR, dirName)
  _ensureDir(dir)

  const filePath = path.join(dir, time.today() + '.log')
  const line = '[' + time.timeStr() + '] [' + level + '] ' + message

  _queue.push({ filePath, line })

  if (_queue.length > QUEUE_WARN_THRESHOLD) {
    console.warn('[Logger] Queue size: ' + _queue.length)
  }

  _flush()
}

/**
 * 建立分類 logger
 */
const create = (category) => {
  return {
    info: (msg) => _log(category, 'INFO', msg),
    warn: (msg) => _log(category, 'WARN', msg),
    error: (msg) => _log(category, 'ERROR', msg),
  }
}

/**
 * 等待所有日誌寫入完成（優雅關閉用）
 */
const waitFinish = () => {
  if (_queue.length === 0 && !_writing) {
    return Promise.resolve()
  }

  return new Promise((resolve) => {
    // 安全逾時，避免永遠等待
    const timer = setTimeout(resolve, 5000)
    _waitResolve = () => {
      clearTimeout(timer)
      resolve()
    }
  })
}

module.exports = { create, waitFinish }

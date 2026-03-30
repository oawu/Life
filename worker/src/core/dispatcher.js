/**
 * Job 調度器
 *
 * - 查詢 Job 表（pending / failed + retryCount < MAX_RETRY）
 * - 並發控制（concurrency=3）
 * - 超時管理（300s per job）
 * - Stale job 清理（啟動時）
 * - HTTP /notify 即時通知
 * - Polling fallback（每 3 秒）
 */

const pLimit = require('p-limit')
const db = require('./db')
const config = require('./config')
const logger = require('./logger')
const time = require('./time')
const systemMonitor = require('./system-monitor')

const _log = logger.create('main')

// 任務類型 → processor 映射（暫無任務類型）
const PROCESSORS = {
}

let _running = false
let _dispatching = false
let _pollTimer = null
let _memTimer = null
let _totalProcessed = 0
let _limit = null

// 已 fetch 但尚未完成的 job ID（防止 poll/notify 重複 fetch 同一 job）
const _inflightJobIds = new Set()

/**
 * 清理上次殘留的 processing jobs（Worker 重啟時）
 */
const _cleanStaleJobs = async () => {
  const staleJobs = await db.query(
    'SELECT id, type, targetId, startAt FROM Job WHERE status = ? ORDER BY id ASC',
    ['processing']
  )

  for (const job of staleJobs) {
    await db.execute(
      'UPDATE Job SET status = ?, stage = NULL, updateAt = NOW() WHERE id = ?',
      ['pending', job.id]
    )

    _log.info('Stale job #' + job.id + ' reset to pending')
    console.log('[Dispatcher] Stale job #' + job.id + ' reset to pending')
  }
}

/**
 * 取得待處理 jobs（排除已在處理中的）
 */
const _fetchJobs = async (limit) => {
  if (_inflightJobIds.size === 0) {
    return db.query(
      'SELECT * FROM Job WHERE status IN (?, ?) AND retryCount < ? ORDER BY id ASC LIMIT ?',
      ['pending', 'failed', config.MAX_RETRY, limit]
    )
  }

  const excludePlaceholders = Array.from(_inflightJobIds).map(() => '?').join(',')

  return db.query(
    'SELECT * FROM Job WHERE status IN (?, ?) AND retryCount < ? AND id NOT IN (' + excludePlaceholders + ') ORDER BY id ASC LIMIT ?',
    ['pending', 'failed', config.MAX_RETRY, ...Array.from(_inflightJobIds), limit]
  )
}

/**
 * 標記 job 失敗
 */
const _markJobFailed = async (jobId, stage, errorMsg, duration) => {
  const rows = await db.query('SELECT * FROM Job WHERE id = ?', [jobId])
  const job = rows[0]

  if (!job) {
    return
  }

  const entry = {
    at: time.datetime(),
    stage: stage,
    error: errorMsg,
  }

  const jobErrors = Array.isArray(job.error) ? job.error : []
  jobErrors.push(entry)

  await db.execute(
    'UPDATE Job SET status = ?, stage = ?, error = ?, retryCount = ?, duration = ?, endAt = NOW(), updateAt = NOW() WHERE id = ?',
    ['failed', stage, JSON.stringify(jobErrors), (job.retryCount || 0) + 1, duration ?? null, jobId]
  )
}

/**
 * 處理單一 Job
 */
const _processJob = async (job) => {
  const processorFactory = PROCESSORS[job.type]

  if (!processorFactory) {
    await _markJobFailed(job.id, 'dispatch', '未知的任務類型: ' + job.type)
    _log.warn('Job #' + job.id + ': unknown type ' + job.type)
    console.log('[Dispatcher] Job #' + job.id + ': unknown type ' + job.type)
    return
  }

  const startTime = Date.now()
  job._startTime = startTime

  // 標記為 processing
  await db.execute(
    'UPDATE Job SET status = ?, startAt = NOW(), updateAt = NOW() WHERE id = ?',
    ['processing', job.id]
  )

  const processor = processorFactory()

  let timeoutId
  try {
    const result = await Promise.race([
      processor.process(job),
      new Promise((_, reject) => {
        timeoutId = setTimeout(() => reject(new Error('處理超時 (' + config.TIMEOUT + 's)')), config.TIMEOUT * 1000)
      }),
    ])
    clearTimeout(timeoutId)
    if (global.gc) {
      global.gc()
    }
    const rss = Math.round(process.memoryUsage().rss / 1024 / 1024)
    _log.info('Job #' + job.id + ': ' + result + ' (rss=' + rss + 'MB)')
    console.log('[Dispatcher] Job #' + job.id + ': ' + result + ' (rss=' + rss + 'MB)')
  } catch (err) {
    clearTimeout(timeoutId)
    const duration = Math.round((Date.now() - startTime) / 1000)
    await _markJobFailed(job.id, 'dispatch', err.message, duration)
    if (global.gc) {
      global.gc()
    }
    const rss = Math.round(process.memoryUsage().rss / 1024 / 1024)
    _log.error('Job #' + job.id + ' failed: ' + err.message + ' (rss=' + rss + 'MB)')
    console.error('[Dispatcher] Job #' + job.id + ' failed:', err.message, '(rss=' + rss + 'MB)')
  }
}

/**
 * 檢查並派發任務
 */
const _dispatch = async () => {
  if (!_running || _dispatching) {
    return
  }

  _dispatching = true

  try {
    const availableSlots = config.CONCURRENCY - _limit.activeCount - _limit.pendingCount

    if (availableSlots <= 0) {
      return
    }

    let jobs

    try {
      jobs = await _fetchJobs(availableSlots)
    } catch (err) {
      _log.error('Fetch jobs error: ' + err.message)
      console.error('[Dispatcher] Fetch jobs error:', err.message)
      return
    }

    if (jobs.length === 0) {
      return
    }

    for (const job of jobs) {
      _inflightJobIds.add(job.id)
      _limit(async () => {
        try {
          await _processJob(job)
        } finally {
          _inflightJobIds.delete(job.id)
          _totalProcessed++
          // 完成一個 job 後，立即嘗試取更多
          _dispatch().catch(() => {})
        }
      }).catch(() => {})
    }
  } finally {
    _dispatching = false
  }
}

/**
 * 啟動 Dispatcher
 */
const start = async () => {
  _running = true
  _limit = pLimit(config.CONCURRENCY)

  _log.info('Dispatcher started (concurrency=' + config.CONCURRENCY + ', poll=' + config.POLL_INTERVAL + 'ms)')
  console.log('[Dispatcher] Started (concurrency=' + config.CONCURRENCY + ', poll=' + config.POLL_INTERVAL + 'ms)')

  // 啟動系統指標監控
  systemMonitor.start()

  // 清理 stale jobs + 初始派發（Job 表不存在時跳過）
  try {
    await _cleanStaleJobs()
    await _dispatch()
  } catch (err) {
    _log.warn('Dispatcher init skipped: ' + err.message)
    console.log('[Dispatcher] Init skipped (Job table may not exist):', err.message)
  }

  // 定期記錄記憶體狀態（每 60 秒）
  _memTimer = setInterval(() => {
    const rss = Math.round(process.memoryUsage().rss / 1024 / 1024)
    const heap = Math.round(process.memoryUsage().heapUsed / 1024 / 1024)
    const active = _limit ? _limit.activeCount : 0
    const pending = _limit ? _limit.pendingCount : 0
    _log.info('Status: rss=' + rss + 'MB, heap=' + heap + 'MB, active=' + active + ', pending=' + pending + ', total=' + _totalProcessed + ', uptime=' + Math.round(process.uptime()) + 's')
  }, 60000)

  // Polling fallback
  _pollTimer = setInterval(() => {
    _dispatch().catch((err) => {
      _log.error('Poll error: ' + err.message)
      console.error('[Dispatcher] Poll error:', err.message)
    })
  }, config.POLL_INTERVAL)
}

/**
 * 停止 Dispatcher
 */
const stop = () => {
  _running = false

  if (_pollTimer) {
    clearInterval(_pollTimer)
    _pollTimer = null
  }

  if (_memTimer) {
    clearInterval(_memTimer)
    _memTimer = null
  }

  // 停止系統指標監控
  systemMonitor.stop()

  const rss = Math.round(process.memoryUsage().rss / 1024 / 1024)
  _log.info('Dispatcher stopped (total=' + _totalProcessed + ', rss=' + rss + 'MB)')
  console.log('[Dispatcher] Stopped (total=' + _totalProcessed + ', rss=' + rss + 'MB)')
}

/**
 * 收到 /notify 通知，立即派發
 */
const notify = () => {
  if (!_running) {
    return
  }

  _dispatch().catch((err) => {
    _log.error('Notify dispatch error: ' + err.message)
    console.error('[Dispatcher] Notify dispatch error:', err.message)
  })
}

/**
 * 取得狀態
 */
const status = () => {
  return {
    running: _running,
    activeJobs: _limit ? _limit.activeCount : 0,
    pendingJobs: _limit ? _limit.pendingCount : 0,
    totalProcessed: _totalProcessed,
    concurrency: config.CONCURRENCY,
    pollInterval: config.POLL_INTERVAL,
    system: systemMonitor.snapshot(),
  }
}

module.exports = { start, stop, notify, status }

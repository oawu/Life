/**
 * 排程服務
 *
 * - 每分鐘檢查一次，按設定時間觸發 CLI 任務
 * - 同日同任務只執行一次（防重複）
 * - start() / stop() 對應 Worker 生命週期
 */

const execCli = require('./exec-cli')
const logger = require('../core/logger')
const time = require('../core/time')

const _log = logger.create('main')

// 排程任務定義（暫無排程任務）
const TASKS = [
]

// 已執行記錄（key: 'name:YYYY-MM-DD'）
const _lastRunDates = new Map()

let _timer = null

/**
 * 每分鐘檢查
 */
const _check = () => {
  const { hour, minute } = time.hourMinute()
  const today = time.todayDash()

  for (const task of TASKS) {
    if (task.hour !== hour || task.minute !== minute) {
      continue
    }

    const key = task.name + ':' + today
    if (_lastRunDates.has(key)) {
      continue
    }

    _lastRunDates.set(key, true)
    _log.info('[Scheduler] Running: ' + task.name)

    execCli.exec({ cmd: task.cmd, timeout: 300 }).then((result) => {
      if (result.ok) {
        _log.info('[Scheduler] Done: ' + task.name + ' — ' + result.stdout)
      } else {
        _log.error('[Scheduler] Failed: ' + task.name + ' — ' + (result.error || result.stderr))
      }
    })
  }
}

/**
 * 啟動排程
 */
const start = () => {
  if (_timer) {
    return
  }

  _timer = setInterval(_check, 60 * 1000)
  _log.info('[Scheduler] Started (' + TASKS.length + ' task' + (TASKS.length !== 1 ? 's' : '') + ')')
}

/**
 * 停止排程
 */
const stop = () => {
  if (_timer) {
    clearInterval(_timer)
    _timer = null
  }
}

module.exports = { start, stop }

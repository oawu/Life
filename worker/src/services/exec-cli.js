/**
 * CLI 執行服務
 *
 * - child_process.exec() 執行 shell 命令
 * - 可選 queue name（Named Queue 序列化執行）
 * - 可選 delay（延遲執行）
 * - Debounce 機制（同命令去重）
 * - 可配置 timeout（預設 60s）
 * - 追蹤 active child processes（graceful shutdown 用）
 */

const { exec } = require('child_process')
const queue = require('../core/queue')
const config = require('../core/config')
const logger = require('../core/logger')

const _log = logger.create('main')

const DEFAULT_TIMEOUT = 10 * 60 * 1000      // 10min
const DEFAULT_MAX_BUFFER = 10 * 1024 * 1024  // 10MB

// Debounce timer map：cmd → { timer, resolve }
const _debounceTimers = new Map()

// Active child processes（graceful shutdown 用）
const _activeProcesses = new Set()

// CLI 預設工作目錄 + 環境變數（lazy init）
let _cliDir = null
let _cliEnv = null

/**
 * 初始化（讀取設定）
 */
const _getCliDir = () => {
  if (_cliDir !== null) {
    return _cliDir
  }
  const workerConfig = config.getConfig('Worker') || {}
  _cliDir = workerConfig.cliDir || config.BACKEND_DIR
  return _cliDir
}

const _getCliEnv = () => {
  if (_cliEnv !== null) {
    return _cliEnv
  }
  const workerConfig = config.getConfig('Worker') || {}
  _cliEnv = Object.assign({}, process.env)
  if (workerConfig.cliToken) {
    _cliEnv.WORKER_TOKEN = workerConfig.cliToken
  }
  return _cliEnv
}

/**
 * 執行 shell 命令（核心）
 */
const _execCmd = (cmd, timeout) => {
  return new Promise((resolve) => {
    const child = exec(cmd, {
      cwd: _getCliDir(),
      env: _getCliEnv(),
      timeout: timeout,
      maxBuffer: DEFAULT_MAX_BUFFER,
    }, (error, stdout, stderr) => {
      _activeProcesses.delete(child)

      const result = {
        ok: !error,
        cmd: cmd,
        exitCode: error ? (typeof error.code === 'number' ? error.code : 1) : 0,
        stdout: stdout ? stdout.trim() : '',
        stderr: stderr ? stderr.trim() : '',
      }

      if (error) {
        if (error.killed) {
          result.error = 'Process killed (timeout)'
        } else {
          result.error = error.message
        }
        _log.error('CLI failed: ' + cmd + ' — ' + (result.error || 'unknown'))
      }

      resolve(result)
    })

    _activeProcesses.add(child)
  })
}

/**
 * 執行 CLI 命令
 *
 * @param {Object} options
 * @param {string} options.cmd - 要執行的命令
 * @param {string} [options.queue] - Named Queue 名稱
 * @param {number} [options.delay] - 延遲秒數（啟用 debounce）
 * @param {number} [options.timeout] - 超時秒數（預設 60）
 */
const execCommand = (options) => {
  const { cmd, delay, timeout } = options
  const queueName = options.queue
  const timeoutMs = timeout ? timeout * 1000 : DEFAULT_TIMEOUT

  // 有 delay → debounce 模式
  if (delay && delay > 0) {
    return _debounceExec(cmd, queueName, delay, timeoutMs)
  }

  // 有 queue → 序列化執行
  if (queueName) {
    return _queueExec(cmd, queueName, timeoutMs)
  }

  // 直接執行
  return _execCmd(cmd, timeoutMs)
}

/**
 * Debounce 執行：同命令在 delay 秒內只執行最後一次
 */
const _debounceExec = (cmd, queueName, delay, timeoutMs) => {
  return new Promise((resolve) => {
    const key = cmd + (queueName ? '::' + queueName : '')

    // 清除前一個同命令的 timer，resolve 前一個 caller
    const prev = _debounceTimers.get(key)
    if (prev) {
      clearTimeout(prev.timer)
      prev.resolve({ ok: false, cmd, exitCode: 0, stdout: '', stderr: '', error: 'Debounced (replaced by newer call)' })
    }

    const timer = setTimeout(async () => {
      _debounceTimers.delete(key)

      let result
      if (queueName) {
        result = await _queueExec(cmd, queueName, timeoutMs)
      } else {
        result = await _execCmd(cmd, timeoutMs)
      }

      resolve(result)
    }, delay * 1000)

    _debounceTimers.set(key, { timer, resolve })
  })
}

/**
 * Queue 執行：在 Named Queue 中序列化執行
 */
const _queueExec = (cmd, queueName, timeoutMs) => {
  const limit = queue.get(queueName)
  return limit(() => _execCmd(cmd, timeoutMs))
}

/**
 * 終止所有執行中的 child processes（graceful shutdown）
 */
const killAll = () => {
  // 清除所有 debounce timers，resolve 等待中的 callers
  for (const { timer, resolve } of _debounceTimers.values()) {
    clearTimeout(timer)
    resolve({ ok: false, cmd: '', exitCode: 0, stdout: '', stderr: '', error: 'Shutdown' })
  }
  _debounceTimers.clear()

  // Kill active processes
  for (const child of _activeProcesses) {
    try {
      child.kill('SIGTERM')
    } catch (e) {
      // ignore
    }
  }

  if (_activeProcesses.size > 0) {
    _log.info('Killed ' + _activeProcesses.size + ' active process(es)')
  }

  _activeProcesses.clear()
}

module.exports = { exec: execCommand, killAll }

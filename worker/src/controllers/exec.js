/**
 * Exec Controller — CLI 命令執行
 *
 * POST /exec/cli
 */

const execCli = require('../services/exec-cli')
const logger = require('../core/logger')

const _log = logger.create('main')

/**
 * POST /exec/cli — 執行 CLI 命令
 *
 * Body: { cmd, queue?, delay?, timeout? }
 * - cmd: 要執行的命令（必填）
 * - queue: Named Queue 名稱（選填，序列化執行）
 * - delay: 延遲秒數（選填）
 * - timeout: 超時秒數（選填，預設 60）
 */
const cli = async (body) => {
  if (!body || !body.cmd) {
    const err = new Error('Missing required field: cmd')
    err.statusCode = 400
    throw err
  }

  const { cmd, queue, delay, timeout } = body

  _log.info('CLI exec: ' + cmd + (queue ? ' [queue=' + queue + ']' : '') + (delay ? ' [delay=' + delay + 's]' : ''))

  const result = await execCli.exec({ cmd, queue, delay, timeout })

  return result
}

module.exports = { cli }

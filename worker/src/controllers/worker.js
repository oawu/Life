/**
 * Worker Controller — /notify + /status
 *
 * 從 index.js 抽出的核心路由處理器
 */

const dispatcher = require('../core/dispatcher')

/**
 * POST /notify — 觸發 Job Dispatcher 立即派發
 */
const notify = () => {
  dispatcher.notify()
  return { ok: true }
}

/**
 * GET /status — 回傳 Dispatcher 狀態
 */
const status = () => {
  return dispatcher.status()
}

module.exports = { notify, status }

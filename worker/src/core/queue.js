/**
 * Named Queue — 用 p-limit(1) 實現序列化佇列
 *
 * 同名 queue 內的任務依序執行，不同 queue 之間互不影響。
 * 用於 CLI 執行的 debounce / 序列化需求。
 */

const pLimit = require('p-limit')

const _queues = new Map()

/**
 * 取得指定名稱的 queue（lazy init）
 * @param {string} name
 * @returns {Function} p-limit instance（concurrency=1）
 */
const get = (name) => {
  if (!_queues.has(name)) {
    _queues.set(name, pLimit(1))
  }
  return _queues.get(name)
}

/**
 * 取得所有 queue 名稱
 */
const names = () => {
  return Array.from(_queues.keys())
}

/**
 * 取得各 queue 的待處理數量
 */
const stats = () => {
  const result = {}
  for (const [name, limit] of _queues) {
    result[name] = {
      active: limit.activeCount,
      pending: limit.pendingCount,
    }
  }
  return result
}

module.exports = { get, names, stats }

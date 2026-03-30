/**
 * 系統指標監控 — CPU 取樣與記憶體快照
 *
 * - 每 2 秒取樣 CPU 使用率（os.cpus() 差值計算）
 * - 提供 snapshot() 回傳即時系統指標
 */

const os = require('os')

let _timer = null
let _prevCpus = null
let _cpuUsages = null

/**
 * 取樣 CPU 使用率（需要兩次取樣算差值）
 */
const _sample = () => {
  const cpus = os.cpus()

  if (_prevCpus !== null && _prevCpus.length === cpus.length) {
    _cpuUsages = cpus.map((cpu, i) => {
      const prev = _prevCpus[i].times
      const curr = cpu.times
      const idleDiff  = curr.idle - prev.idle
      const totalDiff = (curr.user + curr.nice + curr.sys + curr.idle + curr.irq)
                      - (prev.user + prev.nice + prev.sys + prev.idle + prev.irq)

      if (totalDiff === 0) {
        return 0
      }

      return Math.round((1 - idleDiff / totalDiff) * 100)
    })
  }

  _prevCpus = cpus
}

/**
 * 啟動定時取樣
 */
const start = () => {
  _sample()
  _timer = setInterval(_sample, 2000)
}

/**
 * 停止定時取樣
 */
const stop = () => {
  if (_timer) {
    clearInterval(_timer)
    _timer = null
  }
  _prevCpus = null
  _cpuUsages = null
}

/**
 * 取得系統指標快照
 */
const snapshot = () => {
  const cpus = os.cpus()
  const totalMem = os.totalmem()
  const freeMem = os.freemem()
  const mem = process.memoryUsage()

  return {
    cpu:     { model: cpus[0] ? cpus[0].model : '', cores: cpus.length, usages: _cpuUsages || [] },
    memory:  { total: totalMem, free: freeMem, used: totalMem - freeMem },
    process: { rss: mem.rss, heapTotal: mem.heapTotal, heapUsed: mem.heapUsed },
    uptime:  Math.round(process.uptime()),
  }
}

module.exports = { start, stop, snapshot }

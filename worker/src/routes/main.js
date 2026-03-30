/**
 * 路由定義
 *
 * POST /worker/notify   → worker.notify     （Job Dispatcher 觸發）
 * GET  /worker/status   → worker.status      （狀態查詢）
 * POST /exec/cli        → exec.cli           （CLI 命令執行，需 auth）
 */

const router = require('../core/router')
const worker = require('../controllers/worker')
const exec = require('../controllers/exec')

const register = () => {
  // 核心功能（無需 auth）
  router.route('POST', '/worker/notify', worker.notify)
  router.route('GET', '/worker/status', worker.status)

  // CLI 執行（需 auth）
  router.route('POST', '/exec/cli', exec.cli, { auth: true })
}

module.exports = { register }

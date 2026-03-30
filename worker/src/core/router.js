/**
 * 路由引擎 — 簡化版
 *
 * - 解析 URL → Map 查找路由（O(1)）→ 執行 Controller
 * - 內建 JSON body 解析
 * - 內建 Bearer Token 驗證（auth middleware）
 * - 統一錯誤處理（Error → JSON 回應）
 * - 非 Production 環境輸出 error stack
 */

const { URL } = require('url')
const config = require('./config')
const logger = require('./logger')

const _requestLog = logger.create('request')

// 路由表：Map<'METHOD /path', { handler, auth }>
const _routes = new Map()

let _authToken = null

/**
 * 設定 auth token（用於需要驗證的路由）
 */
const setAuthToken = (token) => {
  _authToken = token
}

/**
 * 註冊路由
 * @param {string} method - HTTP method
 * @param {string} path - URL path
 * @param {Function} handler - async (body, req) => response
 * @param {Object} options - { auth: boolean }
 */
const route = (method, path, handler, options) => {
  const opts = options || {}
  _routes.set(method + ' ' + path, {
    handler,
    auth: opts.auth || false,
  })
}

/**
 * 解析 JSON body
 */
const _parseBody = (req) => {
  return new Promise((resolve, reject) => {
    // 非 POST/PUT/PATCH 不解析 body
    if (req.method === 'GET' || req.method === 'DELETE' || req.method === 'HEAD') {
      resolve(null)
      return
    }

    const chunks = []
    let size = 0
    let rejected = false
    const maxSize = 1024 * 1024 // 1MB

    req.on('data', (chunk) => {
      if (rejected) {
        return
      }
      size += chunk.length
      if (size > maxSize) {
        rejected = true
        req.destroy()
        reject(new Error('Request body too large'))
        return
      }
      chunks.push(chunk)
    })

    req.on('end', () => {
      if (rejected) {
        return
      }
      if (chunks.length === 0) {
        resolve(null)
        return
      }

      const raw = Buffer.concat(chunks).toString('utf-8')

      try {
        resolve(JSON.parse(raw))
      } catch (e) {
        reject(new Error('Invalid JSON body'))
      }
    })

    req.on('error', reject)
  })
}

/**
 * 驗證 Bearer Token
 */
const _checkAuth = (req) => {
  const header = req.headers['authorization'] || ''
  const match = header.match(/^Bearer\s+(.+)$/i)

  if (!match) {
    return false
  }

  return match[1] === _authToken
}

/**
 * JSON 回應
 */
const _jsonResponse = (res, statusCode, data) => {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify(data))
}

/**
 * 處理 HTTP 請求（供 http.createServer 使用）
 */
const handle = async (req, res) => {
  const startTime = Date.now()
  const parsed = new URL(req.url, 'http://localhost')
  const pathname = parsed.pathname
  const key = req.method + ' ' + pathname

  const matched = _routes.get(key)

  if (!matched) {
    _jsonResponse(res, 404, { error: 'Not Found' })
    _requestLog.info(req.method + ' ' + pathname + ' 404 ' + (Date.now() - startTime) + 'ms')
    return
  }

  // Auth 驗證
  if (matched.auth) {
    if (!_authToken) {
      _jsonResponse(res, 503, { error: 'Auth not configured' })
      _requestLog.warn(req.method + ' ' + pathname + ' 503 auth not configured')
      return
    }

    if (!_checkAuth(req)) {
      _jsonResponse(res, 401, { error: 'Unauthorized' })
      _requestLog.warn(req.method + ' ' + pathname + ' 401')
      return
    }
  }

  try {
    const body = await _parseBody(req)
    const result = await matched.handler(body, req)

    const data = result || { ok: true }
    _jsonResponse(res, 200, data)
    _requestLog.info(req.method + ' ' + pathname + ' 200 ' + (Date.now() - startTime) + 'ms')
  } catch (err) {
    const statusCode = err.statusCode || 500
    const payload = { error: err.message }

    // 非 Production 才輸出 stack
    if (config.env() !== 'Production') {
      payload.stack = err.stack
    }

    _jsonResponse(res, statusCode, payload)
    _requestLog.error(req.method + ' ' + pathname + ' ' + statusCode + ' ' + err.message)
  }
}

module.exports = { route, handle, setAuthToken }

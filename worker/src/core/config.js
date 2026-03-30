/**
 * 設定讀取器 — 解析 backend PHP 設定檔
 *
 * 1. 讀取 System/_Env.php 取得 ENVIRONMENT（Local / Development / Beta / Production）
 * 2. 依環境讀取 Config/{ENVIRONMENT}/ → Config/ fallback
 *    （與 PHP Config::get() 行為一致）
 */

const fs = require('fs')
const path = require('path')

const BACKEND_DIR = path.resolve(__dirname, '../../../backend')
const CONFIG_DIR = path.join(BACKEND_DIR, 'Config')
const WORK_DIR = path.resolve(__dirname, '../../../work')

/**
 * 從 _Env.php 解析 ENVIRONMENT 常數
 */
const getEnvironment = () => {
  const envFile = path.join(BACKEND_DIR, 'System', '_Env.php')

  if (!fs.existsSync(envFile)) {
    throw new Error('System/_Env.php 未找到')
  }

  const content = fs.readFileSync(envFile, 'utf-8')

  // 匹配未被註解的 define('ENVIRONMENT', '...')
  // 排除 // 開頭的註解行
  const lines = content.split('\n')

  for (const line of lines) {
    const trimmed = line.trim()

    // 跳過註解行
    if (trimmed.startsWith('//') || trimmed.startsWith('#') || trimmed.startsWith('*')) {
      continue
    }

    const match = trimmed.match(/define\s*\(\s*'ENVIRONMENT'\s*,\s*'([^']+)'\s*\)/)

    if (match) {
      return match[1]
    }
  }

  throw new Error('無法從 _Env.php 解析 ENVIRONMENT')
}

/**
 * 解析 PHP return array 設定檔
 * 支援格式：return ['key' => 'value', ...]
 */
const parsePhpConfig = (filePath) => {
  if (!fs.existsSync(filePath)) {
    return null
  }

  const content = fs.readFileSync(filePath, 'utf-8')
  const result = {}

  // 匹配 'key' => 'value' 或 "key" => "value" 或 'key' => number
  const regex = /['"](\w+)['"]\s*=>\s*(?:'([^']*)'|"([^"]*)"|(\d+(?:\.\d+)?))/g
  let match

  while ((match = regex.exec(content)) !== null) {
    const key = match[1]
    const value = match[2] !== undefined ? match[2]
      : match[3] !== undefined ? match[3]
      : Number(match[4])
    result[key] = value
  }

  return result
}

let _environment = null

/**
 * 取得當前環境
 */
const env = () => {
  if (_environment) {
    return _environment
  }
  _environment = getEnvironment()
  return _environment
}

/**
 * 讀取設定檔（與 PHP Config::get() 一致）
 * 優先 Config/{ENVIRONMENT}/ → fallback Config/
 */
const getConfig = (filename) => {
  const environment = env()
  const envPath = path.join(CONFIG_DIR, environment, filename + '.php')
  const defaultPath = path.join(CONFIG_DIR, filename + '.php')

  const envConfig = parsePhpConfig(envPath)

  if (envConfig) {
    return envConfig
  }

  return parsePhpConfig(defaultPath)
}

/**
 * 讀取 MySQL 設定
 */
const getMySqlConfig = () => {
  const config = getConfig('MySql')

  if (!config) {
    throw new Error('MySQL 設定檔未找到')
  }

  return {
    host: config.host || '127.0.0.1',
    user: config.username || 'root',
    password: config.password || '',
    database: config.database || '',
  }
}

/**
 * 讀取 _Key.php 中的 KEY 常數
 */
const getKey = () => {
  const keyFile = path.join(BACKEND_DIR, 'System', '_Key.php')

  if (!fs.existsSync(keyFile)) {
    throw new Error('_Key.php 未找到')
  }

  const content = fs.readFileSync(keyFile, 'utf-8')
  const match = content.match(/define\s*\(\s*'KEY'\s*,\s*'([^']+)'\s*\)/)

  if (!match) {
    throw new Error('無法從 _Key.php 解析 KEY')
  }

  return match[1]
}

module.exports = {
  BACKEND_DIR,
  WORK_DIR,
  CONCURRENCY: 3,
  TIMEOUT: 300,
  POLL_INTERVAL: 3000,
  MAX_RETRY: 3,
  env,
  getConfig,
  getMySqlConfig,
  getKey,
}

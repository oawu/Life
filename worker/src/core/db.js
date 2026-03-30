/**
 * MySQL 連線池
 */

const mysql = require('mysql2/promise')
const config = require('./config')

let _pool = null

const getPool = () => {
  if (_pool) {
    return _pool
  }

  const dbConfig = config.getMySqlConfig()

  _pool = mysql.createPool({
    host: dbConfig.host,
    user: dbConfig.user,
    password: dbConfig.password,
    database: dbConfig.database,
    waitForConnections: true,
    connectionLimit: 5,
    idleTimeout: 60000,
    enableKeepAlive: true,
    keepAliveInitialDelay: 10000,
    timezone: '+08:00',
  })

  // 每條新連線設定 session timezone，確保 NOW() 回傳 UTC+8
  _pool.pool.on('connection', (connection) => {
    connection.query("SET time_zone = '+08:00'")
  })

  return _pool
}

/**
 * 執行 SQL 查詢
 * @param {string} sql
 * @param {Array} params
 * @returns {Promise<Array>} rows
 */
const query = async (sql, params = []) => {
  const [rows] = await getPool().query(sql, params)
  return rows
}

/**
 * 執行 SQL（INSERT/UPDATE/DELETE），回傳 ResultSetHeader
 * @param {string} sql
 * @param {Array} params
 * @returns {Promise<object>} result
 */
const execute = async (sql, params = []) => {
  const [result] = await getPool().query(sql, params)
  return result
}

/**
 * 關閉連線池
 */
const close = async () => {
  if (_pool) {
    await _pool.end()
    _pool = null
  }
}

module.exports = { query, execute, close }

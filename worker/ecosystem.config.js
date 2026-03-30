const fs = require('fs')
const path = require('path')

const LOG_DIR = path.resolve(__dirname, '../backend/File/Log/Worker')

// 從 backend/System/_Env.php 讀取環境，區分 pm2 name
const getEnvPrefix = () => {
  try {
    const envFile = path.resolve(__dirname, '../backend/System/_Env.php')
    const content = fs.readFileSync(envFile, 'utf-8')

    for (const line of content.split('\n')) {
      const trimmed = line.trim()

      if (trimmed.startsWith('//') || trimmed.startsWith('#') || trimmed.startsWith('*')) {
        continue
      }

      const match = trimmed.match(/define\s*\(\s*'ENVIRONMENT'\s*,\s*'([^']+)'\s*\)/)

      if (match) {
        return `${match[1].toLowerCase()}-`
      }
    }
  } catch (_) {}

  return ''
}

if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true, mode: 0o777 })
}

const PM2_LOG = path.join(LOG_DIR, 'Pm2.log')

if (!fs.existsSync(PM2_LOG)) {
  fs.writeFileSync(PM2_LOG, '')
}
fs.chmodSync(PM2_LOG, 0o777)

module.exports = {
  apps: [{
    name: `${getEnvPrefix()}life-worker`,
    script: 'src/index.js',
    node_args: '--expose-gc --max-old-space-size=512',
    cwd: __dirname,
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    kill_timeout: 5000,
    log_file: path.join(LOG_DIR, 'Pm2.log'),
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    merge_logs: true,
    env: {
      NODE_ENV: 'production',
    },
  }],
}

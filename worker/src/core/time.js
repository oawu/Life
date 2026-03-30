/**
 * UTC+8 時間工具
 *
 * 統一使用 Asia/Taipei (UTC+8) 時區，
 * 確保所有時間戳與 MySQL NOW() 一致。
 */

const OFFSET_MS = 8 * 60 * 60 * 1000
const _pad = (n) => String(n).padStart(2, '0')

/**
 * 取得 UTC+8 校正後的各欄位
 */
const _parts = () => {
  const now = new Date()
  const d = new Date(now.getTime() + OFFSET_MS + now.getTimezoneOffset() * 60000)
  return {
    y: d.getFullYear(),
    mo: _pad(d.getMonth() + 1),
    day: _pad(d.getDate()),
    h: _pad(d.getHours()),
    m: _pad(d.getMinutes()),
    s: _pad(d.getSeconds()),
    hour: d.getHours(),
    minute: d.getMinutes(),
  }
}

/** YYYYMMDD（Logger 檔名用） */
const today = () => { const p = _parts(); return p.y + p.mo + p.day }

/** YYYY-MM-DD（Scheduler 日期用） */
const todayDash = () => { const p = _parts(); return p.y + '-' + p.mo + '-' + p.day }

/** HH:mm:ss（Logger 時間用） */
const timeStr = () => { const p = _parts(); return p.h + ':' + p.m + ':' + p.s }

/** YYYY-MM-DD HH:mm:ss（MySQL datetime 格式） */
const datetime = () => { const p = _parts(); return p.y + '-' + p.mo + '-' + p.day + ' ' + p.h + ':' + p.m + ':' + p.s }

/** 取得 UTC+8 的小時與分鐘（Scheduler 比對用） */
const hourMinute = () => { const p = _parts(); return { hour: p.hour, minute: p.minute } }

module.exports = { today, todayDash, timeStr, datetime, hourMinute }

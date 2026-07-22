export const SITE_TIME_ZONE = 'Asia/Shanghai'

const DB_DATETIME_PATTERN = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$/
const EXPLICIT_TIME_ZONE_PATTERN = /(?:[zZ]|[+-]\d{2}:?\d{2})$/

const dateTimeFormatter = new Intl.DateTimeFormat('zh-CN', {
  timeZone: SITE_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
})

export const parseSiteDateTime = (raw?: string | null) => {
  if (!raw) return null
  const text = String(raw).trim()
  if (!text) return null

  if (EXPLICIT_TIME_ZONE_PATTERN.test(text)) {
    const explicitDate = new Date(text)
    return Number.isNaN(explicitDate.getTime()) ? null : explicitDate
  }

  const dbMatch = text.match(DB_DATETIME_PATTERN)
  if (dbMatch) {
    const [, year, month, day, hour, minute, second = '00'] = dbMatch
    const utcDate = new Date(`${year}-${month}-${day}T${hour}:${minute}:${second}Z`)
    return Number.isNaN(utcDate.getTime()) ? null : utcDate
  }

  const fallbackDate = new Date(text)
  return Number.isNaN(fallbackDate.getTime()) ? null : fallbackDate
}

export const formatSiteDateTime = (raw?: string | null) => {
  if (!raw) return ''
  const date = parseSiteDateTime(raw)
  if (!date) return String(raw)
  return dateTimeFormatter.format(date)
}

export const formatSiteDate = (
  raw?: string | null,
  locale = 'zh-CN',
  options: Intl.DateTimeFormatOptions = { year: 'numeric', month: 'long', day: 'numeric' },
) => {
  if (!raw) return ''
  const date = parseSiteDateTime(raw)
  if (!date) return String(raw)
  return new Intl.DateTimeFormat(locale || 'zh-CN', {
    timeZone: SITE_TIME_ZONE,
    ...options,
  }).format(date)
}

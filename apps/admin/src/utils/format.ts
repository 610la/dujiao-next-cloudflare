import i18n from '@/i18n'

export const SITE_TIME_ZONE = 'Asia/Shanghai'

const DB_DATETIME_PATTERN = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$/
const EXPLICIT_TIME_ZONE_PATTERN = /(?:[zZ]|[+-]\d{2}:?\d{2})$/
const SITE_TIME_ZONE_OFFSET_MINUTES = 8 * 60

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

const dateOnlyFormatter = new Intl.DateTimeFormat('zh-CN', {
  timeZone: SITE_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
})

const shortDateFormatter = new Intl.DateTimeFormat('zh-CN', {
  timeZone: SITE_TIME_ZONE,
  month: '2-digit',
  day: '2-digit',
})

export const parseSiteDate = (raw?: string | null) => {
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

const parseSiteLocalInput = (raw: string) => {
  const text = raw.trim().replace(' ', 'T')
  if (EXPLICIT_TIME_ZONE_PATTERN.test(text)) return parseSiteDate(text)
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?)?$/)
  if (!match) return parseSiteDate(text)
  const [, year, month, day, hour = '00', minute = '00', second = '00'] = match
  const utcMs = Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute) - SITE_TIME_ZONE_OFFSET_MINUTES,
    Number(second),
  )
  const date = new Date(utcMs)
  return Number.isNaN(date.getTime()) ? null : date
}

export const toRFC3339 = (raw?: string) => {
  if (!raw) return undefined
  const date = parseSiteLocalInput(raw)
  if (!date) return undefined
  return date.toISOString()
}

export const formatDate = (raw?: string) => {
  if (!raw) return ''
  const date = parseSiteDate(raw)
  if (!date) return raw
  return dateTimeFormatter.format(date)
}

export const formatDateOnly = (raw?: string | null) => {
  if (!raw) return ''
  const date = parseSiteDate(raw)
  if (!date) return String(raw)
  return dateOnlyFormatter.format(date)
}

export const formatShortDate = (raw?: string | null) => {
  if (!raw) return '-'
  const date = parseSiteDate(raw)
  if (!date) return String(raw)
  return shortDateFormatter.format(date)
}

export const formatMoney = (amount?: string | number, currency?: string) => {
  if (amount === null || amount === undefined || amount === '') return '-'
  if (!currency) return String(amount)
  return `${amount} ${currency}`
}

export const hasPositiveAmount = (amount?: string | number) => {
  if (amount === null || amount === undefined || amount === '') return false
  const value = Number(amount)
  return !Number.isNaN(value) && value > 0
}

const resolveI18nLocale = () => {
  const globalLocale = (i18n.global.locale as any)?.value || i18n.global.locale || ''
  return String(globalLocale || '').trim()
}

const buildLocaleCandidates = () => {
  const normalized = resolveI18nLocale().replace('_', '-')
  const lower = normalized.toLowerCase()
  if (!lower) return [] as string[]

  const list = new Set<string>([normalized])
  if (lower.startsWith('zh-cn') || lower === 'zh') {
    list.add('zh-CN')
    list.add('zh')
  }
  if (lower.startsWith('zh-tw') || lower.startsWith('zh-hk') || lower.startsWith('zh-mo')) {
    list.add('zh-TW')
  }
  if (lower.startsWith('en')) {
    list.add('en-US')
    list.add('en')
  }

  return Array.from(list)
}

export const getLocalizedText = (jsonData: any): string => {
  if (!jsonData) return ''
  if (typeof jsonData === 'string') {
    const text = jsonData.trim()
    if ((text.startsWith('{') && text.endsWith('}')) || (text.startsWith('[') && text.endsWith(']'))) {
      try {
        return getLocalizedText(JSON.parse(text))
      } catch {
        return jsonData
      }
    }
    return jsonData
  }

  const source = jsonData as Record<string, unknown>
  const localeCandidates = buildLocaleCandidates()
  for (const key of localeCandidates) {
    const val = source[key]
    if (val !== undefined && val !== null && String(val).trim() !== '') {
      return String(val)
    }
  }

  return String(source['zh-CN'] || source['zh-TW'] || source['en-US'] || Object.values(source)[0] || '')
}

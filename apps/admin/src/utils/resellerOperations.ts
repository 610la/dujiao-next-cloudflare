export const resellerOperationsFinancePermission = 'GET:/admin/resellers/operations/finance'

export const hasFinancePermission = (hasPermission: (permission: string) => boolean) =>
  hasPermission(resellerOperationsFinancePermission)

export const buildResellerOperationsAlertClass = (level?: string) => {
  if (level === 'warning') return 'border-amber-200 bg-amber-50 text-amber-800'
  if (level === 'danger') return 'border-rose-200 bg-rose-50 text-rose-800'
  if (level === 'info') return 'border-sky-200 bg-sky-50 text-sky-800'
  return 'border-border bg-muted/30 text-muted-foreground'
}

export const normalizeCurrencyRows = <T extends { currency?: string }>(rows?: T[] | null) =>
  Array.isArray(rows)
    ? rows.map((row) => ({ ...row, currency: String(row.currency || '').trim().toUpperCase() }))
    : []

const padDatePart = (value: number) => String(value).padStart(2, '0')

const formatPeriodBoundary = (raw?: string) => {
  if (!raw) return '-'

  const rfc3339Parts = raw.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?/)
  if (rfc3339Parts) {
    const [, year, month, day, hour, minute, second = '00'] = rfc3339Parts
    return `${year}-${month}-${day} ${hour}:${minute}:${second}`
  }

  const date = new Date(raw)
  if (Number.isNaN(date.getTime())) return raw

  return [
    `${date.getFullYear()}-${padDatePart(date.getMonth() + 1)}-${padDatePart(date.getDate())}`,
    `${padDatePart(date.getHours())}:${padDatePart(date.getMinutes())}:${padDatePart(date.getSeconds())}`,
  ].join(' ')
}

export const formatResellerOperationsPeriod = (from?: string, to?: string) =>
  `${formatPeriodBoundary(from)} - ${formatPeriodBoundary(to)}`

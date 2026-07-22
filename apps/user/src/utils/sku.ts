export const normalizeSkuId = (value: unknown) => {
  const numberValue = Number(value)
  if (!Number.isFinite(numberValue)) return 0
  const integerValue = Math.trunc(numberValue)
  return integerValue > 0 ? integerValue : 0
}

const SUPPORTED_LOCALES = ['zh-CN', 'zh-TW', 'en-US'] as const

const normalizeText = (value: unknown) => String(value ?? '').trim()

const normalizeLocaleCode = (locale?: unknown) => normalizeText(locale).toLowerCase()

const localeFallbacks = (locale?: string) => {
  const normalized = normalizeLocaleCode(locale)
  switch (normalized) {
    case 'zh-tw':
    case 'zh-hk':
    case 'zh-mo':
      return ['zh-TW', 'zh-CN', 'en-US']
    case 'en':
    case 'en-us':
      return ['en-US', 'zh-CN', 'zh-TW']
    case 'zh':
    case 'zh-cn':
    default:
      return ['zh-CN', 'zh-TW', 'en-US']
  }
}

const isLocalizedObject = (value: unknown): value is Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false
  const keys = Object.keys(value)
  if (keys.length === 0) return false
  return keys.every((key) => SUPPORTED_LOCALES.includes(key as typeof SUPPORTED_LOCALES[number]))
}

const resolveLocalizedText = (value: unknown, locale?: string) => {
  if (!isLocalizedObject(value)) return ''
  const rows = value as Record<string, unknown>
  const chain = localeFallbacks(locale)
  for (const code of chain) {
    const text = normalizeText(rows[code])
    if (text) return text
  }
  for (const code of SUPPORTED_LOCALES) {
    const text = normalizeText(rows[code])
    if (text) return text
  }
  return ''
}

const parseJSONLike = (value: unknown): unknown => {
  if (typeof value !== 'string') return value
  const trimmed = value.trim()
  if (!trimmed || (!trimmed.startsWith('{') && !trimmed.startsWith('['))) return value
  try {
    return JSON.parse(trimmed)
  } catch {
    return value
  }
}

const firstNonEmptyValue = (row: Record<string, unknown>, keys: string[]) => {
  for (const key of keys) {
    if (row[key] !== undefined && row[key] !== null && normalizeText(row[key])) {
      return row[key]
    }
  }
  return undefined
}

const formatSpecArray = (values: unknown[], locale?: string) => {
  return values
    .map((entry) => {
      const normalizedEntry = parseJSONLike(entry)
      if (normalizedEntry && typeof normalizedEntry === 'object' && !Array.isArray(normalizedEntry) && !isLocalizedObject(normalizedEntry)) {
        const row = normalizedEntry as Record<string, unknown>
        const label = normalizeText(firstNonEmptyValue(row, ['label', 'name', 'key', 'title', 'spec_name', 'option_name']))
        const value = firstNonEmptyValue(row, ['value', 'val', 'text', 'spec_value', 'option_value'])
        const valueText = normalizeSpecValue(value, locale)
        if (label && valueText) return `${label}:${valueText}`
        if (valueText) return valueText
      }
      return normalizeSpecValue(normalizedEntry, locale)
    })
    .filter(Boolean)
    .join(' / ')
}

const normalizeSpecValue = (raw: unknown, locale?: string): string => {
  const value = parseJSONLike(raw)
  if (Array.isArray(value)) {
    return formatSpecArray(value, locale)
  }
  if (value === null || value === undefined) return ''
  if (isLocalizedObject(value)) {
    return resolveLocalizedText(value, locale)
  }
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .map(([key, entryValue]) => {
        const valueText = normalizeSpecValue(entryValue, locale)
        if (!valueText) return ''
        const keyText = normalizeText(key)
        return keyText ? `${keyText}:${valueText}` : valueText
      })
      .filter(Boolean)
    return entries.join(', ')
  }
  return normalizeText(value)
}

export const formatSkuSpecValues = (specValues: unknown, locale?: string) => {
  const normalizedSpecValues = parseJSONLike(specValues)
  if (!normalizedSpecValues) return ''
  if (Array.isArray(normalizedSpecValues)) {
    return formatSpecArray(normalizedSpecValues, locale)
  }
  if (typeof normalizedSpecValues !== 'object') return normalizeSpecValue(normalizedSpecValues, locale)
  if (isLocalizedObject(normalizedSpecValues)) {
    return resolveLocalizedText(normalizedSpecValues, locale)
  }
  const entries = Object.entries(normalizedSpecValues as Record<string, unknown>)
    .map(([key, value]) => {
      const normalizedValue = normalizeSpecValue(value, locale)
      if (!normalizedValue) return ''
      const normalizedKey = normalizeText(key)
      if (!normalizedKey) return normalizedValue
      return `${normalizedKey}:${normalizedValue}`
    })
    .filter(Boolean)
  return entries.join(' / ')
}

export const buildSkuDisplayText = (payload: {
  skuCode?: unknown
  specValues?: unknown
  fallback?: string
  locale?: string
}) => {
  const specText = formatSkuSpecValues(payload.specValues, payload.locale)
  if (specText) return specText
  return payload.fallback || ''
}

export const buildSkuDisplayTextFromSnapshot = (snapshot: unknown, options?: { fallback?: string; locale?: string }) => {
  const normalizedSnapshot = parseJSONLike(snapshot)
  if (!normalizedSnapshot || typeof normalizedSnapshot !== 'object' || Array.isArray(normalizedSnapshot)) {
    return options?.fallback || ''
  }
  const row = normalizedSnapshot as Record<string, unknown>
  const hasSpecValues = Object.prototype.hasOwnProperty.call(row, 'spec_values')
  const hasSkuMeta = ['sku_code', 'sku_id', 'image'].some((key) => Object.prototype.hasOwnProperty.call(row, key))
  const specValues = hasSpecValues ? row.spec_values : (hasSkuMeta ? undefined : row)
  return buildSkuDisplayText({
    skuCode: row.sku_code,
    specValues,
    fallback: options?.fallback || '',
    locale: options?.locale,
  })
}

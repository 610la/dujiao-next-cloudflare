import type { TranslateFn } from './status'

export type FulfillmentLabelScope = 'orderDetail' | 'admin.orders'

export const fulfillmentTypeLabel = (t: TranslateFn, type?: string, scope: FulfillmentLabelScope = 'orderDetail') => {
  if (!type) return '-'
  const baseKey = `${scope}.fulfillmentTypes`
  const map: Record<string, string> = {
    manual: t(`${baseKey}.manual`),
    auto: t(`${baseKey}.auto`),
  }
  return map[type] || type
}

export const fulfillmentStatusLabel = (
  t: TranslateFn,
  status?: string,
  scope: FulfillmentLabelScope = 'orderDetail'
) => {
  if (!status) return '-'
  const baseKey = `${scope}.fulfillmentStatuses`
  const map: Record<string, string> = {
    pending: t(`${baseKey}.pending`),
    delivered: t(`${baseKey}.delivered`),
  }
  return map[status] || status
}

const scalarDeliveryText = (value: unknown) => {
  if (typeof value === 'string') return value.trim()
  if (typeof value === 'number' && Number.isFinite(value)) return String(value)
  if (typeof value === 'boolean') return String(value)
  return ''
}

const recordValue = (value: unknown): Record<string, unknown> | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  return value as Record<string, unknown>
}

export const fulfillmentDeliveryLines = (fulfillment: unknown): string[] => {
  const fulfillmentRecord = recordValue(fulfillment)
  if (!fulfillmentRecord) return []

  const deliveryData = recordValue(fulfillmentRecord.delivery_data)
    || recordValue(fulfillmentRecord.logistics)
  if (!deliveryData) return []

  const lines: string[] = []
  const note = scalarDeliveryText(deliveryData.note)
  if (note) lines.push(note)

  const entries = Array.isArray(deliveryData.entries) ? deliveryData.entries : []
  entries.forEach((rawEntry) => {
    const entry = recordValue(rawEntry)
    if (!entry) return
    const key = scalarDeliveryText(entry.key)
    const value = scalarDeliveryText(entry.value)
    if (!key && !value) return
    if (!key) lines.push(value)
    else if (!value) lines.push(key)
    else lines.push(`${key}: ${value}`)
  })

  if (lines.length > 0) return lines

  Object.entries(deliveryData).forEach(([key, value]) => {
    if (key === 'note' || key === 'entries') return
    const text = scalarDeliveryText(value)
    if (text) lines.push(`${key}: ${text}`)
  })

  return lines
}

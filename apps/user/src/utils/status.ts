export type TranslateFn = (...args: any[]) => string

export const orderStatusLabel = (t: TranslateFn, status?: string) => {
  if (!status) return '-'
  const map: Record<string, string> = {
    pending_payment: t('order.status.pending_payment'),
    paid: t('order.status.paid'),
    fulfilling: t('order.status.fulfilling'),
    partially_delivered: t('order.status.partially_delivered'),
    partially_refunded: t('order.status.partially_refunded'),
    delivered: t('order.status.delivered'),
    completed: t('order.status.completed'),
    expired: t('order.status.expired'),
    canceled: t('order.status.canceled'),
    refunded: t('order.status.refunded'),
  }
  return map[status] || status
}

export type BadgeTone = 'success' | 'warning' | 'info' | 'danger' | 'accent' | 'neutral'

export const orderStatusVariant = (status?: string): BadgeTone => {
  switch (status) {
    case 'pending_payment':
    case 'partially_refunded':
      return 'warning'
    case 'paid':
    case 'delivered':
    case 'completed':
      return 'success'
    case 'partially_delivered':
    case 'refunded':
      return 'info'
    case 'fulfilling':
      return 'accent'
    case 'expired':
      return 'danger'
    case 'canceled':
    default:
      return 'neutral'
  }
}

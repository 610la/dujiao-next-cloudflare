interface CheckoutOrderSnapshotStorage {
  getItem: (key: string) => string | null
  setItem: (key: string, value: string) => void
  removeItem: (key: string) => void
}

const SNAPSHOT_PREFIX = 'dujiao:checkout-order:'
const SNAPSHOT_MAX_AGE_MS = 60_000

const defaultStorage = (): CheckoutOrderSnapshotStorage | null => {
  if (typeof window === 'undefined') return null
  try {
    return window.sessionStorage
  } catch {
    return null
  }
}

const snapshotKey = (orderNo: string) => `${SNAPSHOT_PREFIX}${orderNo.trim()}`

export const saveCheckoutOrderSnapshot = (
  orderNo: string,
  order: unknown,
  storage: CheckoutOrderSnapshotStorage | null = defaultStorage(),
  now = Date.now(),
): boolean => {
  const normalizedOrderNo = String(orderNo || '').trim()
  if (!storage || !normalizedOrderNo || !order || typeof order !== 'object') return false
  if (String((order as Record<string, unknown>).order_no || '').trim() !== normalizedOrderNo) return false
  try {
    storage.setItem(snapshotKey(normalizedOrderNo), JSON.stringify({ order, saved_at: now }))
    return true
  } catch {
    return false
  }
}

export const consumeCheckoutOrderSnapshot = (
  orderNo: string,
  storage: CheckoutOrderSnapshotStorage | null = defaultStorage(),
  now = Date.now(),
): any | null => {
  const normalizedOrderNo = String(orderNo || '').trim()
  if (!storage || !normalizedOrderNo) return null
  const key = snapshotKey(normalizedOrderNo)
  try {
    const raw = storage.getItem(key)
    storage.removeItem(key)
    if (!raw) return null
    const snapshot = JSON.parse(raw)
    const savedAt = Number(snapshot?.saved_at || 0)
    const order = snapshot?.order
    if (!Number.isFinite(savedAt) || savedAt <= 0 || now - savedAt > SNAPSHOT_MAX_AGE_MS) return null
    if (!order || typeof order !== 'object') return null
    if (String(order.order_no || '').trim() !== normalizedOrderNo) return null
    if (String(order.status || '') !== 'pending_payment') return null
    return order
  } catch {
    try {
      storage.removeItem(key)
    } catch {}
    return null
  }
}

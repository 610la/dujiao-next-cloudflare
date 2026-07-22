const STORAGE_KEY = 'checkout_request_attempt_v1'

type CheckoutAttemptRecord = {
  fingerprint: string
  requestId: string
}

type StorageLike = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>

const stableJson = (value: unknown): string => {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`
  if (value && typeof value === 'object') {
    return `{${Object.entries(value as Record<string, unknown>)
      .filter(([, entry]) => entry !== undefined)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, entry]) => `${JSON.stringify(key)}:${stableJson(entry)}`)
      .join(',')}}`
  }
  return JSON.stringify(value) ?? 'null'
}

const fallbackHash = (value: string) => {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return (hash >>> 0).toString(16).padStart(8, '0')
}

export const checkoutAttemptFingerprint = async (value: unknown) => {
  const serialized = stableJson(value)
  if (!globalThis.crypto?.subtle) return fallbackHash(serialized)
  const digest = await globalThis.crypto.subtle.digest('SHA-256', new TextEncoder().encode(serialized))
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

const createRequestId = () => {
  const uuid = globalThis.crypto?.randomUUID?.()
  if (uuid) return `checkout_${uuid}`
  return `checkout_${Date.now()}_${Math.random().toString(36).slice(2, 18)}`
}

const parseStoredAttempt = (storage: StorageLike): CheckoutAttemptRecord | null => {
  try {
    const parsed = JSON.parse(storage.getItem(STORAGE_KEY) || 'null')
    if (!parsed || typeof parsed !== 'object') return null
    const fingerprint = String(parsed.fingerprint || '')
    const requestId = String(parsed.requestId || '')
    if (!fingerprint || !/^[A-Za-z0-9][A-Za-z0-9_-]{15,127}$/.test(requestId)) return null
    return { fingerprint, requestId }
  } catch {
    return null
  }
}

export const getOrCreateCheckoutRequestId = async (value: unknown, storage: StorageLike = sessionStorage) => {
  const fingerprint = await checkoutAttemptFingerprint(value)
  const stored = parseStoredAttempt(storage)
  if (stored?.fingerprint === fingerprint) return stored.requestId

  const requestId = createRequestId()
  try {
    storage.setItem(STORAGE_KEY, JSON.stringify({ fingerprint, requestId }))
  } catch {}
  return requestId
}

export const clearCheckoutRequestId = (requestId: string, storage: StorageLike = sessionStorage) => {
  const stored = parseStoredAttempt(storage)
  if (!stored || stored.requestId !== requestId) return
  try {
    storage.removeItem(STORAGE_KEY)
  } catch {}
}

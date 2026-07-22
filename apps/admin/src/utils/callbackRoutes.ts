export const CALLBACK_ROUTE_KEYS = [
  'payment_callback',
  'dujiaopay_webhook',
  'paypal_webhook',
  'stripe_webhook',
  'upstream_callback',
] as const

export type CallbackRouteKey = (typeof CALLBACK_ROUTE_KEYS)[number]

export type CallbackRoutesValue = Record<CallbackRouteKey, string>

export const DEFAULT_CALLBACK_ROUTE_PATHS: CallbackRoutesValue = {
  payment_callback: '/api/v1/payments/callback',
  dujiaopay_webhook: '/api/v1/payments/webhook/dujiaopay',
  paypal_webhook: '/api/v1/payments/webhook/paypal',
  stripe_webhook: '/api/v1/payments/webhook/stripe',
  upstream_callback: '/api/v1/upstream/callback',
}

export const normalizeCallbackRouteInput = (value: unknown): string => {
  return String(value || '').trim().replace(/\/+$/, '')
}

export const getCallbackRouteDisplayValue = (key: CallbackRouteKey, value: unknown): string => {
  return normalizeCallbackRouteInput(value) || DEFAULT_CALLBACK_ROUTE_PATHS[key]
}

export const toCallbackRouteSaveValue = (key: CallbackRouteKey, value: unknown): string => {
  const normalized = normalizeCallbackRouteInput(value)
  if (normalized === DEFAULT_CALLBACK_ROUTE_PATHS[key]) {
    return ''
  }
  return normalized
}

export const buildCallbackRoutesSavePayload = (value: Partial<Record<CallbackRouteKey, unknown>>): CallbackRoutesValue => {
  return CALLBACK_ROUTE_KEYS.reduce((payload, key) => {
    payload[key] = toCallbackRouteSaveValue(key, value[key])
    return payload
  }, {} as CallbackRoutesValue)
}

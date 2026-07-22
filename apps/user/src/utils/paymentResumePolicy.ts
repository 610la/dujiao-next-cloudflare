export type PaymentResetReason = 'generic' | 'route_change' | 'change_payment_method'

export interface PaymentResetPolicy {
  resumeLatestPayment: boolean
  clearSelectedChannel: boolean
  stopActivePaymentWatch: boolean
}

export interface CachedPaymentRestorePolicy {
  startActivePaymentWatch: boolean
  autoOpenPayLink: boolean
}

export const getPaymentResetPolicy = (reason: PaymentResetReason = 'generic'): PaymentResetPolicy => {
  if (reason === 'change_payment_method') {
    return {
      resumeLatestPayment: false,
      clearSelectedChannel: true,
      stopActivePaymentWatch: true,
    }
  }

  return {
    resumeLatestPayment: true,
    clearSelectedChannel: false,
    stopActivePaymentWatch: false,
  }
}

export const getCachedPaymentRestorePolicy = (): CachedPaymentRestorePolicy => ({
  startActivePaymentWatch: true,
  autoOpenPayLink: false,
})

export const shouldAutoOpenPaymentLink = (payment?: { interaction_mode?: unknown; pay_url?: unknown } | null) => {
  if (!payment) return false
  const mode = String(payment.interaction_mode || '').trim().toLowerCase()
  const payURL = String(payment.pay_url || '').trim()
  return mode === 'redirect' && payURL !== ''
}

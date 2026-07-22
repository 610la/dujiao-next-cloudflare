import test from 'node:test'
import assert from 'node:assert/strict'
import {
  getCachedPaymentRestorePolicy,
  getPaymentResetPolicy,
  shouldAutoOpenPaymentLink,
} from '../src/utils/paymentResumePolicy.ts'

test('manual payment method changes do not auto resume the latest payment', () => {
  assert.deepEqual(getPaymentResetPolicy('change_payment_method'), {
    resumeLatestPayment: false,
    clearSelectedChannel: true,
    stopActivePaymentWatch: true,
  })
})

test('route changes keep the normal latest payment resume behavior', () => {
  assert.deepEqual(getPaymentResetPolicy('route_change'), {
    resumeLatestPayment: true,
    clearSelectedChannel: false,
    stopActivePaymentWatch: false,
  })
})

test('cached payment restore resumes status watching without opening a cashier', () => {
  assert.deepEqual(getCachedPaymentRestorePolicy(), {
    startActivePaymentWatch: true,
    autoOpenPayLink: false,
  })
})

test('only redirect payments with a pay link are auto opened', () => {
  assert.equal(
    shouldAutoOpenPaymentLink({ interaction_mode: 'redirect', pay_url: 'https://pay.example.com' }),
    true,
  )
  assert.equal(
    shouldAutoOpenPaymentLink({ interaction_mode: 'qr', pay_url: 'https://pay.example.com' }),
    false,
  )
  assert.equal(
    shouldAutoOpenPaymentLink({ interaction_mode: 'redirect', pay_url: '   ' }),
    false,
  )
})

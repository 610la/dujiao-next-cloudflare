import test from 'node:test'
import assert from 'node:assert/strict'
import {
  checkoutAttemptFingerprint,
  clearCheckoutRequestId,
  getOrCreateCheckoutRequestId,
} from '../src/utils/checkoutAttempt.ts'

const memoryStorage = () => {
  const values = new Map<string, string>()
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { values.set(key, value) },
    removeItem: (key: string) => { values.delete(key) },
  }
}

test('checkout fingerprint is stable across object key order', async () => {
  assert.equal(
    await checkoutAttemptFingerprint({ items: [{ sku: 1, quantity: 2 }], useBalance: true }),
    await checkoutAttemptFingerprint({ useBalance: true, items: [{ quantity: 2, sku: 1 }] }),
  )
})

test('same checkout reuses one request id and changed checkout rotates it', async () => {
  const storage = memoryStorage()
  const first = await getOrCreateCheckoutRequestId({ sku: 1, quantity: 1 }, storage)
  const retry = await getOrCreateCheckoutRequestId({ quantity: 1, sku: 1 }, storage)
  const changed = await getOrCreateCheckoutRequestId({ sku: 1, quantity: 2 }, storage)

  assert.equal(retry, first)
  assert.notEqual(changed, first)
})

test('successful checkout only clears its own stored request id', async () => {
  const storage = memoryStorage()
  const first = await getOrCreateCheckoutRequestId({ sku: 1 }, storage)
  clearCheckoutRequestId('checkout_another_request_123456', storage)
  assert.equal(await getOrCreateCheckoutRequestId({ sku: 1 }, storage), first)
  clearCheckoutRequestId(first, storage)
  assert.notEqual(await getOrCreateCheckoutRequestId({ sku: 1 }, storage), first)
})

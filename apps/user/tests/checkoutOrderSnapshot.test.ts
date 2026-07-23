import test from 'node:test'
import assert from 'node:assert/strict'
import {
  consumeCheckoutOrderSnapshot,
  saveCheckoutOrderSnapshot,
} from '../src/utils/checkoutOrderSnapshot.ts'

const memoryStorage = () => {
  const values = new Map<string, string>()
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { values.set(key, value) },
    removeItem: (key: string) => { values.delete(key) },
  }
}

test('fresh pending checkout order snapshot is consumed once', () => {
  const storage = memoryStorage()
  const order = { order_no: 'DJ100', status: 'pending_payment', total_amount: 15 }
  assert.equal(saveCheckoutOrderSnapshot('DJ100', order, storage, 1_000), true)
  assert.deepEqual(consumeCheckoutOrderSnapshot('DJ100', storage, 20_000), order)
  assert.equal(consumeCheckoutOrderSnapshot('DJ100', storage, 20_000), null)
})

test('expired or mismatched checkout order snapshots are rejected', () => {
  const storage = memoryStorage()
  assert.equal(saveCheckoutOrderSnapshot('DJ100', { order_no: 'DJ200', status: 'pending_payment' }, storage, 1_000), false)
  saveCheckoutOrderSnapshot('DJ100', { order_no: 'DJ100', status: 'pending_payment' }, storage, 1_000)
  assert.equal(consumeCheckoutOrderSnapshot('DJ100', storage, 70_001), null)
})

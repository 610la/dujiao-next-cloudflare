import test from 'node:test'
import assert from 'node:assert/strict'
import { fulfillmentDeliveryLines } from '../src/utils/fulfillment.ts'

test('fulfillment delivery lines format direct manual fields', () => {
  assert.deepEqual(
    fulfillmentDeliveryLines({
      delivery_data: {
        note: '已寄出',
        entries: [{ key: '顺丰', value: 'SF000000000' }],
      },
    }),
    ['已寄出', '顺丰: SF000000000'],
  )
})

test('fulfillment delivery lines ignore aggregate objects so payload can render', () => {
  const lines = fulfillmentDeliveryLines({
    payload: '顺丰：SF000000000',
    delivery_data: {
      components: [
        {
          source_type: 'manual',
          delivery_data: {
            entries: [{ key: '顺丰', value: 'SF000000000' }],
          },
        },
      ],
      manual: {
        entries: [{ key: '顺丰', value: 'SF000000000' }],
      },
    },
  })

  assert.deepEqual(lines, [])
  assert.equal(lines.some((line) => line.includes('[object Object]')), false)
})

test('fulfillment delivery lines keep primitive legacy logistics fields only', () => {
  assert.deepEqual(
    fulfillmentDeliveryLines({
      logistics: {
        carrier: '顺丰',
        tracking_number: 'SF000000000',
        metadata: { internal: true },
      },
    }),
    ['carrier: 顺丰', 'tracking_number: SF000000000'],
  )
})

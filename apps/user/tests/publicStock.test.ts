import test from 'node:test'
import assert from 'node:assert/strict'
import {
  resolveSkuAvailableStock,
  resolveSkuStockDisplay,
} from '../src/utils/publicStock.ts'

test('hidden public stock does not expose exact sku purchase limit or count', () => {
  const product = { fulfillment_type: 'manual', stock_display_mode: 'status' }
  const sku = {
    manual_stock_total: 37,
    stock_status: 'in_stock',
    stock_display: 'in_stock',
    stock_quantity_hidden: true,
  }

  assert.equal(resolveSkuAvailableStock(product, sku), null)
  assert.deepEqual(resolveSkuStockDisplay(product, sku), { kind: 'in_stock' })
})

test('exact public stock keeps current sku quantity behavior', () => {
  const product = { fulfillment_type: 'manual', stock_display_mode: 'exact' }
  const sku = {
    manual_stock_total: 37,
    stock_status: 'in_stock',
    stock_display: 'exact',
    stock_quantity_hidden: false,
  }

  assert.equal(resolveSkuAvailableStock(product, sku), 37)
  assert.deepEqual(resolveSkuStockDisplay(product, sku), { kind: 'remaining', count: 37 })
})

test('range public stock returns bucket without exact count', () => {
  const product = { fulfillment_type: 'manual', stock_display_mode: 'range' }
  const sku = {
    manual_stock_total: 1,
    stock_status: 'in_stock',
    stock_display: 'range_21_50',
    stock_range_min: 21,
    stock_range_max: 50,
    stock_quantity_hidden: true,
  }

  assert.equal(resolveSkuAvailableStock(product, sku), null)
  assert.deepEqual(resolveSkuStockDisplay(product, sku), { kind: 'range', min: 21, max: 50 })
})

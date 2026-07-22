import test from 'node:test'
import assert from 'node:assert/strict'
import {
  buildResellerProductSettingPayload,
  getResellerPricingModeLabelKey,
  isResellerProductSettingDetail,
  normalizeResellerProductSettingsPagination,
  normalizeResellerProductSettingForm,
  summarizeEffectivePrice,
} from '../src/utils/resellerProductSettings.ts'

test('pricing mode label keys are stable', () => {
  assert.equal(getResellerPricingModeLabelKey('inherit'), 'inherit')
  assert.equal(getResellerPricingModeLabelKey('markup_percent'), 'markupPercent')
  assert.equal(getResellerPricingModeLabelKey('fixed_markup'), 'fixedMarkup')
  assert.equal(getResellerPricingModeLabelKey('fixed_price'), 'fixedPrice')
  assert.equal(getResellerPricingModeLabelKey('bad'), 'unknown')
})

test('form normalization defaults money fields and listed state', () => {
  assert.deepEqual(normalizeResellerProductSettingForm({ sku_id: 3 }), {
    sku_id: 3,
    is_listed: true,
    pricing_mode: 'inherit',
    markup_percent: '0.00',
    fixed_markup_amount: '0.00',
    fixed_price_amount: '0.00',
    sort_order: 0,
  })
})

test('payload builder trims empty rows by explicit sku scope', () => {
  const payload = buildResellerProductSettingPayload([
    { sku_id: 0, is_listed: true, pricing_mode: 'markup_percent', markup_percent: ' 12.50 ', fixed_markup_amount: '', fixed_price_amount: '', sort_order: 0 },
  ])
  assert.deepEqual(payload, {
    settings: [
      { sku_id: 0, is_listed: true, pricing_mode: 'markup_percent', markup_percent: '12.50', fixed_markup_amount: '0.00', fixed_price_amount: '0.00', sort_order: 0 },
    ],
  })
})

test('effective price summary prefers explicit effective price', () => {
  assert.equal(summarizeEffectivePrice({ effective_price_amount: '128.00', pricing_mode: 'fixed_price' }), '128.00')
  assert.equal(summarizeEffectivePrice(null), '-')
})

test('reset response is not treated as product setting detail', () => {
  assert.equal(isResellerProductSettingDetail({ deleted: true }), false)
  assert.equal(
    isResellerProductSettingDetail({
      product: { id: 9, title: { 'zh-CN': '商品' }, slug: 'demo', price_amount: '10.00', is_active: true },
      skus: [],
    }),
    true,
  )
})

test('product settings pagination normalizes API pagination payloads', () => {
  assert.deepEqual(
    normalizeResellerProductSettingsPagination({ page: '2', page_size: '30', total: '61', total_page: '3' }),
    { page: 2, page_size: 30, total: 61, total_page: 3 },
  )
  assert.deepEqual(
    normalizeResellerProductSettingsPagination(null, { page: 4, page_size: 20, total: 80, total_page: 4 }),
    { page: 4, page_size: 20, total: 80, total_page: 4 },
  )
})

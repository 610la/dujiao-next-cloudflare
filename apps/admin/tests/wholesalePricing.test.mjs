import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { rmSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import test from 'node:test'

const __dirname = dirname(fileURLToPath(import.meta.url))
const root = join(__dirname, '..')
const outDir = join(root, '.codex-test-output', 'wholesalePricing')

async function loadModule() {
  rmSync(outDir, { recursive: true, force: true })
  const tscScript = join(root, '..', '..', 'node_modules', 'typescript', 'bin', 'tsc')
  execFileSync(
    process.execPath,
    [
      tscScript,
      'src/utils/wholesalePricing.ts',
      '--target',
      'ES2022',
      '--module',
      'ES2022',
      '--moduleResolution',
      'bundler',
      '--strict',
      '--skipLibCheck',
      '--outDir',
      outDir,
    ],
    { cwd: root, stdio: 'pipe' },
  )
  return import(`${pathToFileURL(join(outDir, 'wholesalePricing.js')).href}?t=${Date.now()}`)
}

test('buildWholesaleSkuPriceReferences explains which SKUs are affected by current wholesale tiers', async () => {
  const { buildWholesaleSkuPriceReferences, hasMultipleActiveWholesaleSkus } = await loadModule()
  const product = {
    skus: [
      {
        id: 3,
        sku_code: 'YEAR',
        spec_values: { 'zh-CN': '年卡' },
        price_amount: 100,
        sort_order: 2,
        is_active: true,
      },
      {
        id: 2,
        sku_code: 'MONTH',
        spec_values: { 'zh-CN': '月卡' },
        price_amount: 50,
        sort_order: 1,
        is_active: true,
      },
      {
        id: 4,
        sku_code: 'OFF',
        spec_values: { 'zh-CN': '停用' },
        price_amount: 200,
        sort_order: 3,
        is_active: false,
      },
    ],
  }

  assert.equal(hasMultipleActiveWholesaleSkus(product), true)

  const refs = buildWholesaleSkuPriceReferences(product, {
    tiers: [{ min_quantity: 10, unit_price: 80 }],
    locale: 'zh-CN',
    formatPrice: (amount) => `${amount} CNY`,
  })

  assert.deepEqual(
    refs.map((item) => ({
      id: item.id,
      label: item.label,
      priceText: item.priceText,
      tierApplies: item.tierApplies,
    })),
    [
      { id: 2, label: '月卡', priceText: '50 CNY', tierApplies: false },
      { id: 3, label: '年卡', priceText: '100 CNY', tierApplies: true },
    ],
  )
})

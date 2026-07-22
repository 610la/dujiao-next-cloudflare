import test from 'node:test'
import assert from 'node:assert/strict'
import {
  canRenderResellerConsoleModule,
  getResellerConsoleState,
  resolveResellerConsoleModule,
} from '../src/utils/resellerConsole.ts'

test('reseller console route gate blocks active-only modules until profile is active', () => {
  const pendingState = getResellerConsoleState({
    opened: true,
    can_apply: false,
    profile: { status: 'pending_review' },
    domains: [],
  } as any)
  const activeState = getResellerConsoleState({
    opened: true,
    can_apply: false,
    profile: { status: 'active' },
    domains: [],
  } as any)

  assert.equal(resolveResellerConsoleModule('/reseller/products'), 'products')
  assert.equal(canRenderResellerConsoleModule('/reseller/apply', pendingState), true)
  assert.equal(canRenderResellerConsoleModule('/reseller', pendingState), true)
  assert.equal(canRenderResellerConsoleModule('/reseller/products', pendingState), false)
  assert.equal(canRenderResellerConsoleModule('/reseller/products', activeState), true)
})

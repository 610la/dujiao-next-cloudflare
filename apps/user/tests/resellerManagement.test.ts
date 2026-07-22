import test from 'node:test'
import assert from 'node:assert/strict'
import {
  getResellerDomainStatusKey,
  getResellerManagementState,
  getResellerProfileStatusKey,
  isResellerProfileActive,
} from '../src/utils/resellerManagement.ts'

test('user reseller profile status keys map backend values', () => {
  assert.equal(getResellerProfileStatusKey('pending_review'), 'pendingReview')
  assert.equal(getResellerProfileStatusKey('active'), 'active')
  assert.equal(getResellerProfileStatusKey('rejected'), 'rejected')
  assert.equal(getResellerProfileStatusKey('disabled'), 'disabled')
  assert.equal(getResellerProfileStatusKey('unexpected'), 'unknown')
})

test('user reseller domain status keys map backend values', () => {
  assert.equal(getResellerDomainStatusKey('pending_review'), 'pendingReview')
  assert.equal(getResellerDomainStatusKey('active'), 'active')
  assert.equal(getResellerDomainStatusKey('disabled'), 'disabled')
  assert.equal(getResellerDomainStatusKey('unexpected'), 'unknown')
})

test('user reseller management state drives onboarding and domain forms', () => {
  assert.deepEqual(getResellerManagementState(null), {
    canApply: false,
    canSubmitDomain: false,
    statusKey: 'unknown',
  })
  assert.deepEqual(getResellerManagementState({ opened: false, can_apply: true }), {
    canApply: true,
    canSubmitDomain: false,
    statusKey: 'notOpened',
  })
  assert.deepEqual(
    getResellerManagementState({
      opened: true,
      can_apply: false,
      profile: { status: 'pending_review' },
    }),
    { canApply: false, canSubmitDomain: false, statusKey: 'pendingReview' },
  )
  assert.deepEqual(
    getResellerManagementState({
      opened: true,
      can_apply: true,
      profile: { status: 'rejected' },
    }),
    { canApply: true, canSubmitDomain: false, statusKey: 'rejected' },
  )
  assert.deepEqual(
    getResellerManagementState({
      opened: true,
      can_apply: false,
      profile: { status: 'active' },
    }),
    { canApply: false, canSubmitDomain: true, statusKey: 'active' },
  )
})

test('active reseller profile check is strict', () => {
  assert.equal(isResellerProfileActive({ status: 'active' }), true)
  assert.equal(isResellerProfileActive({ status: 'pending_review' }), false)
  assert.equal(isResellerProfileActive(null), false)
})

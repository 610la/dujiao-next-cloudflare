import test from 'node:test'
import assert from 'node:assert/strict'
import {
  getResellerDomainActionState,
  getResellerProfileActionState,
  getResellerProfileStatusKey,
} from '../src/utils/resellerManagement.ts'

test('admin reseller profile status keys map backend values', () => {
  assert.equal(getResellerProfileStatusKey('pending_review'), 'pendingReview')
  assert.equal(getResellerProfileStatusKey('active'), 'active')
  assert.equal(getResellerProfileStatusKey('rejected'), 'rejected')
  assert.equal(getResellerProfileStatusKey('disabled'), 'disabled')
  assert.equal(getResellerProfileStatusKey('other'), 'unknown')
})

test('admin reseller profile actions follow review state', () => {
  assert.deepEqual(getResellerProfileActionState('pending_review'), { canApprove: true, canReject: true, canDisable: true, canRestore: false })
  assert.deepEqual(getResellerProfileActionState('active'), { canApprove: false, canReject: false, canDisable: true, canRestore: false })
  assert.deepEqual(getResellerProfileActionState('disabled'), { canApprove: false, canReject: false, canDisable: false, canRestore: true })
})

test('admin reseller domain actions follow domain state', () => {
  assert.deepEqual(getResellerDomainActionState('pending_review'), { canApprove: true, canDisable: true })
  assert.deepEqual(getResellerDomainActionState('active'), { canApprove: false, canDisable: true })
  assert.deepEqual(getResellerDomainActionState('disabled'), { canApprove: true, canDisable: false })
})

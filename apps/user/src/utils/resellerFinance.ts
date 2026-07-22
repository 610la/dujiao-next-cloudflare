import type { BadgeTone } from './status'

type ResellerWithdrawState = {
  withdraw_enabled?: boolean
}

type ResellerFinanceProfile = {
  status?: string
  settlement_status?: string
}

type ResellerFinanceStatusNamespace = 'profileStatusMap' | 'settlementStatusMap'

export type ResellerFinanceStatusView = {
  namespace: ResellerFinanceStatusNamespace
  key: string
  badgeTone: BadgeTone
}

const PROFILE_STATUS_ACTIVE = 'active'
const PROFILE_STATUS_PENDING_REVIEW = 'pending_review'

const profileStatusKeyMap: Record<string, string> = {
  pending_review: 'pendingReview',
  active: 'active',
  rejected: 'rejected',
  disabled: 'disabled',
}

const settlementStatusKeyMap: Record<string, string> = {
  normal: 'normal',
  frozen: 'frozen',
  frozen_review: 'frozen',
  disabled: 'disabled',
}

const withdrawDisabledReasonKeyMap: Record<string, string> = {
  profile_inactive: 'profileInactive',
  settlement_unavailable: 'settlementUnavailable',
}

const ledgerTypeKeyMap: Record<string, string> = {
  order_profit: 'orderProfit',
  refund_deduct: 'refundDeduct',
  withdraw_lock: 'withdrawLock',
  manual_adjust: 'manualAdjust',
  withdraw_paid: 'withdrawPaid',
}

type ResellerBalanceLike = {
  currency: string
  available_amount: string
}

/**
 * 从多币种余额中挑选用于"主要可用余额"展示的账户。
 * 系统没有"主结算币种"概念，按可用余额最大者展示，避免直接取数组第 0 个造成的误导。
 */
export const pickPrimaryResellerBalance = <T extends ResellerBalanceLike>(balances?: T[] | null): T | null => {
  const list = (balances || []).filter(Boolean)
  if (list.length === 0) return null
  return list.reduce((best, cur) =>
    (Number(cur.available_amount) || 0) > (Number(best.available_amount) || 0) ? cur : best,
  )
}

export const isResellerWithdrawEnabled = (dashboard?: ResellerWithdrawState | null) => dashboard?.withdraw_enabled === true

export const getResellerWithdrawDisabledReasonKey = (reason?: string) => {
  if (!reason) return 'default'
  return withdrawDisabledReasonKeyMap[reason] || 'default'
}

export const getResellerFinanceStatusView = (profile?: ResellerFinanceProfile | null): ResellerFinanceStatusView => {
  if (!profile) {
    return {
      namespace: 'profileStatusMap',
      key: 'unknown',
      badgeTone: 'neutral',
    }
  }

  const profileStatus = profile?.status || ''
  if (profileStatus && profileStatus !== PROFILE_STATUS_ACTIVE) {
    return {
      namespace: 'profileStatusMap',
      key: profileStatusKeyMap[profileStatus] || profileStatus,
      badgeTone: profileStatus === PROFILE_STATUS_PENDING_REVIEW ? 'warning' : 'neutral',
    }
  }

  const settlementStatus = profile?.settlement_status || ''
  return {
    namespace: 'settlementStatusMap',
    key: settlementStatusKeyMap[settlementStatus] || settlementStatus || 'unknown',
    badgeTone: settlementStatus === 'normal' ? 'success' : 'warning',
  }
}

export const getResellerLedgerTypeKey = (type?: string) => {
  if (!type) return null
  return ledgerTypeKeyMap[type] || null
}

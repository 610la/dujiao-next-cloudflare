import type { ResellerManagementSnapshotData } from '../api'
import { formatSiteDateTime } from './time.ts'

export type ResellerModuleKey =
  | 'apply'
  | 'dashboard'
  | 'domains'
  | 'site'
  | 'products'
  | 'orders'
  | 'finance'
  | 'ledger'
  | 'withdraws'

export type ResellerConsoleModuleState = {
  visible: boolean
  enabled: boolean
  reason?: string
}

export type ResellerConsoleState = {
  opened: boolean
  profileStatus: 'not_opened' | 'pending_review' | 'active' | 'rejected' | 'disabled' | 'unknown'
  canApply: boolean
  modules: Record<ResellerModuleKey, ResellerConsoleModuleState>
}

const activeModules: ResellerModuleKey[] = [
  'dashboard',
  'domains',
  'site',
  'products',
  'orders',
  'finance',
  'ledger',
  'withdraws',
]

const pathModuleMap: Record<string, ResellerModuleKey> = {
  apply: 'apply',
  domains: 'domains',
  site: 'site',
  products: 'products',
  orders: 'orders',
  finance: 'finance',
  ledger: 'ledger',
  withdraws: 'withdraws',
}

export const getResellerConsoleState = (snapshot?: ResellerManagementSnapshotData | null): ResellerConsoleState => {
  const status = snapshot?.profile?.status || (snapshot?.opened ? 'unknown' : 'not_opened')
  const profileStatus = status as ResellerConsoleState['profileStatus']
  const canApply = snapshot?.can_apply === true
  const modules = {} as Record<ResellerModuleKey, ResellerConsoleModuleState>

  modules.apply = { visible: true, enabled: canApply || profileStatus !== 'active' }
  for (const key of activeModules) {
    modules[key] = {
      visible: true,
      enabled: profileStatus === 'active',
      reason: profileStatus === 'active' ? undefined : profileStatus,
    }
  }

  return {
    opened: snapshot?.opened === true,
    profileStatus,
    canApply,
    modules,
  }
}

export const resolveResellerConsoleModule = (path: string): ResellerModuleKey => {
  const cleanPath = String(path || '').split(/[?#]/)[0]?.replace(/\/+$/, '') || '/reseller'
  if (cleanPath === '/reseller') return 'dashboard'
  const segment = cleanPath.replace(/^\/reseller\/?/, '').split('/')[0] || ''
  return pathModuleMap[segment] || 'dashboard'
}

export const canRenderResellerConsoleModule = (
  path: string,
  state: ResellerConsoleState,
) => {
  const module = resolveResellerConsoleModule(path)
  if (module === 'apply' || module === 'dashboard') return true
  return state.modules[module]?.enabled === true
}

export const formatResellerConsoleDate = (raw?: string | null) => {
  return formatSiteDateTime(raw) || '-'
}

export const formatResellerConsoleAmount = (amount?: string | number | null, currency?: string | null) => {
  if (amount === undefined || amount === null || amount === '') return '-'
  const num = typeof amount === 'number' ? amount : Number(amount)
  let value: string
  if (Number.isFinite(num)) {
    const decimals = (String(amount).split('.')[1] || '').length
    value = num.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: Math.max(2, Math.min(decimals, 8)),
    })
  } else {
    value = String(amount)
  }
  return currency ? `${value} ${currency}` : value
}

export const resellerAmountSign = (amount?: string | number | null): 'positive' | 'negative' | 'zero' => {
  const num = typeof amount === 'number' ? amount : Number(amount)
  if (!Number.isFinite(num) || num === 0) return 'zero'
  return num > 0 ? 'positive' : 'negative'
}

export const resellerProfitStatusKey = (status?: string) => {
  if (status === 'credited') return 'credited'
  if (status === 'pending') return 'pending'
  if (status === 'unavailable') return 'unavailable'
  return 'unknown'
}

export const resellerOrderStatusTone = (status?: string) => {
  if (status === 'paid' || status === 'completed' || status === 'delivered') return 'success'
  if (status === 'pending_payment') return 'warning'
  if (status === 'refunded' || status === 'partially_refunded' || status === 'canceled') return 'neutral'
  return 'info'
}

// 纯 CSS/SVG 可视化共用调色板（明暗主题均可读）
export const RESELLER_CHART_PALETTE = [
  '#6366f1',
  '#10b981',
  '#f59e0b',
  '#0ea5e9',
  '#ec4899',
  '#8b5cf6',
  '#14b8a6',
  '#ef4444',
]

export const resellerOrderStatusColor = (status?: string): string => {
  switch (status) {
    case 'paid':
      return '#10b981'
    case 'completed':
      return '#0ea5e9'
    case 'delivered':
      return '#14b8a6'
    case 'pending_payment':
      return '#f59e0b'
    case 'partially_refunded':
      return '#f97316'
    case 'refunded':
      return '#ef4444'
    case 'canceled':
      return '#94a3b8'
    default:
      return '#6366f1'
  }
}

export const resellerCurrencyColor = (index: number): string =>
  RESELLER_CHART_PALETTE[index % RESELLER_CHART_PALETTE.length] ?? '#6366f1'

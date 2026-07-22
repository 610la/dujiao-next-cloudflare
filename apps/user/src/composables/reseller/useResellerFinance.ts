import { reactive, ref } from 'vue'
import {
  resellerAPI,
  type ResellerBalanceData,
  type ResellerDashboardData,
  type ResellerLedgerData,
  type ResellerWithdrawApplyPayload,
  type ResellerWithdrawData,
} from '../../api'

export type ResellerFinanceListParams = {
  page?: number
  page_size?: number
  type?: string
  status?: string
  order_id?: number
}

export const useResellerFinance = () => {
  const dashboardLoading = ref(false)
  const balanceLoading = ref(false)
  const ledgerLoading = ref(false)
  const withdrawsLoading = ref(false)
  const submittingWithdraw = ref(false)
  const dashboard = ref<ResellerDashboardData | null>(null)
  const balances = ref<ResellerBalanceData[]>([])
  const ledgerEntries = ref<ResellerLedgerData[]>([])
  const withdraws = ref<ResellerWithdrawData[]>([])
  const ledgerPagination = reactive({ page: 1, page_size: 20, total: 0, total_page: 1 })
  const withdrawsPagination = reactive({ page: 1, page_size: 20, total: 0, total_page: 1 })

  // 各 load* 统一在内部兜底吞异常：避免在 onMounted / Promise.all 聚合处冒泡成未处理 rejection，
  // 并防止单个区段请求失败拖垮整页加载；失败时对应区段降级为空，不影响其它区段。
  const loadDashboard = async () => {
    dashboardLoading.value = true
    try {
      const response = await resellerAPI.dashboard()
      dashboard.value = response.data.data || null
    } catch {
      dashboard.value = null
    } finally {
      dashboardLoading.value = false
    }
  }

  const loadBalances = async (params: ResellerFinanceListParams = {}) => {
    balanceLoading.value = true
    try {
      const response = await resellerAPI.balanceAccounts(params)
      balances.value = response.data.data || []
    } catch {
      balances.value = []
    } finally {
      balanceLoading.value = false
    }
  }

  const loadLedgerEntries = async (params: ResellerFinanceListParams = {}) => {
    ledgerLoading.value = true
    try {
      const response = await resellerAPI.ledgerEntries({
        page: ledgerPagination.page,
        page_size: ledgerPagination.page_size,
        ...params,
      })
      ledgerEntries.value = response.data.data || []
      Object.assign(ledgerPagination, response.data.pagination || ledgerPagination)
    } catch {
      ledgerEntries.value = []
    } finally {
      ledgerLoading.value = false
    }
  }

  const loadWithdraws = async (params: ResellerFinanceListParams = {}) => {
    withdrawsLoading.value = true
    try {
      const response = await resellerAPI.withdraws({
        page: withdrawsPagination.page,
        page_size: withdrawsPagination.page_size,
        ...params,
      })
      withdraws.value = response.data.data || []
      Object.assign(withdrawsPagination, response.data.pagination || withdrawsPagination)
    } catch {
      withdraws.value = []
    } finally {
      withdrawsLoading.value = false
    }
  }

  const applyWithdraw = async (payload: ResellerWithdrawApplyPayload) => {
    submittingWithdraw.value = true
    try {
      await resellerAPI.applyWithdraw(payload)
      // 提现申请已成功提交；后续刷新仅为同步展示，属尽力而为。
      // 必须用 allSettled：若用 Promise.all，任一刷新请求的瞬时失败都会 reject 上抛，
      // 被调用方误判为「提现失败」，诱导用户重复提交造成重复提现申请。
      await Promise.allSettled([loadDashboard(), loadBalances(), loadWithdraws({ page: 1 })])
    } finally {
      submittingWithdraw.value = false
    }
  }

  return {
    dashboardLoading,
    balanceLoading,
    ledgerLoading,
    withdrawsLoading,
    submittingWithdraw,
    dashboard,
    balances,
    ledgerEntries,
    withdraws,
    ledgerPagination,
    withdrawsPagination,
    loadDashboard,
    loadBalances,
    loadLedgerEntries,
    loadWithdraws,
    applyWithdraw,
  }
}

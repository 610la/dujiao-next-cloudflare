import { reactive, ref } from 'vue'
import {
  resellerAPI,
  type ResellerOrderData,
  type ResellerOrderDetailData,
  type ResellerOrderListParams,
  type ResellerOrderStatsData,
} from '../../api'

export const useResellerOrders = () => {
  const loading = ref(false)
  const detailLoading = ref(false)
  const error = ref('')
  const detailError = ref('')
  const rows = ref<ResellerOrderData[]>([])
  const detail = ref<ResellerOrderDetailData | null>(null)
  const stats = ref<ResellerOrderStatsData | null>(null)
  const pagination = reactive({ page: 1, page_size: 20, total: 0, total_page: 1 })

  // 统一兜底：失败时记录后端本地化消息，避免请求失败被误显示为「暂无数据」，
  // 同时吞掉异常，避免 Promise.all 的连带 reject 变成未处理 rejection。
  const load = async (params: ResellerOrderListParams = {}) => {
    loading.value = true
    error.value = ''
    try {
      const response = await resellerAPI.orders({ page: pagination.page, page_size: pagination.page_size, ...params })
      rows.value = response.data.data || []
      Object.assign(pagination, response.data.pagination || pagination)
    } catch (err) {
      error.value = err instanceof Error && err.message ? err.message : 'error'
    } finally {
      loading.value = false
    }
  }

  // 统计为次要信息，失败时静默归零不阻塞订单列表。
  const loadStats = async (params: ResellerOrderListParams = {}) => {
    try {
      const response = await resellerAPI.orderStats(params)
      stats.value = response.data.data || null
    } catch {
      stats.value = null
    }
  }

  const loadDetail = async (orderNo: string) => {
    detailLoading.value = true
    detailError.value = ''
    try {
      const response = await resellerAPI.orderDetail(orderNo)
      detail.value = response.data.data || null
    } catch (err) {
      detailError.value = err instanceof Error && err.message ? err.message : 'error'
    } finally {
      detailLoading.value = false
    }
  }

  return { loading, detailLoading, error, detailError, rows, detail, stats, pagination, load, loadStats, loadDetail }
}

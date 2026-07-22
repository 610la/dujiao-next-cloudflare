<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useDebounceFn } from '@vueuse/core'
import { adminAPI } from '@/api/admin'
import type { AdminProcurementOrder, AdminSiteConnection } from '@/api/types'
import { getLocalizedText, formatDate, formatMoney, hasPositiveAmount, parseSiteDate, toRFC3339 } from '@/utils/format'
import { orderStatusLabel } from '@/utils/status'
import TableSkeleton from '@/components/TableSkeleton.vue'
import ListPagination from '@/components/ListPagination.vue'
import { useListRefresh, type ListFetchOptions } from '@/composables/useListRefresh'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { confirmAction } from '@/utils/confirm'
import { notifyError, notifySuccess } from '@/utils/notify'

interface LocalOrderItem {
  title: Record<string, string>
  sku_snapshot?: { sku_code?: string }
  quantity: number | string
  cost_price?: number | string
  total_amount: number | string
}

interface LocalOrder {
  status: string
  user_email?: string
  refunded_amount?: number | string
  items?: LocalOrderItem[]
}

interface UpstreamRefundRecordRow {
  id: string
  type: string
  amount: string
  currency: string
  remark: string
  createdAt: string
}

type ProcurementOrderWithRelations = AdminProcurementOrder & {
  connection?: { name?: string; id?: number; exchange_rate?: number }
  local_order?: LocalOrder
  currency?: string
  upstream_currency?: string
}

const { t } = useI18n()
const loading = ref(true)
const { refreshing, refreshList } = useListRefresh()
const orders = ref<ProcurementOrderWithRelations[]>([])
const connections = ref<AdminSiteConnection[]>([])
const pagination = reactive({
  page: 1,
  page_size: 20,
  total: 0,
  total_page: 1,
})
const filters = reactive({
  status: '__all__',
  connection_id: '__all__',
  order_no: '',
  upstream_order_no: '',
  created_from: '',
  created_to: '',
})

const showDetail = ref(false)
const detailOrder = ref<ProcurementOrderWithRelations | null>(null)
const detailLoading = ref(false)
const retryingId = ref<number | null>(null)
const cancelingId = ref<number | null>(null)
const procurementDownloading = ref(false)

const handleDownloadUpstreamPayload = async (orderId: number) => {
  if (procurementDownloading.value) return
  procurementDownloading.value = true
  try {
    const res = await adminAPI.downloadProcurementUpstreamPayload(orderId)
    const blob = new Blob([res.data], { type: 'text/plain; charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `upstream-payload-${orderId}.txt`
    a.click()
    URL.revokeObjectURL(url)
  } catch {} finally {
    procurementDownloading.value = false
  }
}

const statusOptions = [
  { value: '__all__', key: 'procurement.filters.allStatus' },
  { value: 'pending', key: 'procurement.status.pending' },
  { value: 'accepted', key: 'procurement.status.accepted' },
  { value: 'rejected', key: 'procurement.status.rejected' },
  { value: 'failed', key: 'procurement.status.failed' },
  { value: 'partially_refunded', key: 'procurement.status.partially_refunded' },
  { value: 'fulfilled', key: 'procurement.status.fulfilled' },
  { value: 'refunded', key: 'procurement.status.refunded' },
  { value: 'canceled', key: 'procurement.status.canceled' },
]

// Stats（来自后端聚合接口，基于全量数据，与 status 筛选解耦）
const stats = reactive({
  total: 0,
  pending: 0,
  failed: 0,
  rejected: 0,
  fulfilled: 0,
  other: 0, // 其他状态合计（accepted/submitted/canceled/refunded 等中间态），保证四细分卡 + other = total
})

const buildStatsParams = () => {
  const params: Record<string, unknown> = {}
  if (filters.connection_id && filters.connection_id !== '__all__') params.connection_id = filters.connection_id
  if (filters.order_no) params.order_no = filters.order_no
  if (filters.upstream_order_no) params.upstream_order_no = filters.upstream_order_no
  const createdFrom = toRFC3339(filters.created_from)
  if (createdFrom) params.created_from = createdFrom
  const createdTo = toRFC3339(filters.created_to)
  if (createdTo) params.created_to = createdTo
  return params
}

const fetchStats = async () => {
  try {
    const res = await adminAPI.getProcurementOrderStats(buildStatsParams())
    const data = res.data?.data ?? {}
    const byStatus = (data.by_status ?? {}) as Record<string, number>
    const total = Number(data.total ?? 0)
    const pending = Number(byStatus.pending ?? 0)
    const failed = Number(byStatus.failed ?? 0)
    const rejected = Number(byStatus.rejected ?? 0)
    const fulfilled = Number(byStatus.fulfilled ?? 0)
    stats.total = total
    stats.pending = pending
    stats.failed = failed
    stats.rejected = rejected
    stats.fulfilled = fulfilled
    stats.other = Math.max(0, total - pending - failed - rejected - fulfilled)
  } catch {
    // 失败时保留旧值，避免与 list 已有数据冲突；list 失败会自带提示
  }
}

const fetchConnections = async () => {
  try {
    const res = await adminAPI.getSiteConnections({ page: 1, page_size: 100 })
    connections.value = res.data.data || []
  } catch { /* ignore */ }
}

const fetchOrders = async (page = 1, options: ListFetchOptions = {}) => {
  if (!options.preserveRows) loading.value = true
  try {
    const params: Record<string, unknown> = {
      page,
      page_size: pagination.page_size,
    }
    if (filters.status && filters.status !== '__all__') params.status = filters.status
    if (filters.connection_id && filters.connection_id !== '__all__') params.connection_id = filters.connection_id
    if (filters.order_no) params.order_no = filters.order_no
    if (filters.upstream_order_no) params.upstream_order_no = filters.upstream_order_no
    const createdFrom = toRFC3339(filters.created_from)
    if (createdFrom) params.created_from = createdFrom
    const createdTo = toRFC3339(filters.created_to)
    if (createdTo) params.created_to = createdTo

    const res = await adminAPI.getProcurementOrders(params)
    orders.value = (res.data.data as ProcurementOrderWithRelations[]) || []
    const p = res.data.pagination
    if (p) {
      pagination.page = p.page
      pagination.page_size = p.page_size
      pagination.total = p.total
      pagination.total_page = p.total_page
    }
  } catch {
    if (!options.preserveRows) orders.value = []
  } finally {
    if (!options.preserveRows) loading.value = false
  }
}

const changePage = (page: number) => {
  if (page < 1 || page > pagination.total_page) return
  fetchOrders(page)
}

const pageSizeOptions = [10, 20, 50, 100]

const changePageSize = (size: number) => {
  if (size === pagination.page_size) return
  pagination.page_size = size
  fetchOrders(1)
}

const handleSearch = () => {
  fetchOrders(1, { preserveRows: true })
  fetchStats()
}
const debouncedSearch = useDebounceFn(handleSearch, 300)

const selectStatusFilter = (status: string) => {
  if (filters.status === status) {
    filters.status = '__all__'
  } else {
    filters.status = status
  }
  fetchOrders(1, { preserveRows: true })
}

const refresh = () => {
  refreshList(() => fetchOrders(pagination.page, { preserveRows: true }))
}

const openDetail = async (order: ProcurementOrderWithRelations) => {
  detailLoading.value = true
  showDetail.value = true
  detailOrder.value = order
  try {
    const res = await adminAPI.getProcurementOrder(order.id)
    detailOrder.value = (res.data.data as ProcurementOrderWithRelations) || order
  } catch { /* keep original */ }
  detailLoading.value = false
}

const closeDetail = () => {
  showDetail.value = false
  detailOrder.value = null
}

const handleRetry = async (order: ProcurementOrderWithRelations) => {
  const confirmed = await confirmAction({
    description: t('procurement.actions.retryConfirm', { id: order.id }),
    confirmText: t('procurement.actions.retry'),
  })
  if (!confirmed) return
  retryingId.value = order.id
  try {
    await adminAPI.retryProcurementOrder(order.id)
    notifySuccess(t('procurement.actions.retrySuccess'))
    fetchOrders(pagination.page)
    if (showDetail.value && detailOrder.value?.id === order.id) {
      openDetail(order)
    }
  } catch (err: any) {
    notifyError(err?.response?.data?.message || err?.message)
  } finally {
    retryingId.value = null
  }
}

const handleCancel = async (order: ProcurementOrderWithRelations) => {
  const confirmed = await confirmAction({
    description: t('procurement.actions.cancelConfirm', { id: order.id }),
    confirmText: t('procurement.actions.cancelOrder'),
    variant: 'destructive',
  })
  if (!confirmed) return
  cancelingId.value = order.id
  try {
    await adminAPI.cancelProcurementOrder(order.id)
    notifySuccess(t('procurement.actions.cancelSuccess'))
    fetchOrders(pagination.page)
    if (showDetail.value && detailOrder.value?.id === order.id) {
      openDetail(order)
    }
  } catch (err: any) {
    notifyError(err?.response?.data?.message || err?.message)
  } finally {
    cancelingId.value = null
  }
}

const statusBadgeClass = (status: string) => {
  switch (status) {
    case 'pending': return 'text-amber-700 border-amber-200 bg-amber-50'
    case 'submitted': return 'text-blue-700 border-blue-200 bg-blue-50'
    case 'accepted': return 'text-sky-700 border-sky-200 bg-sky-50'
    case 'rejected': return 'text-red-700 border-red-200 bg-red-50'
    case 'failed': return 'text-red-700 border-red-200 bg-red-50'
    case 'partially_refunded': return 'text-orange-700 border-orange-200 bg-orange-50'
    case 'fulfilled': return 'text-emerald-700 border-emerald-200 bg-emerald-50'
    case 'completed': return 'text-emerald-700 border-emerald-200 bg-emerald-50'
    case 'refunded': return 'text-blue-700 border-blue-200 bg-blue-50'
    case 'canceled': return 'text-muted-foreground border-border bg-muted/30'
    default: return 'text-muted-foreground border-border bg-muted/30'
  }
}

const statusIcon = (status: string) => {
  switch (status) {
    case 'pending': return 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z' // clock
    case 'accepted': return 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z' // check circle
    case 'rejected': case 'failed': return 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z' // exclamation
    case 'fulfilled': case 'completed': return 'M5 13l4 4L19 7' // check
    case 'partially_refunded': case 'refunded': return 'M3 10h12M3 14h9m7-9v14l-3-2-3 2V5a1 1 0 011-1h4a1 1 0 011 1z' // refund
    case 'canceled': return 'M6 18L18 6M6 6l12 12' // x
    default: return 'M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01'
  }
}

const formatTime = (raw?: string) => {
  return formatDate(raw) || '-'
}

const relativeTime = (raw?: string) => {
  if (!raw) return ''
  const d = parseSiteDate(raw)
  if (!d) return ''
  const diff = Date.now() - d.getTime()
  const minutes = Math.floor(diff / 60000)
  if (minutes < 1) return t('procurement.time.justNow')
  if (minutes < 60) return t('procurement.time.minutesAgo', { n: minutes })
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return t('procurement.time.hoursAgo', { n: hours })
  const days = Math.floor(hours / 24)
  return t('procurement.time.daysAgo', { n: days })
}

const getOrderTitle = (order: ProcurementOrderWithRelations) => {
  const localOrder = order.local_order
  if (!localOrder) return order.local_order_no || '-'
  const items = localOrder.items || []
  if (items.length > 0 && items[0]?.title) {
    return getLocalizedText(items[0]!.title)
  }
  return order.local_order_no || '-'
}

const getExchangeRate = (order: ProcurementOrderWithRelations) => {
  const rate = order.connection?.exchange_rate
  return rate && rate > 0 ? rate : 1
}

const parseMoneyValue = (value: unknown) => {
  if (value === null || value === undefined) return 0
  const num = Number(value)
  return Number.isFinite(num) ? num : 0
}

const upstreamRefundInLocal = (order: ProcurementOrderWithRelations) => parseMoneyValue(order.upstream_refunded_amount) * getExchangeRate(order)
const localRefundAmount = (order: ProcurementOrderWithRelations) => parseMoneyValue(order.local_order?.refunded_amount)

const localCostValue = (order: ProcurementOrderWithRelations) => {
  const items = order.local_order?.items || []
  return items.reduce((sum, item) => {
    const qty = parseMoneyValue(item.quantity)
    const costPrice = parseMoneyValue(item.cost_price)
    return sum + (costPrice * qty)
  }, 0)
}

const profitAmount = (order: ProcurementOrderWithRelations) => {
  const sell = parseMoneyValue(order.local_sell_amount)
  const upstreamRefund = upstreamRefundInLocal(order)
  const localCost = localCostValue(order)
  const localRefund = localRefundAmount(order)
  const hasFinancialData = [sell, upstreamRefund, localCost, localRefund].some((v) => Math.abs(v) > 0.000001)
  if (!hasFinancialData) return null
  return (sell + upstreamRefund - localCost - localRefund).toFixed(2)
}

const localCostAmount = (order: ProcurementOrderWithRelations) => {
  const cost = localCostValue(order)
  if (Math.abs(cost) <= 0.000001) return null
  return cost.toFixed(2)
}

const normalizeText = (value: unknown) => (value === null || value === undefined ? '' : String(value).trim())

const normalizeUpstreamRefundRecords = (order: ProcurementOrderWithRelations | null): UpstreamRefundRecordRow[] => {
  if (!order || !Array.isArray(order.upstream_refund_records)) return []
  return order.upstream_refund_records.map((raw, index) => {
    const record = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>
    return {
      id: String(index + 1),
      type: normalizeText(record.type),
      amount: normalizeText(record.amount),
      currency: normalizeText(record.currency),
      remark: normalizeText(record.remark),
      createdAt: normalizeText(record.created_at),
    }
  })
}

const detailUpstreamRefundRecords = computed(() => normalizeUpstreamRefundRecords(detailOrder.value))

const hasUpstreamRefundAmount = computed(() => hasPositiveAmount(detailOrder.value?.upstream_refunded_amount as string | number | undefined))
const hasLocalRefundAmount = computed(() => hasPositiveAmount(detailOrder.value?.local_order?.refunded_amount))

const getUpstreamRefundTypeLabel = (type: string) => {
  const normalized = type.trim().toLowerCase()
  if (normalized === 'manual') return t('admin.orderRefunds.typeManual')
  if (normalized === 'wallet') return t('admin.orderRefunds.typeWallet')
  return normalized || '-'
}
const getLocalOrderStatusLabel = (status?: string) => orderStatusLabel(t, status)

const profitClass = (order: ProcurementOrderWithRelations) => {
  const p = profitAmount(order)
  if (p === null) return ''
  return parseFloat(p) >= 0 ? 'text-emerald-600' : 'text-red-600'
}

const canRetry = (status: string) => ['failed', 'rejected'].includes(status)
const canCancel = (status: string) => ['pending', 'submitted', 'accepted', 'failed'].includes(status)

onMounted(() => {
  fetchConnections()
  fetchOrders()
  fetchStats()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold">{{ t('procurement.title') }}</h1>
        <p class="mt-1 text-sm text-muted-foreground">{{ t('procurement.subtitle') }}</p>
      </div>
      <Button size="sm" variant="outline" class="w-full sm:w-auto" :disabled="refreshing" @click="refresh">
        {{ t('admin.common.refresh') }}
      </Button>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
      <button
        type="button"
        class="rounded-xl border bg-card p-4 text-left transition-all hover:shadow-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        :class="filters.status === '__all__' ? 'border-foreground/40 ring-1 ring-foreground/30' : 'border-border'"
        :title="t('procurement.stats.totalHint')"
        @click="selectStatusFilter('__all__')"
      >
        <div class="text-xs font-medium text-muted-foreground">{{ t('procurement.stats.total') }}</div>
        <div class="mt-1 text-2xl font-bold">{{ stats.total }}</div>
      </button>
      <button
        type="button"
        class="rounded-xl border bg-amber-50/50 p-4 text-left transition-all hover:shadow-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-amber-300"
        :class="filters.status === 'pending' ? 'border-amber-400 ring-1 ring-amber-300' : 'border-amber-200'"
        @click="selectStatusFilter('pending')"
      >
        <div class="text-xs font-medium text-amber-700">{{ t('procurement.stats.pending') }}</div>
        <div class="mt-1 text-2xl font-bold text-amber-700">{{ stats.pending }}</div>
      </button>
      <button
        type="button"
        class="rounded-xl border bg-red-50/50 p-4 text-left transition-all hover:shadow-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-red-300"
        :class="filters.status === 'failed' ? 'border-red-400 ring-1 ring-red-300' : 'border-red-200'"
        @click="selectStatusFilter('failed')"
      >
        <div class="text-xs font-medium text-red-700">{{ t('procurement.stats.failed') }}</div>
        <div class="mt-1 text-2xl font-bold text-red-700">{{ stats.failed }}</div>
      </button>
      <button
        type="button"
        class="rounded-xl border bg-rose-50/50 p-4 text-left transition-all hover:shadow-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-rose-300"
        :class="filters.status === 'rejected' ? 'border-rose-400 ring-1 ring-rose-300' : 'border-rose-200'"
        @click="selectStatusFilter('rejected')"
      >
        <div class="text-xs font-medium text-rose-700">{{ t('procurement.stats.rejected') }}</div>
        <div class="mt-1 text-2xl font-bold text-rose-700">{{ stats.rejected }}</div>
      </button>
      <button
        type="button"
        class="rounded-xl border bg-emerald-50/50 p-4 text-left transition-all hover:shadow-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-300"
        :class="filters.status === 'fulfilled' ? 'border-emerald-400 ring-1 ring-emerald-300' : 'border-emerald-200'"
        @click="selectStatusFilter('fulfilled')"
      >
        <div class="text-xs font-medium text-emerald-700">{{ t('procurement.stats.fulfilled') }}</div>
        <div class="mt-1 text-2xl font-bold text-emerald-700">{{ stats.fulfilled }}</div>
      </button>
      <div
        class="cursor-default rounded-xl border border-border bg-muted/30 p-4"
        :title="t('procurement.stats.otherHint')"
      >
        <div class="text-xs font-medium text-muted-foreground">{{ t('procurement.stats.other') }}</div>
        <div class="mt-1 text-2xl font-bold text-muted-foreground">{{ stats.other }}</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('procurement.columns.status') }}</label>
        <Select v-model="filters.status" @update:model-value="handleSearch">
          <SelectTrigger class="h-9 w-full sm:w-36">
            <SelectValue :placeholder="t('procurement.filters.allStatus')" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="opt in statusOptions" :key="opt.value" :value="opt.value">
              {{ t(opt.key) }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('procurement.columns.connection') }}</label>
        <Select v-model="filters.connection_id" @update:model-value="handleSearch">
          <SelectTrigger class="h-9 w-full sm:w-44">
            <SelectValue :placeholder="t('procurement.filters.allConnections')" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="__all__">{{ t('procurement.filters.allConnections') }}</SelectItem>
            <SelectItem v-for="conn in connections" :key="conn.id" :value="String(conn.id)">
              {{ conn.name || `#${conn.id}` }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('procurement.filters.orderNo') }}</label>
        <Input v-model="filters.order_no" class="h-9 w-full sm:w-44" :placeholder="t('procurement.filters.orderNoPlaceholder')" @update:modelValue="debouncedSearch" @keyup.enter="handleSearch" />
      </div>
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('procurement.filters.upstreamOrderNo') }}</label>
        <Input v-model="filters.upstream_order_no" class="h-9 w-full sm:w-44" :placeholder="t('procurement.filters.upstreamOrderNoPlaceholder')" @update:modelValue="debouncedSearch" @keyup.enter="handleSearch" />
      </div>
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('procurement.filters.dateRange') }}</label>
        <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center">
          <Input v-model="filters.created_from" type="datetime-local" class="h-9 w-full sm:w-44" @change="handleSearch" />
          <span class="hidden text-xs text-muted-foreground sm:inline">—</span>
          <Input v-model="filters.created_to" type="datetime-local" class="h-9 w-full sm:w-44" @change="handleSearch" />
        </div>
      </div>
      <Button size="sm" class="h-9 w-full sm:w-auto" @click="handleSearch">{{ t('procurement.filters.search') }}</Button>
    </div>

    <!-- Order Cards -->
    <div class="space-y-3">
      <div v-if="loading" class="rounded-xl border border-border bg-card overflow-hidden">
        <TableSkeleton :columns="6" :rows="5" />
      </div>
      <div v-else-if="orders.length === 0" class="rounded-xl border border-border bg-card p-12 text-center text-muted-foreground">
        {{ t('procurement.empty') }}
      </div>

      <div
        v-for="order in orders"
        :key="order.id"
        class="group cursor-pointer rounded-xl border border-border bg-card transition-all hover:shadow-md"
        :class="{ 'border-red-200 bg-red-50/30': order.status === 'failed' || order.status === 'rejected' }"
        @click="openDetail(order)"
      >
        <div class="p-4">
          <!-- Top row: status + ID + time -->
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="flex min-w-0 items-start gap-3">
              <div
                class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border"
                :class="statusBadgeClass(order.status)"
              >
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path :d="statusIcon(order.status)" />
                </svg>
              </div>
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="break-words text-sm font-semibold text-foreground">{{ getOrderTitle(order) }}</span>
                  <span
                    class="inline-flex rounded-full border px-2 py-0.5 text-[11px] font-medium"
                    :class="statusBadgeClass(order.status)"
                  >
                    {{ t('procurement.status.' + order.status) }}
                  </span>
                </div>
                <div class="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
                  <span class="font-mono">#{{ order.id }}</span>
                  <span class="break-words">{{ order.connection?.name || '-' }}</span>
                  <span>{{ relativeTime(order.created_at) }}</span>
                </div>
              </div>
            </div>
            <div class="flex w-full flex-wrap items-center gap-2 sm:w-auto sm:justify-end" @click.stop>
              <Button
                v-if="canRetry(order.status)"
                size="sm"
                variant="outline"
                class="h-7 text-xs"
                :disabled="retryingId === order.id"
                @click="handleRetry(order)"
              >
                {{ t('procurement.actions.retry') }}
              </Button>
              <Button
                v-if="canCancel(order.status)"
                size="sm"
                variant="ghost"
                class="h-7 text-xs text-muted-foreground hover:text-red-600"
                :disabled="cancelingId === order.id"
                @click="handleCancel(order)"
              >
                {{ t('procurement.actions.cancel') }}
              </Button>
            </div>
          </div>

          <!-- Info row -->
          <div class="mt-3 grid grid-cols-2 gap-x-6 gap-y-1.5 text-xs md:grid-cols-4 lg:grid-cols-6">
            <div>
              <span class="text-muted-foreground">{{ t('procurement.columns.localOrderNo') }}</span>
              <div class="mt-0.5 break-all font-mono text-foreground">{{ order.local_order_no || '-' }}</div>
              <div v-if="order.parent_order_no" class="mt-0.5 text-[10px] text-muted-foreground">
                {{ t('procurement.columns.parentOrderNo') }}: <span class="font-mono">{{ order.parent_order_no }}</span>
              </div>
            </div>
            <div>
              <span class="text-muted-foreground">{{ t('procurement.columns.upstreamOrderNo') }}</span>
              <div class="mt-0.5 break-all font-mono text-foreground">{{ order.upstream_order_no || '-' }}</div>
            </div>
            <div>
              <span class="text-muted-foreground">{{ t('procurement.columns.localSellAmount') }}</span>
              <div class="mt-0.5 font-medium text-foreground">{{ formatMoney(order.local_sell_amount, order.currency) }}</div>
            </div>
            <div>
              <span class="text-muted-foreground">{{ t('procurement.columns.upstreamAmount') }}</span>
              <div class="mt-0.5 font-medium text-foreground">{{ order.upstream_amount && String(order.upstream_amount) !== '0.00' ? formatMoney(order.upstream_amount, order.upstream_currency || order.currency) : '-' }}</div>
            </div>
            <div v-if="localCostAmount(order) !== null">
              <span class="text-muted-foreground">{{ t('procurement.columns.localCost') }}</span>
              <div class="mt-0.5 font-medium text-foreground">{{ formatMoney(localCostAmount(order)!, order.currency) }}</div>
            </div>
            <div>
              <span class="text-muted-foreground">{{ t('procurement.detail.profit') }}</span>
              <div class="mt-0.5 font-medium" :class="profitClass(order)">
                {{ profitAmount(order) !== null ? formatMoney(profitAmount(order)!, order.currency) : '-' }}
              </div>
            </div>
            <div>
              <span class="text-muted-foreground">{{ t('procurement.columns.retryCount') }}</span>
              <div class="mt-0.5 text-foreground">{{ order.retry_count ?? 0 }}</div>
            </div>
          </div>

          <!-- Error message -->
          <div
            v-if="order.error_message"
            class="mt-3 flex items-start gap-2 rounded-lg border border-red-200 bg-red-50 px-3 py-2"
          >
            <svg class="mt-0.5 h-3.5 w-3.5 shrink-0 text-red-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <span class="break-words text-xs text-red-700">{{ order.error_message }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Pagination -->
    <ListPagination
      :page="pagination.page"
      :total-page="pagination.total_page"
      :total="pagination.total"
      :page-size="pagination.page_size"
      :page-size-options="pageSizeOptions"
      @change-page="changePage"
      @change-page-size="changePageSize"
    />

    <!-- Detail Dialog -->
    <Dialog v-model:open="showDetail" @update:open="(value: boolean) => { if (!value) closeDetail() }">
      <DialogScrollContent
        class="w-[calc(100vw-1rem)] max-w-3xl p-4 sm:p-6"
        @interact-outside="(e: Event) => e.preventDefault()"
        @open-auto-focus="(e: Event) => e.preventDefault()"
      >
        <DialogHeader>
          <DialogTitle class="flex flex-wrap items-center gap-2">
            {{ t('procurement.detail.title') }}
            <span v-if="detailOrder" class="font-mono text-sm text-muted-foreground">#{{ detailOrder.id }}</span>
          </DialogTitle>
        </DialogHeader>

        <div v-if="detailOrder" class="space-y-5">
          <!-- Status banner -->
          <div
            class="flex items-center gap-3 rounded-lg border px-4 py-3"
            :class="statusBadgeClass(detailOrder.status)"
          >
            <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path :d="statusIcon(detailOrder.status)" />
            </svg>
            <div>
              <div class="text-sm font-semibold">{{ t('procurement.status.' + detailOrder.status) }}</div>
              <div v-if="detailOrder.error_message" class="mt-0.5 text-xs opacity-80">{{ detailOrder.error_message }}</div>
            </div>
          </div>

          <!-- Order info -->
          <div class="rounded-lg border border-border">
            <div class="border-b border-border bg-muted/30 px-4 py-2 text-xs font-semibold text-muted-foreground uppercase">
              {{ t('procurement.detail.orderInfo') }}
            </div>
            <div class="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2 md:grid-cols-3">
              <div>
                <div class="text-xs text-muted-foreground">{{ t('procurement.columns.localOrderNo') }}</div>
                <div class="mt-1 break-all text-sm font-mono font-medium">{{ detailOrder.local_order_no || '-' }}</div>
                <div v-if="detailOrder.parent_order_no" class="mt-1 text-xs text-muted-foreground">
                  {{ t('procurement.columns.parentOrderNo') }}: <span class="font-mono">{{ detailOrder.parent_order_no }}</span>
                </div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">{{ t('procurement.columns.upstreamOrderNo') }}</div>
                <div class="mt-1 break-all text-sm font-mono font-medium">{{ detailOrder.upstream_order_no || '-' }}</div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">{{ t('procurement.columns.connection') }}</div>
                <div class="mt-1 text-sm font-medium">{{ detailOrder.connection?.name || detailOrder.connection_id || '-' }}</div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">{{ t('procurement.detail.traceId') }}</div>
                <div class="mt-1 text-sm font-mono text-muted-foreground break-all">{{ detailOrder.trace_id || '-' }}</div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">{{ t('procurement.detail.currency') }}</div>
                <div class="mt-1 text-sm">{{ detailOrder.currency || '-' }}</div>
              </div>
            </div>
          </div>

          <!-- Financial -->
          <div class="rounded-lg border border-border">
            <div class="border-b border-border bg-muted/30 px-4 py-2 text-xs font-semibold text-muted-foreground uppercase">
              {{ t('procurement.detail.financial') }}
            </div>
            <div class="grid grid-cols-1 gap-3 p-4 sm:grid-cols-2 xl:grid-cols-3">
              <div class="rounded-md border border-border bg-muted/20 p-4 text-center">
                <div class="text-xs text-muted-foreground">{{ t('procurement.columns.localSellAmount') }}</div>
                <div class="mt-1 text-lg font-bold">{{ formatMoney(detailOrder.local_sell_amount, detailOrder.currency) }}</div>
              </div>
              <div class="rounded-md border border-border bg-muted/20 p-4 text-center">
                <div class="text-xs text-muted-foreground">{{ t('procurement.columns.upstreamAmount') }}</div>
                <div class="mt-1 text-lg font-bold">
                  {{ detailOrder.upstream_amount && String(detailOrder.upstream_amount) !== '0.00' ? formatMoney(detailOrder.upstream_amount, detailOrder.upstream_currency || detailOrder.currency) : '-' }}
                </div>
              </div>
              <div v-if="localCostAmount(detailOrder) !== null" class="rounded-md border border-border bg-muted/20 p-4 text-center">
                <div class="text-xs text-muted-foreground">{{ t('procurement.columns.localCost') }}</div>
                <div class="mt-1 text-lg font-bold">
                  {{ localCostAmount(detailOrder) !== null ? formatMoney(localCostAmount(detailOrder)!, detailOrder.currency) : '-' }}
                </div>
              </div>
              <div v-if="hasUpstreamRefundAmount" class="rounded-md border border-border bg-muted/20 p-4 text-center">
                <div class="text-xs text-muted-foreground">{{ t('procurement.detail.upstreamRefunded') }}</div>
                <div class="mt-1 text-lg font-bold text-rose-600">
                  {{ formatMoney(detailOrder.upstream_refunded_amount, detailOrder.upstream_currency || detailOrder.currency) }}
                </div>
              </div>
              <div v-if="hasLocalRefundAmount" class="rounded-md border border-border bg-muted/20 p-4 text-center">
                <div class="text-xs text-muted-foreground">{{ t('procurement.detail.localRefunded') }}</div>
                <div class="mt-1 text-lg font-bold text-rose-600">
                  {{ formatMoney(detailOrder.local_order?.refunded_amount, detailOrder.currency) }}
                </div>
              </div>
              <div class="rounded-md border border-border bg-muted/20 p-4 text-center">
                <div class="text-xs text-muted-foreground">{{ t('procurement.detail.profit') }}</div>
                <div class="mt-1 text-lg font-bold" :class="profitClass(detailOrder)">
                  {{ profitAmount(detailOrder) !== null ? formatMoney(profitAmount(detailOrder)!, detailOrder.currency) : '-' }}
                </div>
              </div>
            </div>
          </div>

          <!-- Upstream Refund Records -->
          <div v-if="detailUpstreamRefundRecords.length > 0" class="rounded-lg border border-border">
            <div class="border-b border-border bg-muted/30 px-4 py-2 text-xs font-semibold text-muted-foreground uppercase">
              {{ t('procurement.detail.upstreamRefundRecords') }}
            </div>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-border text-sm">
                <thead class="bg-muted/20 text-xs text-muted-foreground">
                  <tr>
                    <th class="px-4 py-2 text-left">ID</th>
                    <th class="px-4 py-2 text-left">{{ t('admin.orderRefunds.table.refundType') }}</th>
                    <th class="px-4 py-2 text-left">{{ t('admin.orderRefunds.table.amount') }}</th>
                    <th class="px-4 py-2 text-left">{{ t('admin.orderRefunds.table.createdAt') }}</th>
                    <th class="px-4 py-2 text-left">{{ t('admin.orderRefunds.detailRemark') }}</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-border">
                  <tr v-for="record in detailUpstreamRefundRecords" :key="record.id">
                    <td class="px-4 py-2 font-mono">{{ record.id }}</td>
                    <td class="px-4 py-2">{{ getUpstreamRefundTypeLabel(record.type) }}</td>
                    <td class="px-4 py-2 font-mono">
                      {{ record.amount ? formatMoney(record.amount, record.currency || detailOrder.upstream_currency || detailOrder.currency) : '-' }}
                    </td>
                    <td class="px-4 py-2">{{ formatTime(record.createdAt) }}</td>
                    <td class="px-4 py-2">{{ record.remark || '-' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Local Order Info -->
          <div v-if="detailOrder.local_order" class="rounded-lg border border-border">
            <div class="border-b border-border bg-muted/30 px-4 py-2 text-xs font-semibold text-muted-foreground uppercase">
              {{ t('procurement.detail.localOrder') }}
            </div>
            <div class="p-4 space-y-2">
              <div v-if="detailOrder.local_order.items?.length" class="space-y-2">
                <div v-for="(item, idx) in detailOrder.local_order.items" :key="idx" class="flex flex-col gap-2 text-sm sm:flex-row sm:items-center sm:gap-3">
                  <div class="min-w-0 flex-1">
                    <span class="break-words font-medium">{{ getLocalizedText(item.title) }}</span>
                    <span v-if="item.sku_snapshot?.sku_code" class="mt-1 block text-xs text-muted-foreground sm:ml-2 sm:mt-0 sm:inline">
                      SKU: {{ item.sku_snapshot.sku_code }}
                    </span>
                  </div>
                  <span class="text-muted-foreground">x{{ item.quantity }}</span>
                  <span class="font-mono">{{ formatMoney(item.total_amount, detailOrder.currency) }}</span>
                </div>
              </div>
              <div class="flex flex-col gap-1 border-t border-border pt-1 text-xs text-muted-foreground sm:flex-row sm:flex-wrap sm:items-center sm:gap-4">
                <span>{{ t('procurement.detail.orderStatus') }}: {{ getLocalOrderStatusLabel(detailOrder.local_order.status) }}</span>
                <span v-if="detailOrder.local_order.user_email" class="break-all">{{ detailOrder.local_order.user_email }}</span>
              </div>
            </div>
          </div>

          <!-- Timeline -->
          <div class="rounded-lg border border-border">
            <div class="border-b border-border bg-muted/30 px-4 py-2 text-xs font-semibold text-muted-foreground uppercase">
              {{ t('procurement.detail.timeline') }}
            </div>
            <div class="p-4 space-y-3">
              <div class="flex flex-col gap-1 text-xs sm:flex-row sm:items-start sm:gap-3">
                <div class="w-full shrink-0 text-muted-foreground sm:w-32">{{ t('procurement.columns.createdAt') }}</div>
                <div class="break-all">{{ formatTime(detailOrder.created_at) }}</div>
              </div>
              <div class="flex flex-col gap-1 text-xs sm:flex-row sm:items-start sm:gap-3">
                <div class="w-full shrink-0 text-muted-foreground sm:w-32">{{ t('procurement.detail.updatedAt') }}</div>
                <div class="break-all">{{ formatTime(detailOrder.updated_at) }}</div>
              </div>
              <div v-if="detailOrder.next_retry_at" class="flex flex-col gap-1 text-xs sm:flex-row sm:items-start sm:gap-3">
                <div class="w-full shrink-0 text-muted-foreground sm:w-32">{{ t('procurement.detail.nextRetryAt') }}</div>
                <div class="break-all">{{ formatTime(detailOrder.next_retry_at) }}</div>
              </div>
              <div class="flex flex-col gap-1 text-xs sm:flex-row sm:items-start sm:gap-3">
                <div class="w-full shrink-0 text-muted-foreground sm:w-32">{{ t('procurement.columns.retryCount') }}</div>
                <div>{{ detailOrder.retry_count ?? 0 }}</div>
              </div>
            </div>
          </div>

          <!-- Error detail -->
          <div v-if="detailOrder.error_message" class="rounded-lg border border-red-200 bg-red-50/50">
            <div class="border-b border-red-200 bg-red-50 px-4 py-2 text-xs font-semibold text-red-700 uppercase">
              {{ t('procurement.columns.errorMessage') }}
            </div>
            <div class="p-4 text-sm font-mono whitespace-pre-wrap break-all text-red-700">
              {{ detailOrder.error_message }}
            </div>
          </div>

          <!-- Upstream payload -->
          <div v-if="detailOrder.upstream_payload" class="rounded-lg border border-border">
            <div class="flex items-center justify-between border-b border-border bg-muted/30 px-4 py-2">
              <span class="text-xs font-semibold text-muted-foreground uppercase">{{ t('procurement.detail.upstreamPayload') }}</span>
              <div class="flex items-center gap-2">
                <span v-if="(detailOrder.upstream_payload_line_count ?? 0) > 100" class="text-xs text-muted-foreground">{{ t('admin.orders.fulfillmentTotalLines', { count: detailOrder.upstream_payload_line_count }) }}</span>
                <Button v-if="(detailOrder.upstream_payload_line_count ?? 0) > 100" size="xs" variant="outline" :disabled="procurementDownloading" @click="handleDownloadUpstreamPayload(detailOrder.id)">
                  {{ procurementDownloading ? t('admin.orders.fulfillmentDownloading') : t('admin.orders.fulfillmentDownload') }}
                </Button>
              </div>
            </div>
            <div class="max-h-48 overflow-y-auto p-4 text-xs font-mono whitespace-pre-wrap break-all text-muted-foreground">
              {{ detailOrder.upstream_payload }}
            </div>
          </div>

          <!-- Actions -->
          <div class="flex flex-col-reverse gap-3 border-t border-border pt-4 sm:flex-row sm:justify-end">
            <Button
              v-if="canRetry(detailOrder.status)"
              variant="outline"
              class="w-full sm:w-auto"
              :disabled="retryingId === detailOrder.id"
              @click="handleRetry(detailOrder)"
            >
              {{ t('procurement.actions.retry') }}
            </Button>
            <Button
              v-if="canCancel(detailOrder.status)"
              variant="destructive"
              class="w-full sm:w-auto"
              :disabled="cancelingId === detailOrder.id"
              @click="handleCancel(detailOrder)"
            >
              {{ t('procurement.actions.cancelOrder') }}
            </Button>
            <Button variant="outline" class="w-full sm:w-auto" @click="closeDetail">{{ t('admin.common.cancel') }}</Button>
          </div>
        </div>
      </DialogScrollContent>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminReconciliationJob, AdminReconciliationItem, AdminSiteConnection } from '@/api/types'
import IdCell from '@/components/IdCell.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import TableSkeleton from '@/components/TableSkeleton.vue'
import ListPagination from '@/components/ListPagination.vue'
import { useListRefresh, type ListFetchOptions } from '@/composables/useListRefresh'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { notifyError, notifySuccess } from '@/utils/notify'
import ComplianceGuardWrapper from '@/components/ComplianceGuardWrapper.vue'
import { formatDate, toRFC3339 } from '@/utils/format'

const { t } = useI18n()
const loading = ref(true)
const { refreshing, refreshList } = useListRefresh()
const jobs = ref<(AdminReconciliationJob & Record<string, unknown>)[]>([])
const pagination = reactive({
  page: 1,
  page_size: 20,
  total: 0,
  total_page: 1,
})
const filters = reactive({
  status: '__all__',
  type: '__all__',
  connection_id: '__all__',
})

// 站点连接列表
const connections = ref<AdminSiteConnection[]>([])
const loadingConnections = ref(false)

const fetchConnections = async () => {
  loadingConnections.value = true
  try {
    const res = await adminAPI.getSiteConnections({ page: 1, page_size: 200 })
    connections.value = res.data.data || []
  } catch {
    connections.value = []
  } finally {
    loadingConnections.value = false
  }
}

// Job list
const statusOptions = [
  { value: '__all__', key: 'reconciliation.filters.allStatus' },
  { value: 'pending', key: 'reconciliation.status.pending' },
  { value: 'running', key: 'reconciliation.status.running' },
  { value: 'completed', key: 'reconciliation.status.completed' },
  { value: 'failed', key: 'reconciliation.status.failed' },
]

const typeOptions = [
  { value: '__all__', key: 'reconciliation.filters.allTypes' },
  { value: 'status', key: 'reconciliation.type.status' },
  { value: 'amount', key: 'reconciliation.type.amount' },
  { value: 'full', key: 'reconciliation.type.full' },
]

// New job form
const showNewJob = ref(false)
const newJobForm = reactive({
  connection_id: '',
  type: 'full',
  time_range_start: '',
  time_range_end: '',
})

const openNewJob = () => {
  if (connections.value.length === 0) fetchConnections()
  showNewJob.value = true
}
const submitting = ref(false)

// Detail dialog
const showDetail = ref(false)
const detailJob = ref<(AdminReconciliationJob & Record<string, unknown>) | null>(null)
const detailItems = ref<(AdminReconciliationItem & Record<string, unknown>)[]>([])
const detailItemsTotal = ref(0)
const detailItemsPage = ref(1)

// Resolve dialog
const showResolve = ref(false)
const resolveItemId = ref<number | null>(null)
const resolveRemark = ref('')
const resolving = ref(false)

const fetchJobs = async (page = 1, options: ListFetchOptions = {}) => {
  if (!options.preserveRows) loading.value = true
  try {
    const params: Record<string, unknown> = { page, page_size: pagination.page_size }
    if (filters.status && filters.status !== '__all__') params.status = filters.status
    if (filters.type && filters.type !== '__all__') params.type = filters.type
    if (filters.connection_id && filters.connection_id !== '__all__') params.connection_id = filters.connection_id

    const res = await adminAPI.getReconciliationJobs(params)
    jobs.value = (res.data.data || []) as (AdminReconciliationJob & Record<string, unknown>)[]
    const p = res.data.pagination
    if (p) {
      pagination.page = p.page
      pagination.page_size = p.page_size
      pagination.total = p.total
      pagination.total_page = p.total_page
    }
  } catch {
    if (!options.preserveRows) jobs.value = []
  } finally {
    if (!options.preserveRows) loading.value = false
  }
}

const changePage = (page: number) => {
  if (page < 1 || page > pagination.total_page) return
  fetchJobs(page)
}

const pageSizeOptions = [10, 20, 50, 100]

const changePageSize = (size: number) => {
  if (size === pagination.page_size) return
  pagination.page_size = size
  fetchJobs(1)
}

const refresh = () => {
  refreshList(() => fetchJobs(1, { preserveRows: true }))
}

const handleNewJob = async () => {
  if (!newJobForm.connection_id || !newJobForm.time_range_start || !newJobForm.time_range_end) return
  const timeRangeStart = toRFC3339(newJobForm.time_range_start)
  const timeRangeEnd = toRFC3339(newJobForm.time_range_end)
  if (!timeRangeStart || !timeRangeEnd) return
  submitting.value = true
  try {
    await adminAPI.runReconciliation({
      connection_id: Number(newJobForm.connection_id),
      type: newJobForm.type,
      time_range_start: timeRangeStart,
      time_range_end: timeRangeEnd,
    })
    notifySuccess(t('reconciliation.form.submitSuccess'))
    showNewJob.value = false
    newJobForm.connection_id = ''
    newJobForm.time_range_start = ''
    newJobForm.time_range_end = ''
    fetchJobs(1)
  } catch (err: any) {
    notifyError(err?.response?.data?.message || err?.message)
  } finally {
    submitting.value = false
  }
}

const openDetail = async (job: AdminReconciliationJob) => {
  try {
    const res = await adminAPI.getReconciliationJob(job.id, { items_page: 1, items_page_size: 20 })
    const data = res.data.data as unknown as Record<string, unknown>
    detailJob.value = (data.job || job) as AdminReconciliationJob & Record<string, unknown>
    detailItems.value = (data.items as (AdminReconciliationItem & Record<string, unknown>)[]) || []
    detailItemsTotal.value = (data.items_total as number) || 0
    detailItemsPage.value = 1
  } catch {
    detailJob.value = job as AdminReconciliationJob & Record<string, unknown>
    detailItems.value = []
    detailItemsTotal.value = 0
  }
  showDetail.value = true
}

const loadDetailItems = async (page: number) => {
  if (!detailJob.value) return
  try {
    const res = await adminAPI.getReconciliationJob(detailJob.value.id, { items_page: page, items_page_size: 20 })
    const data = res.data.data as unknown as Record<string, unknown>
    detailItems.value = (data.items as (AdminReconciliationItem & Record<string, unknown>)[]) || []
    detailItemsTotal.value = (data.items_total as number) || 0
    detailItemsPage.value = page
  } catch {
    // keep current items
  }
}

const closeDetail = () => {
  showDetail.value = false
  detailJob.value = null
  detailItems.value = []
}

const openResolve = (item: AdminReconciliationItem & Record<string, unknown>) => {
  resolveItemId.value = item.id
  resolveRemark.value = ''
  showResolve.value = true
}

const handleResolve = async () => {
  if (!resolveItemId.value) return
  resolving.value = true
  try {
    await adminAPI.resolveReconciliationItem(resolveItemId.value, { remark: resolveRemark.value })
    notifySuccess(t('reconciliation.items.resolveSuccess'))
    showResolve.value = false
    // Refresh detail items
    if (detailJob.value) {
      await loadDetailItems(detailItemsPage.value)
    }
  } catch (err: any) {
    notifyError(err?.response?.data?.message || err?.message)
  } finally {
    resolving.value = false
  }
}

const statusBadgeClass = (status: string) => {
  switch (status) {
    case 'pending':
      return 'text-yellow-700 border-yellow-200 bg-yellow-50'
    case 'running':
      return 'text-blue-700 border-blue-200 bg-blue-50'
    case 'completed':
      return 'text-emerald-700 border-emerald-200 bg-emerald-50'
    case 'failed':
      return 'text-red-700 border-red-200 bg-red-50'
    default:
      return 'text-muted-foreground border-border bg-muted/30'
  }
}

const mismatchBadgeClass = (type: string) => {
  switch (type) {
    case 'status':
      return 'text-orange-700 border-orange-200 bg-orange-50'
    case 'amount':
      return 'text-purple-700 border-purple-200 bg-purple-50'
    case 'both':
      return 'text-red-700 border-red-200 bg-red-50'
    default:
      return 'text-muted-foreground border-border bg-muted/30'
  }
}

const formatTime = (raw?: string) => {
  return formatDate(raw) || '-'
}

onMounted(() => {
  fetchConnections()
  fetchJobs()
})
</script>

<template>
  <ComplianceGuardWrapper>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <h1 class="text-2xl font-semibold">{{ t('reconciliation.title') }}</h1>
      <Button size="sm" class="w-full sm:w-auto" @click="openNewJob">{{ t('reconciliation.newJob') }}</Button>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap items-end gap-3">
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.status') }}</label>
        <Select v-model="filters.status">
          <SelectTrigger class="h-9 w-full md:w-40">
            <SelectValue :placeholder="t('reconciliation.filters.allStatus')" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="opt in statusOptions" :key="opt.value" :value="opt.value">
              {{ t(opt.key) }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.type') }}</label>
        <Select v-model="filters.type">
          <SelectTrigger class="h-9 w-full md:w-40">
            <SelectValue :placeholder="t('reconciliation.filters.allTypes')" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="opt in typeOptions" :key="opt.value" :value="opt.value">
              {{ t(opt.key) }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="w-full sm:w-auto">
        <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.filters.connectionId') }}</label>
        <Select v-model="filters.connection_id">
          <SelectTrigger class="h-9 w-full md:w-48">
            <SelectValue :placeholder="t('reconciliation.filters.allConnections')" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="__all__">{{ t('reconciliation.filters.allConnections') }}</SelectItem>
            <SelectItem v-for="conn in connections" :key="conn.id" :value="String(conn.id)">
              {{ conn.name || `#${conn.id}` }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <Button size="sm" class="h-9 w-full sm:w-auto" :disabled="refreshing" @click="refresh">{{ t('admin.common.refresh') }}</Button>
    </div>

    <!-- Table -->
    <div class="rounded-xl border border-border bg-card overflow-x-auto">
      <Table class="min-w-[960px]">
        <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
          <TableRow>
            <TableHead class="min-w-[80px] px-6 py-3">{{ t('reconciliation.columns.id') }}</TableHead>
            <TableHead class="min-w-[160px] px-6 py-3">{{ t('reconciliation.columns.connection') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('reconciliation.columns.type') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('reconciliation.columns.status') }}</TableHead>
            <TableHead class="min-w-[160px] px-6 py-3">{{ t('reconciliation.columns.timeRange') }}</TableHead>
            <TableHead class="min-w-[80px] px-6 py-3">{{ t('reconciliation.columns.total') }}</TableHead>
            <TableHead class="min-w-[80px] px-6 py-3">{{ t('reconciliation.columns.matched') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('reconciliation.columns.mismatched') }}</TableHead>
            <TableHead class="min-w-[80px] px-6 py-3">{{ t('reconciliation.columns.createdAt') }}</TableHead>
            <TableHead class="min-w-[80px] px-6 py-3 text-right">{{ t('reconciliation.columns.actions') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody class="divide-y divide-border">
          <TableRow v-if="loading">
            <TableCell :colspan="10" class="p-0">
              <TableSkeleton :columns="10" :rows="5" />
            </TableCell>
          </TableRow>
          <TableRow v-else-if="jobs.length === 0">
            <TableCell colspan="10" class="px-6 py-8 text-center text-muted-foreground">{{ t('reconciliation.empty') }}</TableCell>
          </TableRow>
          <TableRow
            v-for="job in jobs"
            :key="job.id"
            class="cursor-pointer hover:bg-muted/30"
            @click="openDetail(job)"
          >
            <TableCell class="min-w-[80px] px-6 py-4">
              <IdCell :value="job.id" />
            </TableCell>
            <TableCell class="min-w-[160px] px-6 py-4 font-medium text-foreground break-words">
              {{ (job.connection as any)?.name || job.connection_id || '-' }}
            </TableCell>
            <TableCell class="min-w-[90px] px-6 py-4">
              <span class="text-xs">{{ t('reconciliation.type.' + job.type) }}</span>
            </TableCell>
            <TableCell class="min-w-[90px] px-6 py-4">
              <span
                class="inline-flex rounded-full border px-2.5 py-1 text-xs"
                :class="statusBadgeClass(job.status)"
              >
                {{ t('reconciliation.status.' + job.status) }}
              </span>
            </TableCell>
            <TableCell class="min-w-[160px] px-6 py-4 text-xs text-muted-foreground break-words">
              {{ formatTime(job.time_range_start) }} ~ {{ formatTime(job.time_range_end) }}
            </TableCell>
            <TableCell class="min-w-[80px] px-6 py-4 text-xs text-muted-foreground">{{ job.total_count }}</TableCell>
            <TableCell class="min-w-[80px] px-6 py-4 text-xs text-emerald-600">{{ job.matched_count }}</TableCell>
            <TableCell class="min-w-[90px] px-6 py-4 text-xs" :class="(job.mismatched_count as number) > 0 ? 'text-red-600 font-semibold' : 'text-muted-foreground'">
              {{ job.mismatched_count }}
            </TableCell>
            <TableCell class="min-w-[80px] px-6 py-4 text-xs text-muted-foreground">
              {{ formatTime(job.created_at) }}
            </TableCell>
            <TableCell class="min-w-[80px] px-6 py-4 text-right" @click.stop>
              <Button size="sm" variant="outline" @click="openDetail(job)">
                {{ t('reconciliation.detail.title') }}
              </Button>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>

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
    </div>

    <!-- New Job Dialog -->
    <Dialog v-model:open="showNewJob">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-md p-4 sm:p-6" @interact-outside="(e: Event) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ t('reconciliation.newJob') }}</DialogTitle>
        </DialogHeader>
        <div class="space-y-4 pt-2">
          <div>
            <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.form.connectionId') }}</label>
            <Select v-model="newJobForm.connection_id">
              <SelectTrigger class="h-9">
                <SelectValue :placeholder="t('reconciliation.form.selectConnection')" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="conn in connections" :key="conn.id" :value="String(conn.id)">
                  {{ conn.name || `#${conn.id}` }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.form.type') }}</label>
            <Select v-model="newJobForm.type">
              <SelectTrigger class="h-9">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="status">{{ t('reconciliation.type.status') }}</SelectItem>
                <SelectItem value="amount">{{ t('reconciliation.type.amount') }}</SelectItem>
                <SelectItem value="full">{{ t('reconciliation.type.full') }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.form.timeRangeStart') }}</label>
            <Input v-model="newJobForm.time_range_start" type="datetime-local" class="h-9" />
          </div>
          <div>
            <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.form.timeRangeEnd') }}</label>
            <Input v-model="newJobForm.time_range_end" type="datetime-local" class="h-9" />
          </div>
          <div class="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
            <Button variant="outline" class="w-full sm:w-auto" @click="showNewJob = false">{{ t('admin.common.cancel') }}</Button>
            <Button class="w-full sm:w-auto" :disabled="submitting || !newJobForm.connection_id || !newJobForm.time_range_start || !newJobForm.time_range_end" @click="handleNewJob">
              {{ t('reconciliation.form.submit') }}
            </Button>
          </div>
        </div>
      </DialogScrollContent>
    </Dialog>

    <!-- Detail Dialog -->
    <Dialog v-model:open="showDetail" @update:open="(value: boolean) => { if (!value) closeDetail() }">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-4xl p-4 sm:p-6" @interact-outside="(e: Event) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ t('reconciliation.detail.title') }}</DialogTitle>
        </DialogHeader>

        <div v-if="detailJob" class="space-y-4">
          <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.id') }}</label>
              <div class="text-sm">{{ detailJob.id }}</div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.connection') }}</label>
              <div class="text-sm">{{ (detailJob.connection as any)?.name || detailJob.connection_id || '-' }}</div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.type') }}</label>
              <div class="text-sm">{{ t('reconciliation.type.' + detailJob.type) }}</div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.status') }}</label>
              <div>
                <span class="inline-flex rounded-full border px-2.5 py-1 text-xs" :class="statusBadgeClass(detailJob.status)">
                  {{ t('reconciliation.status.' + detailJob.status) }}
                </span>
              </div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.total') }}</label>
              <div class="text-sm">{{ detailJob.total_count }}</div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.matched') }} / {{ t('reconciliation.columns.mismatched') }}</label>
              <div class="text-sm">
                <span class="text-emerald-600">{{ detailJob.matched_count }}</span>
                /
                <span :class="(detailJob.mismatched_count as number) > 0 ? 'text-red-600 font-semibold' : ''">{{ detailJob.mismatched_count }}</span>
              </div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.timeRange') }}</label>
              <div class="text-xs">{{ formatTime(detailJob.time_range_start) }} ~ {{ formatTime(detailJob.time_range_end) }}</div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.startedAt') }}</label>
              <div class="text-sm">{{ formatTime(detailJob.started_at as string) }}</div>
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.columns.finishedAt') }}</label>
              <div class="text-sm">{{ formatTime(detailJob.finished_at as string) }}</div>
            </div>
          </div>

          <div v-if="detailJob.result_json" class="mt-4">
            <label class="mb-1 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.detail.resultJson') }}</label>
            <div class="rounded-md border border-border bg-muted/30 p-3 text-sm font-mono whitespace-pre-wrap break-all">
              {{ detailJob.result_json }}
            </div>
          </div>

          <!-- Mismatch Items Table -->
          <div v-if="detailItems.length > 0" class="mt-6">
            <h3 class="mb-3 text-sm font-semibold">{{ t('reconciliation.items.title') }} ({{ detailItemsTotal }})</h3>
            <div class="rounded-lg border border-border overflow-x-auto">
              <Table class="min-w-[840px]">
                <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
                  <TableRow>
                    <TableHead class="min-w-[80px] px-4 py-2">{{ t('reconciliation.items.localOrderNo') }}</TableHead>
                    <TableHead class="min-w-[160px] px-4 py-2">{{ t('reconciliation.items.upstreamOrderNo') }}</TableHead>
                    <TableHead class="min-w-[90px] px-4 py-2">{{ t('reconciliation.items.localStatus') }}</TableHead>
                    <TableHead class="min-w-[80px] px-4 py-2">{{ t('reconciliation.items.upstreamStatus') }}</TableHead>
                    <TableHead class="min-w-[80px] px-4 py-2">{{ t('reconciliation.items.mismatchType') }}</TableHead>
                    <TableHead class="min-w-[90px] px-4 py-2">{{ t('reconciliation.columns.status') }}</TableHead>
                    <TableHead class="min-w-[80px] px-4 py-2 text-right">{{ t('reconciliation.columns.actions') }}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody class="divide-y divide-border">
                  <TableRow v-for="item in detailItems" :key="item.id">
                    <TableCell class="min-w-[80px] px-4 py-3 text-xs font-mono break-all">{{ item.local_order_no || '-' }}</TableCell>
                    <TableCell class="min-w-[160px] px-4 py-3 text-xs font-mono break-all">{{ item.upstream_order_no || '-' }}</TableCell>
                    <TableCell class="min-w-[90px] px-4 py-3 text-xs break-words">{{ item.local_status || '-' }}</TableCell>
                    <TableCell class="min-w-[80px] px-4 py-3 text-xs break-words">{{ item.upstream_status || '-' }}</TableCell>
                    <TableCell class="min-w-[80px] px-4 py-3">
                      <span
                        class="inline-flex rounded-full border px-2 py-0.5 text-xs"
                        :class="mismatchBadgeClass(item.mismatch_type as string)"
                      >
                        {{ t('reconciliation.mismatchType.' + item.mismatch_type) }}
                      </span>
                    </TableCell>
                    <TableCell class="min-w-[90px] px-4 py-3">
                      <span
                        class="inline-flex rounded-full border px-2 py-0.5 text-xs"
                        :class="item.resolved ? 'text-emerald-700 border-emerald-200 bg-emerald-50' : 'text-yellow-700 border-yellow-200 bg-yellow-50'"
                      >
                        {{ item.resolved ? t('reconciliation.items.resolved') : t('reconciliation.items.unresolved') }}
                      </span>
                    </TableCell>
                    <TableCell class="min-w-[80px] px-4 py-3 text-right">
                      <Button
                        v-if="!item.resolved"
                        size="sm"
                        variant="outline"
                        @click="openResolve(item)"
                      >
                        {{ t('reconciliation.items.resolve') }}
                      </Button>
                      <span v-else class="text-xs text-muted-foreground">{{ item.remark || '-' }}</span>
                    </TableCell>
                  </TableRow>
                </TableBody>
              </Table>
              <div v-if="detailItemsTotal > 20" class="flex items-center justify-end gap-2 border-t border-border px-4 py-3">
                <Button variant="outline" size="sm" class="h-7" :disabled="detailItemsPage <= 1" @click="loadDetailItems(detailItemsPage - 1)">
                  {{ t('admin.common.prevPage') }}
                </Button>
                <span class="text-xs text-muted-foreground">{{ detailItemsPage }}</span>
                <Button variant="outline" size="sm" class="h-7" :disabled="detailItemsPage * 20 >= detailItemsTotal" @click="loadDetailItems(detailItemsPage + 1)">
                  {{ t('admin.common.nextPage') }}
                </Button>
              </div>
            </div>
          </div>

          <div class="flex flex-col-reverse border-t border-border pt-4 sm:flex-row sm:justify-end">
            <Button variant="outline" class="w-full sm:w-auto" @click="closeDetail">{{ t('admin.common.cancel') }}</Button>
          </div>
        </div>
      </DialogScrollContent>
    </Dialog>

    <!-- Resolve Dialog -->
    <Dialog v-model:open="showResolve">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-md p-4 sm:p-6" @interact-outside="(e: Event) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ t('reconciliation.items.resolve') }}</DialogTitle>
        </DialogHeader>
        <div class="space-y-4 pt-2">
          <div>
            <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('reconciliation.items.remark') }}</label>
            <Textarea v-model="resolveRemark" :placeholder="t('reconciliation.items.remarkPlaceholder')" rows="3" />
          </div>
          <div class="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
            <Button variant="outline" class="w-full sm:w-auto" @click="showResolve = false">{{ t('admin.common.cancel') }}</Button>
            <Button class="w-full sm:w-auto" :disabled="resolving" @click="handleResolve">{{ t('reconciliation.items.resolve') }}</Button>
          </div>
        </div>
      </DialogScrollContent>
    </Dialog>
  </div>
  </ComplianceGuardWrapper>
</template>

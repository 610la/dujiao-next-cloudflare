<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  adminAPI,
  type AdminBatchGiftCardStatusPayload,
  type AdminExportGiftCardsPayload,
  type AdminGiftCardStatus,
  type AdminUpdateGiftCardPayload,
} from '@/api/admin'
import type { AdminGiftCard, AdminGiftCardBatch } from '@/api/types'
import IdCell from '@/components/IdCell.vue'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { toggleArrayMember } from '@/lib/utils'
import { Dialog, DialogHeader, DialogScrollContent, DialogTitle } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import TableSkeleton from '@/components/TableSkeleton.vue'
import ListPagination from '@/components/ListPagination.vue'
import { useListRefresh, type ListFetchOptions } from '@/composables/useListRefresh'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { formatDate } from '@/utils/format'
import { confirmAction } from '@/utils/confirm'

interface RedeemedUser {
  id?: number
  display_name?: string
  email?: string
}

type GiftCardWithRelations = AdminGiftCard & {
  is_expired?: boolean
  redeemed_user?: RedeemedUser
  batch?: AdminGiftCardBatch & { batch_no?: string }
}

const { t } = useI18n()

const loading = ref(true)
const { refreshing, refreshList } = useListRefresh()
const cards = ref<GiftCardWithRelations[]>([])
const pagination = ref({
  page: 1,
  page_size: 20,
  total: 0,
  total_page: 1,
})
const filters = reactive({
  code: '',
  status: '__all__',
  redeemedUserID: '',
  createdFrom: '',
  createdTo: '',
})

const selectedCardIDs = ref<number[]>([])
const batchStatusTarget = ref<'active' | 'disabled'>('disabled')
const batchActionLoading = ref(false)
const batchActionError = ref('')
const batchActionSuccess = ref('')

const showGenerateModal = ref(false)
const generateSubmitting = ref(false)
const generateError = ref('')
const generateForm = reactive({
  name: '',
  quantity: 10,
  amount: '',
  expiresAt: '',
})

const showEditModal = ref(false)
const editSubmitting = ref(false)
const editError = ref('')
const editingCard = ref<GiftCardWithRelations | null>(null)
const editForm = reactive({
  name: '',
  status: 'active',
  expiresAt: '',
})

const normalizeFilterValue = (value: string) => (value === '__all__' ? '' : value)

const toISO = (raw?: string) => {
  const text = String(raw || '').trim()
  if (!text) return ''
  const date = new Date(text)
  if (Number.isNaN(date.getTime())) return ''
  return date.toISOString()
}

const toLocalInput = (raw?: string) => {
  if (!raw) return ''
  const date = new Date(raw)
  if (Number.isNaN(date.getTime())) return ''
  const offset = date.getTimezoneOffset()
  const local = new Date(date.getTime() - offset * 60000)
  return local.toISOString().slice(0, 16)
}

const formatMoney = (amount?: string | number, currency?: string) => {
  if (!amount) return '-'
  return `${amount} ${currency || ''}`.trim()
}

const statusLabel = (card: GiftCardWithRelations) => {
  const status = String(card?.status || '').toLowerCase()
  if (status === 'active' && card?.is_expired) {
    return t('admin.giftCards.status.expired')
  }
  const key = `admin.giftCards.status.${status}`
  const translated = t(key)
  if (translated === key) return status || '-'
  return translated
}

const statusClass = (card: GiftCardWithRelations) => {
  const status = String(card?.status || '').toLowerCase()
  if (status === 'active' && card?.is_expired) {
    return 'text-amber-700 border-amber-200 bg-amber-50'
  }
  if (status === 'active') {
    return 'text-emerald-700 border-emerald-200 bg-emerald-50'
  }
  if (status === 'redeemed') {
    return 'text-sky-700 border-sky-200 bg-sky-50'
  }
  if (status === 'disabled') {
    return 'text-muted-foreground border-border bg-muted/30'
  }
  return 'text-muted-foreground border-border bg-muted/30'
}

const redeemedUserText = (card: GiftCardWithRelations) => {
  const user = card?.redeemed_user
  if (!user) return '-'
  const id = Number(user.id || 0)
  const displayName = String(user.display_name || '').trim()
  const email = String(user.email || '').trim()
  if (displayName && email) return `#${id} ${displayName} (${email})`
  if (displayName) return id > 0 ? `#${id} ${displayName}` : displayName
  if (email) return id > 0 ? `#${id} ${email}` : email
  return id > 0 ? `#${id}` : '-'
}

const expiresAtText = (card: GiftCardWithRelations) => {
  if (!card?.expires_at) return t('admin.giftCards.neverExpire')
  return formatDate(card.expires_at) || t('admin.giftCards.neverExpire')
}

const clearBatchMessages = () => {
  batchActionError.value = ''
  batchActionSuccess.value = ''
}

const normalizeSelectedIDs = () => {
  return Array.from(
    new Set(
      selectedCardIDs.value
        .map((item) => Number(item))
        .filter((item) => Number.isFinite(item) && item > 0)
        .map((item) => Math.floor(item))
    )
  )
}

const allCurrentPageSelected = computed(() => {
  if (!cards.value.length) return false
  return cards.value.every((item) => selectedCardIDs.value.includes(Number(item?.id || 0)))
})

const hasSelectedCards = computed(() => normalizeSelectedIDs().length > 0)

const toggleSelectAllCards = () => {
  if (allCurrentPageSelected.value) {
    selectedCardIDs.value = []
    return
  }
  selectedCardIDs.value = cards.value
    .map((item) => Number(item?.id || 0))
    .filter((id) => Number.isFinite(id) && id > 0)
}

const onRowSelectChange = (rawID: number | string, v: boolean | 'indeterminate') => {
  const id = Number(rawID)
  if (!Number.isFinite(id) || id <= 0) return
  toggleArrayMember(selectedCardIDs, Math.floor(id), v)
}

const fetchGiftCards = async (page = 1, options: ListFetchOptions = {}) => {
  if (!options.preserveRows) loading.value = true
  clearBatchMessages()
  try {
    const params: Record<string, unknown> = {
      page,
      page_size: pagination.value.page_size,
      code: String(filters.code || '').trim() || undefined,
      status: normalizeFilterValue(filters.status) || undefined,
      created_from: toISO(filters.createdFrom) || undefined,
      created_to: toISO(filters.createdTo) || undefined,
    }
    const redeemedUserID = Number(filters.redeemedUserID)
    if (Number.isFinite(redeemedUserID) && redeemedUserID > 0) {
      params.redeemed_user_id = Math.floor(redeemedUserID)
    }
    const response = await adminAPI.getGiftCards(params)
    cards.value = (response.data.data as GiftCardWithRelations[]) || []
    pagination.value = response.data.pagination || pagination.value
    selectedCardIDs.value = []
  } catch {
    if (!options.preserveRows) {
      cards.value = []
      selectedCardIDs.value = []
    }
  } finally {
    if (!options.preserveRows) loading.value = false
  }
}

const handleSearch = () => {
  fetchGiftCards(1, { preserveRows: true })
}

const refresh = () => {
  refreshList(() => fetchGiftCards(pagination.value.page, { preserveRows: true }))
}

const changePage = (page: number) => {
  if (page < 1 || page > pagination.value.total_page) return
  fetchGiftCards(page)
}

const pageSizeOptions = [10, 20, 50, 100]

const changePageSize = (size: number) => {
  if (size === pagination.value.page_size) return
  pagination.value.page_size = size
  fetchGiftCards(1)
}

const applyBatchStatus = async () => {
  clearBatchMessages()
  const ids = normalizeSelectedIDs()
  if (!ids.length) {
    batchActionError.value = t('admin.giftCards.errors.selectRequired')
    return
  }

  const payload: AdminBatchGiftCardStatusPayload = {
    ids,
    status: batchStatusTarget.value,
  }
  const confirmed = await confirmAction({
    description: t('admin.giftCards.batch.confirmStatus', {
      count: ids.length,
      status: t(`admin.giftCards.status.${batchStatusTarget.value}`),
    }),
  })
  if (!confirmed) return

  batchActionLoading.value = true
  try {
    const response = await adminAPI.batchUpdateGiftCardStatus(payload)
    const affected = Number(response?.data?.data?.affected || 0)
    batchActionSuccess.value = t('admin.giftCards.alerts.statusUpdated', { count: affected })
    await fetchGiftCards(pagination.value.page)
  } catch (err: any) {
    batchActionError.value = err?.message || t('admin.giftCards.errors.batchStatusFailed')
  } finally {
    batchActionLoading.value = false
  }
}

const exportSelected = async (format: 'txt' | 'csv') => {
  clearBatchMessages()
  const ids = normalizeSelectedIDs()
  if (!ids.length) {
    batchActionError.value = t('admin.giftCards.errors.selectRequired')
    return
  }

  batchActionLoading.value = true
  try {
    const payload: AdminExportGiftCardsPayload = { ids, format }
    const response = await adminAPI.exportGiftCards(payload) as { data: string; headers?: Record<string, string> }
    const contentDisposition = String(response?.headers?.['content-disposition'] || '')
    const filenameMatch = contentDisposition.match(/filename=\"?([^\";]+)\"?/i)
    const fallbackName = `gift-cards-${new Date().toISOString().replace(/[:.]/g, '-')}.${format}`
    const filename = filenameMatch?.[1] || fallbackName
    const contentType = format === 'csv' ? 'text/csv;charset=utf-8' : 'text/plain;charset=utf-8'
    const blob = new Blob([response.data], { type: contentType })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
    batchActionSuccess.value = t('admin.giftCards.alerts.exported', { count: ids.length, format: format.toUpperCase() })
  } catch (err: any) {
    batchActionError.value = err?.message || t('admin.giftCards.errors.exportFailed')
  } finally {
    batchActionLoading.value = false
  }
}

const resetGenerateForm = () => {
  generateForm.name = ''
  generateForm.quantity = 10
  generateForm.amount = ''
  generateForm.expiresAt = ''
  generateError.value = ''
}

const openGenerateModal = () => {
  resetGenerateForm()
  showGenerateModal.value = true
}

const closeGenerateModal = () => {
  showGenerateModal.value = false
  generateSubmitting.value = false
}

const submitGenerate = async () => {
  generateError.value = ''
  const quantity = Number(generateForm.quantity)
  if (!Number.isFinite(quantity) || quantity <= 0 || quantity > 10000) {
    generateError.value = t('admin.giftCards.errors.invalidQuantity')
    return
  }
  const amount = String(generateForm.amount || '').trim()
  const parsedAmount = Number(amount)
  if (!amount || !Number.isFinite(parsedAmount) || parsedAmount <= 0) {
    generateError.value = t('admin.giftCards.errors.invalidAmount')
    return
  }
  if (!String(generateForm.name || '').trim()) {
    generateError.value = t('admin.giftCards.errors.nameRequired')
    return
  }

  generateSubmitting.value = true
  try {
    const response = await adminAPI.generateGiftCards({
      name: generateForm.name.trim(),
      quantity: Math.floor(quantity),
      amount,
      expires_at: generateForm.expiresAt ? toISO(generateForm.expiresAt) : '',
    })
    const created = Number(response?.data?.data?.created || 0)
    const batchNo = String(response?.data?.data?.batch?.batch_no || '').trim()
    batchActionSuccess.value = batchNo
      ? t('admin.giftCards.alerts.generatedDetail', { count: created, batchNo })
      : t('admin.giftCards.alerts.generated', { count: created })
    closeGenerateModal()
    await fetchGiftCards(1)
  } catch (err: any) {
    generateError.value = err?.message || t('admin.giftCards.errors.generateFailed')
  } finally {
    generateSubmitting.value = false
  }
}

const openEditModal = (card: GiftCardWithRelations) => {
  editingCard.value = card
  editForm.name = String(card?.name || '')
  const normalizedStatus = String(card?.status || '').toLowerCase()
  editForm.status = normalizedStatus === 'disabled' ? 'disabled' : 'active'
  editForm.expiresAt = toLocalInput(card?.expires_at)
  editError.value = ''
  showEditModal.value = true
}

const closeEditModal = () => {
  showEditModal.value = false
  editSubmitting.value = false
  editingCard.value = null
  editError.value = ''
}

const editCardReadonly = computed(() => String(editingCard.value?.status || '') === 'redeemed')

const submitEdit = async () => {
  if (!editingCard.value?.id) return
  editError.value = ''
  const name = String(editForm.name || '').trim()
  if (!name) {
    editError.value = t('admin.giftCards.errors.nameRequired')
    return
  }

  editSubmitting.value = true
  try {
    const payload: AdminUpdateGiftCardPayload = {
      name,
    }
    if (!editCardReadonly.value) {
      const nextStatus = String(editForm.status || '').trim().toLowerCase()
      if (nextStatus === 'active' || nextStatus === 'disabled') {
        if (nextStatus !== String(editingCard.value?.status || '').toLowerCase()) {
          payload.status = nextStatus as Exclude<AdminGiftCardStatus, 'redeemed'>
        }
      }
    }

    const oldExpires = toLocalInput(editingCard.value?.expires_at)
    if (editForm.expiresAt !== oldExpires) {
      payload.expires_at = editForm.expiresAt ? toISO(editForm.expiresAt) : ''
    }

    await adminAPI.updateGiftCard(Number(editingCard.value.id), payload)
    batchActionSuccess.value = t('admin.giftCards.alerts.updated')
    closeEditModal()
    await fetchGiftCards(pagination.value.page)
  } catch (err: any) {
    editError.value = err?.message || t('admin.giftCards.errors.updateFailed')
  } finally {
    editSubmitting.value = false
  }
}

const handleDelete = async (card: GiftCardWithRelations) => {
  const confirmed = await confirmAction({
    description: t('admin.giftCards.confirmDelete', { code: card.code }),
    confirmText: t('admin.common.delete'),
    variant: 'destructive',
  })
  if (!confirmed) return
  try {
    await adminAPI.deleteGiftCard(Number(card.id))
    batchActionSuccess.value = t('admin.giftCards.alerts.deleted')
    const targetPage = cards.value.length === 1 && pagination.value.page > 1
      ? pagination.value.page - 1
      : pagination.value.page
    await fetchGiftCards(targetPage)
  } catch (err: any) {
    batchActionError.value = err?.message || t('admin.giftCards.errors.deleteFailed')
  }
}

onMounted(() => {
  fetchGiftCards()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <h1 class="text-2xl font-semibold">{{ t('admin.giftCards.title') }}</h1>
      <Button size="sm" class="w-full gap-2 sm:w-auto" @click="openGenerateModal">
        <svg class="h-4 w-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        {{ t('admin.giftCards.generate') }}
      </Button>
    </div>

    <div class="rounded-xl border border-border bg-card p-4 shadow-sm">
      <div class="grid grid-cols-1 gap-3 md:grid-cols-12">
        <div class="md:col-span-3">
          <Input v-model="filters.code" :placeholder="t('admin.giftCards.filterCode')" @keyup.enter="handleSearch" />
        </div>
        <div class="md:col-span-2">
          <Input v-model="filters.redeemedUserID" type="number" min="1" :placeholder="t('admin.giftCards.filterUserID')" @keyup.enter="handleSearch" />
        </div>
        <div class="md:col-span-2">
          <Select v-model="filters.status" @update:modelValue="handleSearch">
            <SelectTrigger class="h-9 w-full">
              <SelectValue :placeholder="t('admin.giftCards.filterStatusAll')" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="__all__">{{ t('admin.giftCards.filterStatusAll') }}</SelectItem>
              <SelectItem value="active">{{ t('admin.giftCards.status.active') }}</SelectItem>
              <SelectItem value="expired">{{ t('admin.giftCards.status.expired') }}</SelectItem>
              <SelectItem value="redeemed">{{ t('admin.giftCards.status.redeemed') }}</SelectItem>
              <SelectItem value="disabled">{{ t('admin.giftCards.status.disabled') }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="md:col-span-2">
          <Input v-model="filters.createdFrom" type="datetime-local" :placeholder="t('admin.giftCards.filterCreatedFrom')" />
        </div>
        <div class="md:col-span-2">
          <Input v-model="filters.createdTo" type="datetime-local" :placeholder="t('admin.giftCards.filterCreatedTo')" />
        </div>
        <div class="md:col-span-1 flex items-center justify-end">
          <Button size="sm" class="w-full md:w-auto" @click="handleSearch">{{ t('admin.giftCards.search') }}</Button>
        </div>
      </div>
    </div>

    <div v-if="hasSelectedCards" class="rounded-xl border border-border bg-card p-4 shadow-sm space-y-3">
      <div class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <span class="text-xs text-muted-foreground">{{ t('admin.giftCards.batch.selectedCount', { count: selectedCardIDs.length }) }}</span>
        <div class="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
          <Select v-model="batchStatusTarget">
            <SelectTrigger class="h-8 w-full text-xs sm:w-[170px]">
              <SelectValue :placeholder="t('admin.giftCards.batch.statusPlaceholder')" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="active">{{ t('admin.giftCards.status.active') }}</SelectItem>
              <SelectItem value="disabled">{{ t('admin.giftCards.status.disabled') }}</SelectItem>
            </SelectContent>
          </Select>
          <Button size="sm" variant="outline" class="w-full sm:w-auto" :disabled="batchActionLoading" @click="applyBatchStatus">
            {{ t('admin.giftCards.batch.applyStatus') }}
          </Button>
          <Button size="sm" variant="outline" class="w-full sm:w-auto" :disabled="batchActionLoading" @click="exportSelected('txt')">
            {{ t('admin.giftCards.batch.exportTxt') }}
          </Button>
          <Button size="sm" variant="outline" class="w-full sm:w-auto" :disabled="batchActionLoading" @click="exportSelected('csv')">
            {{ t('admin.giftCards.batch.exportCsv') }}
          </Button>
        </div>
      </div>
      <div v-if="batchActionError" class="rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
        {{ batchActionError }}
      </div>
      <div v-if="batchActionSuccess" class="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
        {{ batchActionSuccess }}
      </div>
    </div>

    <div class="rounded-xl border border-border bg-card overflow-x-auto">
      <Table class="min-w-[1060px]">
        <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
          <TableRow>
            <TableHead class="min-w-[56px] px-4 py-3">
              <Checkbox :model-value="allCurrentPageSelected" @update:model-value="toggleSelectAllCards" />
            </TableHead>
            <TableHead class="min-w-[80px] px-4 py-3">{{ t('admin.giftCards.table.id') }}</TableHead>
            <TableHead class="min-w-[80px] px-4 py-3">{{ t('admin.giftCards.table.name') }}</TableHead>
            <TableHead class="min-w-[160px] px-4 py-3">{{ t('admin.giftCards.table.code') }}</TableHead>
            <TableHead class="min-w-[80px] px-4 py-3">{{ t('admin.giftCards.table.amount') }}</TableHead>
            <TableHead class="min-w-[90px] px-4 py-3">{{ t('admin.giftCards.table.status') }}</TableHead>
            <TableHead class="min-w-[80px] px-4 py-3">{{ t('admin.giftCards.table.batchNo') }}</TableHead>
            <TableHead class="min-w-[160px] px-4 py-3">{{ t('admin.giftCards.table.redeemedUser') }}</TableHead>
            <TableHead class="min-w-[80px] px-4 py-3">{{ t('admin.giftCards.table.redeemedAt') }}</TableHead>
            <TableHead class="min-w-[80px] px-4 py-3">{{ t('admin.giftCards.table.expiresAt') }}</TableHead>
            <TableHead class="min-w-[80px] px-4 py-3">{{ t('admin.giftCards.table.createdAt') }}</TableHead>
            <TableHead class="min-w-[80px] px-4 py-3 text-right">{{ t('admin.giftCards.table.action') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody class="divide-y divide-border">
          <TableRow v-if="loading">
            <TableCell :colspan="12" class="p-0">
              <TableSkeleton :columns="12" :rows="5" />
            </TableCell>
          </TableRow>
          <TableRow v-else-if="cards.length === 0">
            <TableCell colspan="12" class="px-4 py-8 text-center text-muted-foreground">{{ t('admin.giftCards.empty') }}</TableCell>
          </TableRow>
          <TableRow v-for="card in cards" :key="card.id" class="hover:bg-muted/30">
            <TableCell class="min-w-[56px] px-4 py-3">
              <Checkbox
                :model-value="selectedCardIDs.includes(Number(card.id))"
                @update:model-value="(v) => onRowSelectChange(card.id, v)"
              />
            </TableCell>
            <TableCell class="min-w-[80px] px-4 py-3"><IdCell :value="card.id" /></TableCell>
            <TableCell class="min-w-[80px] px-4 py-3 text-foreground font-medium break-words">{{ card.name || '-' }}</TableCell>
            <TableCell class="min-w-[160px] px-4 py-3 font-mono text-xs text-foreground break-all">{{ card.code || '-' }}</TableCell>
            <TableCell class="min-w-[80px] px-4 py-3 font-mono text-xs text-foreground">{{ formatMoney(card.amount, card.currency) }}</TableCell>
            <TableCell class="min-w-[90px] px-4 py-3">
              <span class="inline-flex rounded-full border px-2.5 py-1 text-xs" :class="statusClass(card)">
                {{ statusLabel(card) }}
              </span>
            </TableCell>
            <TableCell class="min-w-[80px] px-4 py-3 text-xs text-muted-foreground break-all">{{ card.batch?.batch_no || '-' }}</TableCell>
            <TableCell class="min-w-[160px] px-4 py-3 text-xs text-muted-foreground break-words">{{ redeemedUserText(card) }}</TableCell>
            <TableCell class="min-w-[80px] px-4 py-3 text-xs text-muted-foreground">{{ formatDate(card.redeemed_at) || '-' }}</TableCell>
            <TableCell class="min-w-[80px] px-4 py-3 text-xs text-muted-foreground break-words">{{ expiresAtText(card) }}</TableCell>
            <TableCell class="min-w-[80px] px-4 py-3 text-xs text-muted-foreground">{{ formatDate(card.created_at) || '-' }}</TableCell>
            <TableCell class="min-w-[80px] px-4 py-3 text-right">
              <div class="flex flex-wrap items-center justify-end gap-2">
                <Button size="sm" variant="outline" @click="openEditModal(card)">{{ t('admin.giftCards.actions.edit') }}</Button>
                <Button
                  size="sm"
                  variant="destructive"
                  :disabled="String(card.status || '').toLowerCase() === 'redeemed'"
                  @click="handleDelete(card)"
                >
                  {{ t('admin.giftCards.actions.delete') }}
                </Button>
              </div>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>

      <ListPagination
        :page="pagination.page"
        :total-page="pagination.total_page"
        :total="pagination.total"
        :page-size="pagination.page_size"
        :page-size-options="pageSizeOptions"
        @change-page="changePage"
        @change-page-size="changePageSize"
      >
        <template #actions>
          <Button size="sm" variant="outline" class="h-8" :disabled="refreshing" @click="refresh">{{ t('admin.common.refresh') }}</Button>
        </template>
      </ListPagination>
    </div>

    <Dialog v-model:open="showGenerateModal" @update:open="(value) => { if (!value) closeGenerateModal() }">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-xl p-4 sm:p-6" @interact-outside="(e) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ t('admin.giftCards.modal.generateTitle') }}</DialogTitle>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="submitGenerate">
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div class="space-y-2 md:col-span-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.giftCards.form.name') }}</label>
              <Input v-model="generateForm.name" maxlength="120" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.giftCards.form.quantity') }}</label>
              <Input v-model.number="generateForm.quantity" type="number" min="1" max="10000" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.giftCards.form.amount') }}</label>
              <Input v-model="generateForm.amount" type="text" inputmode="decimal" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.giftCards.form.expiresAt') }}</label>
              <Input v-model="generateForm.expiresAt" type="datetime-local" />
              <p class="text-xs text-muted-foreground">{{ t('admin.giftCards.form.expiresHint') }}</p>
            </div>
          </div>

          <div v-if="generateError" class="rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive">
            {{ generateError }}
          </div>
          <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <Button type="button" variant="outline" class="w-full sm:w-auto" @click="closeGenerateModal">{{ t('admin.common.cancel') }}</Button>
            <Button type="submit" class="w-full sm:w-auto" :disabled="generateSubmitting">
              {{ generateSubmitting ? t('admin.common.submitting') : t('admin.common.confirm') }}
            </Button>
          </div>
        </form>
      </DialogScrollContent>
    </Dialog>

    <Dialog v-model:open="showEditModal" @update:open="(value) => { if (!value) closeEditModal() }">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-xl p-4 sm:p-6" @interact-outside="(e) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ t('admin.giftCards.modal.editTitle') }}</DialogTitle>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="submitEdit">
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div class="space-y-2 md:col-span-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.giftCards.form.name') }}</label>
              <Input v-model="editForm.name" maxlength="120" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.giftCards.form.status') }}</label>
              <Select v-model="editForm.status" :disabled="editCardReadonly">
                <SelectTrigger class="h-10 w-full">
                  <SelectValue :placeholder="t('admin.giftCards.form.status')" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">{{ t('admin.giftCards.status.active') }}</SelectItem>
                  <SelectItem value="disabled">{{ t('admin.giftCards.status.disabled') }}</SelectItem>
                </SelectContent>
              </Select>
              <p v-if="editCardReadonly" class="text-xs text-muted-foreground">{{ t('admin.giftCards.form.statusReadonly') }}</p>
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.giftCards.form.expiresAt') }}</label>
              <Input v-model="editForm.expiresAt" type="datetime-local" />
              <p class="text-xs text-muted-foreground">{{ t('admin.giftCards.form.editExpiresHint') }}</p>
            </div>
          </div>

          <div v-if="editError" class="rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive">
            {{ editError }}
          </div>
          <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <Button type="button" variant="outline" class="w-full sm:w-auto" @click="closeEditModal">{{ t('admin.common.cancel') }}</Button>
            <Button type="submit" class="w-full sm:w-auto" :disabled="editSubmitting">
              {{ editSubmitting ? t('admin.common.submitting') : t('admin.common.confirm') }}
            </Button>
          </div>
        </form>
      </DialogScrollContent>
    </Dialog>
  </div>
</template>

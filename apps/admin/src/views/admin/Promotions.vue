<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import { adminAPI } from '@/api/admin'
import type { AdminPromotion, AdminProduct } from '@/api/types'
import IdCell from '@/components/IdCell.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Switch } from '@/components/ui/switch'
import { Dialog, DialogHeader, DialogScrollContent, DialogTitle } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import TableSkeleton from '@/components/TableSkeleton.vue'
import ListPagination from '@/components/ListPagination.vue'
import { useListRefresh, type ListFetchOptions } from '@/composables/useListRefresh'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { formatDate, getLocalizedText } from '@/utils/format'
import { notifyError } from '@/utils/notify'
import { confirmAction } from '@/utils/confirm'
import { useFormValidation, rules } from '@/composables/useFormValidation'

const loading = ref(true)
const { refreshing, refreshList } = useListRefresh()
const promotions = ref<AdminPromotion[]>([])
const pagination = ref({
  page: 1,
  page_size: 20,
  total: 0,
  total_page: 1,
})
const filters = reactive({
  id: '',
  name: '',
  scopeRefId: '__all__',
  isActive: '__all__',
})
const autoOpenId = ref<number | null>(null)
const normalizeFilterValue = (value: string) => (value === '__all__' ? '' : value)
const normalizeScopeFilterValue = (value: string) => (value === '__all__' ? '' : value)

const showModal = ref(false)
const submitting = ref(false)
const error = ref('')
const isEditing = ref(false)
const editingId = ref<number | null>(null)
const productKeyword = ref('')
const productOptions = ref<AdminProduct[]>([])
const productOptionsLoading = ref(false)
const modalScopeValue = ref('__none__')
const form = reactive({
  name: '',
  type: 'percent',
  scope_ref_id: 0,
  value: 0,
  min_amount: 0,
  starts_at: '',
  ends_at: '',
  is_active: true,
})
const { t } = useI18n()
const route = useRoute()

const promotionSchema = {
  name: [rules.required()],
  type: [rules.required()],
  value: [rules.required(), rules.numeric(), rules.min(0)],
}
const { errors, validate, clearErrors } = useFormValidation(promotionSchema)

const applyRouteFilter = () => {
  const rawId = route.query.id || route.query.promotion_id
  const parsed = Number(rawId)
  if (Number.isFinite(parsed) && parsed > 0) {
    filters.id = String(parsed)
    autoOpenId.value = parsed
    return
  }
  filters.id = ''
}

const discountTypeLabel = (type: string) => {
  const map: Record<string, string> = {
    percent: t('admin.common.discountTypes.percent'),
    fixed: t('admin.common.discountTypes.fixed'),
  }
  return map[type] || type
}

const promotionValueHint = computed(() => {
  switch (String(form.type || '').trim()) {
    case 'percent':
      return t('admin.promotions.modal.valueHintPercent')
    case 'fixed':
      return t('admin.promotions.modal.valueHintFixed')
    case 'special_price':
      return t('admin.promotions.modal.valueHintSpecialPrice')
    default:
      return t('admin.promotions.modal.valueHintDefault')
  }
})

const parsePriceNumber = (value: unknown) => {
  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed < 0) return null
  return parsed
}

const selectedScopeProduct = computed(() => {
  const id = Number(modalScopeValue.value)
  if (!Number.isFinite(id) || id <= 0) return null
  return productOptions.value.find((item) => Number(item?.id || 0) === Math.floor(id)) || null
})

const selectedScopeReferenceUnitPrice = computed(() => {
  const product = selectedScopeProduct.value
  if (!product) return null

  const skuPrices: number[] = []
  const skus = Array.isArray(product?.skus) ? product.skus : []
  skus.forEach((sku) => {
    if (sku?.is_active === false) return
    const amount = parsePriceNumber(sku?.price_amount)
    if (amount === null) return
    skuPrices.push(amount)
  })
  if (skuPrices.length > 0) {
    return Math.min(...skuPrices)
  }
  return parsePriceNumber(product?.price_amount)
})

const fixedDiscountRisk = computed(() => {
  if (String(form.type || '').trim() !== 'fixed') return null
  const discountValue = parsePriceNumber(form.value)
  const referencePrice = selectedScopeReferenceUnitPrice.value
  if (discountValue === null || referencePrice === null) return null
  if (discountValue < referencePrice) return null
  return {
    discountValue: discountValue.toFixed(2),
    referencePrice: referencePrice.toFixed(2),
  }
})

const resetForm = () => {
  form.name = ''
  form.type = 'percent'
  form.scope_ref_id = 0
  form.value = 0
  form.min_amount = 0
  form.starts_at = ''
  form.ends_at = ''
  form.is_active = true
  modalScopeValue.value = '__none__'
}

const toISO = (raw: string) => {
  if (!raw) return ''
  const date = new Date(raw)
  if (Number.isNaN(date.getTime())) return raw
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

const parseScopeFilterID = () => {
  const normalized = normalizeScopeFilterValue(filters.scopeRefId)
  if (!normalized) return 0
  const parsed = Number(normalized)
  if (!Number.isFinite(parsed) || parsed <= 0) return 0
  return Math.floor(parsed)
}

const buildProductLabel = (product: AdminProduct) => {
  const id = Number(product?.id || 0)
  const name = getLocalizedText(product?.title || {})
  if (id > 0 && name) return `#${id} ${name}`
  if (id > 0) return `#${id}`
  return name || '-'
}

const ensureReferencedProductsInOptions = (rows: AdminProduct[]) => {
  const ids: number[] = []
  const scopeFilterID = parseScopeFilterID()
  if (scopeFilterID > 0) ids.push(scopeFilterID)
  if (form.scope_ref_id > 0) ids.push(Math.floor(form.scope_ref_id))

  if (!ids.length) return rows
  const exists = new Set(
    rows.map((item) => Number(item?.id || 0)).filter((id: number) => Number.isFinite(id) && id > 0)
  )
  ids.forEach((id) => {
    if (exists.has(id)) return
    rows.unshift({
      id,
      title: {
        'zh-CN': `#${id}`,
        'zh-TW': `#${id}`,
        'en-US': `#${id}`,
      },
    } as unknown as AdminProduct)
    exists.add(id)
  })
  return rows
}

const loadProductOptions = async () => {
  productOptionsLoading.value = true
  try {
    const keyword = String(productKeyword.value || '').trim()
    const rows: AdminProduct[] = []
    let page = 1
    let totalPage = 1
    do {
      const response = await adminAPI.getProducts({
        page,
        page_size: 100,
        search: keyword || undefined,
      })
      const list = Array.isArray(response.data.data) ? response.data.data : []
      rows.push(...list)
      totalPage = Number(response.data?.pagination?.total_page || 1)
      page += 1
    } while (page <= totalPage && page <= 20)

    const dedup = new Map<number, AdminProduct>()
    rows.forEach((item) => {
      const id = Number(item?.id || 0)
      if (!Number.isFinite(id) || id <= 0) return
      if (!dedup.has(id)) dedup.set(id, item)
    })
    productOptions.value = ensureReferencedProductsInOptions(Array.from(dedup.values()))
  } catch {
    productOptions.value = ensureReferencedProductsInOptions([])
  } finally {
    productOptionsLoading.value = false
  }
}

const handleSearchProducts = async () => {
  await loadProductOptions()
}

const resolveProductNameByID = (rawProductID: number | string) => {
  const productID = Number(rawProductID)
  if (!Number.isFinite(productID) || productID <= 0) return ''
  const target = productOptions.value.find((item) => Number(item?.id || 0) === Math.floor(productID))
  if (!target) return ''
  return getLocalizedText(target?.title || {})
}

const formatPromotionScope = (rawScopeID: number | string) => {
  const scopeID = Number(rawScopeID || 0)
  if (!Number.isFinite(scopeID) || scopeID <= 0) return '-'
  const productName = resolveProductNameByID(scopeID)
  if (productName) return `#${Math.floor(scopeID)} ${productName}`
  return `#${Math.floor(scopeID)}`
}

const fetchPromotions = async (page = 1, options: ListFetchOptions = {}) => {
  if (!options.preserveRows) loading.value = true
  try {
    const normalizedIsActive = normalizeFilterValue(filters.isActive)
    const normalizedScope = normalizeScopeFilterValue(filters.scopeRefId)
    const isActiveValue = normalizedIsActive === '' ? undefined : normalizedIsActive === 'true'
    const response = await adminAPI.getPromotions({
      page,
      page_size: pagination.value.page_size,
      id: filters.id || undefined,
      name: filters.name.trim() || undefined,
      scope_ref_id: normalizedScope || undefined,
      is_active: isActiveValue,
    })
    promotions.value = response.data.data || []
    pagination.value = response.data.pagination || pagination.value
    if (autoOpenId.value) {
      const target = promotions.value.find((item) => item.id === autoOpenId.value)
      if (target) {
        openEditModal(target)
      }
      autoOpenId.value = null
    }
  } catch {
    if (!options.preserveRows) promotions.value = []
  } finally {
    if (!options.preserveRows) loading.value = false
  }
}

const handleSearch = () => {
  fetchPromotions(1)
}

const refresh = () => {
  refreshList(() => fetchPromotions(pagination.value.page, { preserveRows: true }))
}

const changePage = (page: number) => {
  if (page < 1 || page > pagination.value.total_page) return
  fetchPromotions(page)
}

const pageSizeOptions = [10, 20, 50, 100]

const changePageSize = (size: number) => {
  if (size === pagination.value.page_size) return
  pagination.value.page_size = size
  fetchPromotions(1)
}

const openCreateModal = () => {
  error.value = ''
  clearErrors()
  isEditing.value = false
  editingId.value = null
  resetForm()
  showModal.value = true
  void loadProductOptions()
}

const openEditModal = (promo: AdminPromotion) => {
  error.value = ''
  isEditing.value = true
  editingId.value = promo.id
  form.name = promo.name || ''
  form.type = promo.type || 'percent'
  form.scope_ref_id = promo.scope_ref_id || 0
  modalScopeValue.value = form.scope_ref_id > 0 ? String(form.scope_ref_id) : '__none__'
  form.value = promo.value || 0
  form.min_amount = promo.min_amount || 0
  form.starts_at = toLocalInput(promo.starts_at)
  form.ends_at = toLocalInput(promo.ends_at)
  form.is_active = Boolean(promo.is_active)
  showModal.value = true
  void loadProductOptions()
}

const closeModal = () => {
  showModal.value = false
  isEditing.value = false
  editingId.value = null
  clearErrors()
}

const handleSubmit = async () => {
  error.value = ''
  if (!validate({ ...form } as Record<string, unknown>)) return
  const scopeRefID = Number(modalScopeValue.value)
  if (!Number.isFinite(scopeRefID) || scopeRefID <= 0) {
    error.value = t('admin.promotions.errors.scopeRequired')
    return
  }
  form.scope_ref_id = Math.floor(scopeRefID)
  submitting.value = true
  try {
    const payload = {
      name: form.name.trim(),
      type: form.type,
      scope_ref_id: Number(form.scope_ref_id),
      value: Number(form.value),
      min_amount: Number(form.min_amount || 0),
      starts_at: form.starts_at ? toISO(form.starts_at) : '',
      ends_at: form.ends_at ? toISO(form.ends_at) : '',
      is_active: form.is_active,
    }
    if (isEditing.value && editingId.value) {
      await adminAPI.updatePromotion(editingId.value, payload)
    } else {
      await adminAPI.createPromotion(payload)
    }
    closeModal()
    fetchPromotions(1)
  } catch (err: any) {
    error.value =
      err.message ||
      (isEditing.value ? t('admin.promotions.errors.updateFailed') : t('admin.promotions.errors.createFailed'))
  } finally {
    submitting.value = false
  }
}

const handleDelete = async (promo: AdminPromotion) => {
  const confirmed = await confirmAction({ description: t('admin.promotions.confirmDelete', { name: promo.name }), confirmText: t('admin.common.delete'), variant: 'destructive' })
  if (!confirmed) return
  try {
    await adminAPI.deletePromotion(promo.id)
    fetchPromotions(pagination.value.page)
  } catch (err: any) {
    const message = err.message || t('admin.promotions.errors.deleteFailed')
    notifyError(message)
  }
}

const handleScopeFilterChange = () => {
  fetchPromotions(1)
}

const handleModalScopeChange = (value: unknown) => {
  const normalized = String(value ?? '')
  modalScopeValue.value = normalized
  const parsed = Number(normalized)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    form.scope_ref_id = 0
    return
  }
  form.scope_ref_id = Math.floor(parsed)
}

onMounted(async () => {
  applyRouteFilter()
  await loadProductOptions()
  fetchPromotions()
})

watch(
  () => route.query.id,
  () => {
    applyRouteFilter()
    fetchPromotions(1)
  }
)

watch(
  () => route.query.promotion_id,
  () => {
    applyRouteFilter()
    fetchPromotions(1)
  }
)
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <h1 class="text-2xl font-semibold">{{ t('admin.promotions.title') }}</h1>
      <Button size="sm" class="w-full gap-2 sm:w-auto" @click="openCreateModal">
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        {{ t('admin.promotions.create') }}
      </Button>
    </div>

    <div class="rounded-xl border border-border bg-card p-4 shadow-sm">
      <div class="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center">
        <div class="w-full md:w-60">
          <Input
            v-model="filters.name"
            :placeholder="t('admin.promotions.filterNamePlaceholder')"
            @keyup.enter="handleSearch"
          />
        </div>
        <div class="flex w-full flex-col gap-2 md:w-72 sm:flex-row sm:items-center">
          <Input
            v-model="productKeyword"
            :placeholder="t('admin.promotions.filterScopeSearchPlaceholder')"
            @keyup.enter="handleSearchProducts"
          />
          <Button
            size="sm"
            class="w-full sm:w-auto"
            variant="outline"
            :disabled="productOptionsLoading"
            @click="handleSearchProducts"
          >
            {{ productOptionsLoading ? t('admin.common.loading') : t('admin.promotions.filterScopeSearchAction') }}
          </Button>
        </div>
        <div class="w-full md:w-60">
          <Select v-model="filters.scopeRefId" @update:modelValue="handleScopeFilterChange">
            <SelectTrigger class="h-9 w-full">
              <SelectValue :placeholder="t('admin.promotions.filterScope')" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="__all__">{{ t('admin.promotions.filterScopeAll') }}</SelectItem>
              <SelectItem v-for="product in productOptions" :key="`promotion-filter-product-${product.id}`" :value="String(product.id)">
                {{ buildProductLabel(product) }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="w-full md:w-48">
          <Select v-model="filters.isActive" @update:modelValue="handleSearch">
            <SelectTrigger class="h-9 w-full">
            <SelectValue :placeholder="t('admin.promotions.filterStatusAll')" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="__all__">{{ t('admin.promotions.filterStatusAll') }}</SelectItem>
              <SelectItem value="true">{{ t('admin.common.enabled') }}</SelectItem>
              <SelectItem value="false">{{ t('admin.common.disabled') }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="hidden flex-1 sm:block"></div>
        <Button size="sm" class="w-full sm:w-auto" :disabled="refreshing" @click="refresh">{{ t('admin.common.refresh') }}</Button>
      </div>
    </div>

    <div class="rounded-xl border border-border bg-card overflow-x-auto">
      <Table class="min-w-[900px]">
        <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
          <TableRow>
            <TableHead class="px-6 py-3">{{ t('admin.promotions.table.id') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('admin.promotions.table.name') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('admin.promotions.table.type') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('admin.promotions.table.value') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('admin.promotions.table.scope') }}</TableHead>
            <TableHead class="min-w-[100px] px-6 py-3">{{ t('admin.promotions.table.minAmount') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('admin.promotions.table.period') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3">{{ t('admin.promotions.table.status') }}</TableHead>
            <TableHead class="min-w-[90px] px-6 py-3 text-right">{{ t('admin.promotions.table.action') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody class="divide-y divide-border">
          <TableRow v-if="loading">
            <TableCell :colspan="9" class="p-0">
              <TableSkeleton :columns="9" :rows="5" />
            </TableCell>
          </TableRow>
          <TableRow v-else-if="promotions.length === 0">
            <TableCell colspan="9" class="px-6 py-8 text-center text-muted-foreground">{{ t('admin.promotions.empty') }}</TableCell>
          </TableRow>
          <TableRow v-for="promo in promotions" :key="promo.id" class="hover:bg-muted/30">
            <TableCell class="px-6 py-4">
              <IdCell :value="promo.id" />
            </TableCell>
            <TableCell class="min-w-[90px] px-6 py-4">
              <div class="break-words font-medium text-foreground">{{ promo.name }}</div>
            </TableCell>
            <TableCell class="min-w-[90px] px-6 py-4 text-xs text-muted-foreground">{{ discountTypeLabel(promo.type) }}</TableCell>
            <TableCell class="min-w-[90px] px-6 py-4 text-foreground font-mono">{{ promo.value }}</TableCell>
            <TableCell class="min-w-[90px] px-6 py-4 text-xs text-muted-foreground">
              <div class="break-words">{{ formatPromotionScope(promo.scope_ref_id) }}</div>
            </TableCell>
            <TableCell class="min-w-[100px] px-6 py-4 text-xs text-muted-foreground">{{ promo.min_amount || '-' }}</TableCell>
            <TableCell class="min-w-[90px] px-6 py-4 text-xs text-muted-foreground">
              <div class="break-words">{{ t('admin.promotions.period.startsAt') }}：{{ formatDate(promo.starts_at) || '-' }}</div>
              <div class="break-words">{{ t('admin.promotions.period.endsAt') }}：{{ formatDate(promo.ends_at) || '-' }}</div>
            </TableCell>
            <TableCell class="min-w-[90px] px-6 py-4">
              <span
                class="inline-flex rounded-full border px-2.5 py-1 text-xs"
                :class="promo.is_active ? 'text-emerald-700 border-emerald-200 bg-emerald-50' : 'text-muted-foreground border-border bg-muted/30'"
              >
                {{ promo.is_active ? t('admin.common.enabled') : t('admin.common.disabled') }}
              </span>
            </TableCell>
            <TableCell class="min-w-[90px] px-6 py-4 text-right">
              <div class="flex items-center justify-end gap-2">
                <Button size="sm" variant="outline" @click="openEditModal(promo)">{{ t('admin.promotions.actions.edit') }}</Button>
                <Button size="sm" variant="destructive" @click="handleDelete(promo)">{{ t('admin.promotions.actions.delete') }}</Button>
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
      />
    </div>

    <Dialog v-model:open="showModal" @update:open="(value) => { if (!value) closeModal() }">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-3xl p-4 sm:p-6" @interact-outside="(e) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ isEditing ? t('admin.promotions.modal.editTitle') : t('admin.promotions.modal.title') }}</DialogTitle>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="handleSubmit">
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('admin.promotions.modal.name') }} *</label>
              <Input v-model="form.name" required :placeholder="t('admin.promotions.modal.namePlaceholder')" />
              <p v-if="errors.name" class="text-xs text-destructive mt-1">{{ errors.name }}</p>
            </div>
            <div>
              <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('admin.promotions.modal.type') }} *</label>
              <Select v-model="form.type">
                <SelectTrigger class="h-9 w-full">
                  <SelectValue :placeholder="t('admin.common.discountTypes.percent')" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="percent">{{ t('admin.common.discountTypes.percent') }}</SelectItem>
                  <SelectItem value="fixed">{{ t('admin.common.discountTypes.fixed') }}</SelectItem>
                </SelectContent>
              </Select>
              <p v-if="errors.type" class="text-xs text-destructive mt-1">{{ errors.type }}</p>
            </div>
            <div>
              <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('admin.promotions.modal.value') }} *</label>
              <Input v-model.number="form.value" type="number" step="0.01" required placeholder="10" />
              <p v-if="errors.value" class="text-xs text-destructive mt-1">{{ errors.value }}</p>
              <p class="mt-1 text-[11px] leading-5 text-muted-foreground">{{ promotionValueHint }}</p>
              <div
                v-if="fixedDiscountRisk"
                class="mt-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-[11px] leading-5 text-amber-800"
              >
                <div class="font-medium">{{ t('admin.promotions.modal.riskHintTitle') }}</div>
                <div class="mt-1">
                  {{ t('admin.promotions.modal.riskHintFixedMayZero', { value: fixedDiscountRisk.discountValue, price: fixedDiscountRisk.referencePrice }) }}
                </div>
                <div class="mt-1">{{ t('admin.promotions.modal.riskHintReferencePrice') }}</div>
              </div>
            </div>
            <div class="md:col-span-2">
              <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('admin.promotions.modal.scope') }} *</label>
              <div class="space-y-2">
                <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
                  <Input
                    v-model="productKeyword"
                    :placeholder="t('admin.promotions.modal.scopeSearchPlaceholder')"
                    @keyup.enter="handleSearchProducts"
                  />
                  <Button
                    class="w-full sm:w-auto"
                    type="button"
                    size="sm"
                    variant="outline"
                    :disabled="productOptionsLoading"
                    @click="handleSearchProducts"
                  >
                    {{ productOptionsLoading ? t('admin.common.loading') : t('admin.promotions.modal.scopeSearchAction') }}
                  </Button>
                </div>
                <Select v-model="modalScopeValue" @update:modelValue="handleModalScopeChange">
                  <SelectTrigger class="h-9 w-full">
                    <SelectValue :placeholder="t('admin.promotions.modal.scopePlaceholder')" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__none__">{{ t('admin.promotions.modal.scopePlaceholder') }}</SelectItem>
                    <SelectItem v-for="product in productOptions" :key="`promotion-modal-product-${product.id}`" :value="String(product.id)">
                      {{ buildProductLabel(product) }}
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div>
              <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('admin.promotions.modal.minAmount') }}</label>
              <Input v-model.number="form.min_amount" type="number" step="0.01" placeholder="0" />
              <p class="mt-1 text-[11px] leading-5 text-muted-foreground">{{ t('admin.promotions.modal.minAmountHint') }}</p>
            </div>
            <div>
              <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('admin.promotions.modal.startsAt') }}</label>
              <Input v-model="form.starts_at" type="datetime-local" />
            </div>
            <div>
              <label class="mb-1.5 block text-xs font-medium text-muted-foreground">{{ t('admin.promotions.modal.endsAt') }}</label>
              <Input v-model="form.ends_at" type="datetime-local" />
            </div>
            <div class="flex flex-col gap-2 md:col-span-2 sm:flex-row sm:items-center">
              <Switch v-model="form.is_active" />
              <span class="text-xs text-muted-foreground">{{ t('admin.common.enabled') }}</span>
            </div>
          </div>

          <div v-if="error" class="rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
            {{ error }}
          </div>

          <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <Button class="w-full sm:w-auto" type="button" variant="outline" @click="closeModal">{{ t('admin.common.cancel') }}</Button>
            <Button class="w-full sm:w-auto" type="submit" :disabled="submitting">{{ t('admin.common.save') }}</Button>
          </div>
        </form>
      </DialogScrollContent>
    </Dialog>
  </div>
</template>

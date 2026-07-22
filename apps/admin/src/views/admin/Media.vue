<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useDebounceFn } from '@vueuse/core'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminMedia } from '@/api/types'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import ListPagination from '@/components/ListPagination.vue'
import { getImageUrl } from '@/utils/image'
import { notifyError, notifySuccess } from '@/utils/notify'
import { confirmAction } from '@/utils/confirm'
import FileInput from '@/components/FileInput.vue'
import { DEFAULT_UPLOAD_MAX_SIZE_BYTES, formatFileSizeLimit, splitFilesBySize } from '@/utils/upload'

const { t } = useI18n()
const loading = ref(false)
const uploading = ref(false)
const uploadProgress = ref({ current: 0, total: 0 })
const batchMode = ref(false)
const batchOperating = ref(false)
const selectedIds = ref<Set<number>>(new Set())

const items = ref<AdminMedia[]>([])
const pagination = reactive({
  page: 1,
  page_size: 24,
  total: 0,
  total_page: 0,
})
const filters = reactive({
  search: '',
  scene: '__all__',
})

const allSelected = computed(() => items.value.length > 0 && items.value.every((item) => selectedIds.value.has(item.id)))

// Inline rename state
const editingId = ref<number | null>(null)
const editingName = ref('')

const sceneOptions = [
  { label: () => t('admin.media.filters.sceneAll'), value: '__all__' },
  { label: () => t('admin.media.scenes.product'), value: 'product' },
  { label: () => t('admin.media.scenes.banner'), value: 'banner' },
  { label: () => t('admin.media.scenes.category'), value: 'category' },
  { label: () => t('admin.media.scenes.post'), value: 'post' },
  { label: () => t('admin.media.scenes.editor'), value: 'editor' },
  { label: () => t('admin.media.scenes.common'), value: 'common' },
  { label: () => t('admin.media.scenes.telegram'), value: 'telegram' },
  { label: () => t('admin.media.scenes.upstream'), value: 'upstream' },
]

async function fetchMedia(page = 1) {
  loading.value = true
  try {
    const params: Record<string, unknown> = {
      page,
      page_size: pagination.page_size,
    }
    if (filters.search) params.search = filters.search
    if (filters.scene !== '__all__') params.scene = filters.scene

    const res = await adminAPI.getMedia(params)
    items.value = (res.data.data as any)?.items || []
    const visibleIds = new Set(items.value.map((item) => item.id))
    selectedIds.value = new Set(Array.from(selectedIds.value).filter((id) => visibleIds.has(id)))
    const total = (res.data.data as any)?.total || 0
    pagination.total = total
    pagination.page = page
    pagination.total_page = Math.ceil(total / pagination.page_size)
  } catch {
    // silent on fetch error
  } finally {
    loading.value = false
  }
}

function clearSelection() {
  selectedIds.value = new Set()
}

function toggleBatchMode() {
  batchMode.value = !batchMode.value
  editingId.value = null
  if (!batchMode.value) {
    clearSelection()
  }
}

function toggleSelect(id: number) {
  const next = new Set(selectedIds.value)
  if (next.has(id)) {
    next.delete(id)
  } else {
    next.add(id)
  }
  selectedIds.value = next
}

function toggleSelectAll() {
  selectedIds.value = allSelected.value
    ? new Set()
    : new Set(items.value.map((item) => item.id))
}

function changePage(page: number) {
  if (page < 1 || page > pagination.total_page) return
  fetchMedia(page)
}

const pageSizeOptions = [10, 20, 50, 100]

function changePageSize(size: number) {
  if (size === pagination.page_size) return
  pagination.page_size = size
  fetchMedia(1)
}

const debouncedFetch = useDebounceFn(() => fetchMedia(1), 300)
watch(() => filters.search, debouncedFetch)
watch(() => filters.scene, () => fetchMedia(1))

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
}

// Upload
async function handleFileChange(files: FileList | null) {
  if (!files || files.length === 0) return
  const { accepted: fileList, rejected } = splitFilesBySize(Array.from(files))
  if (rejected.length > 0) {
    notifyError(t('admin.media.errors.fileTooLarge', {
      count: rejected.length,
      max: formatFileSizeLimit(DEFAULT_UPLOAD_MAX_SIZE_BYTES),
    }))
  }
  if (fileList.length === 0) return

  uploading.value = true
  const total = fileList.length
  uploadProgress.value = { current: 0, total }
  let failCount = 0

  for (let i = 0; i < fileList.length; i += 3) {
    const batch = fileList.slice(i, i + 3)
    await Promise.allSettled(batch.map(async (file) => {
      const formData = new FormData()
      formData.append('file', file)
      try {
        await adminAPI.upload(formData, 'common')
      } catch {
        failCount++
      } finally {
        uploadProgress.value.current++
      }
    }))
  }

  if (failCount > 0) {
    notifyError(failCount === total
      ? t('admin.media.errors.uploadFailed', { message: `${total}` })
      : t('admin.media.errors.uploadPartialFailed', { fail: failCount, total }))
  }
  fetchMedia(1)
  uploading.value = false
}

// Inline rename
function startRename(item: AdminMedia) {
  editingId.value = item.id
  editingName.value = item.name
}

async function saveRename(item: AdminMedia) {
  const name = editingName.value.trim()
  if (!name || name === item.name) {
    editingId.value = null
    return
  }
  try {
    await adminAPI.updateMedia(item.id, { name })
    item.name = name
    notifySuccess(t('admin.media.card.renameSaved'))
  } catch (err: any) {
    notifyError(t('admin.media.errors.renameFailed', { message: err?.message || '' }))
  } finally {
    editingId.value = null
  }
}

function handleRenameKeydown(e: KeyboardEvent, item: AdminMedia) {
  if (e.key === 'Enter') {
    e.preventDefault()
    saveRename(item)
  } else if (e.key === 'Escape') {
    editingId.value = null
  }
}

// Delete
async function handleDelete(item: AdminMedia) {
  const confirmed = await confirmAction({
    title: t('admin.media.confirmDelete', { name: item.name }),
    description: t('admin.media.deleteWarning'),
  })
  if (!confirmed) return
  try {
    await adminAPI.deleteMedia(item.id)
    fetchMedia(pagination.page)
  } catch (err: any) {
    notifyError(t('admin.media.errors.deleteFailed', { message: err?.message || '' }))
  }
}

async function handleBatchDelete() {
  const ids = Array.from(selectedIds.value)
  if (ids.length === 0) return
  const confirmed = await confirmAction({
    description: t('admin.media.batch.deleteConfirm', { count: ids.length }),
    confirmText: t('admin.common.delete'),
    variant: 'destructive',
  })
  if (!confirmed) return

  batchOperating.value = true
  try {
    const res = await adminAPI.batchDeleteMedia(ids)
    const data = res.data.data as { success_count?: number } | null
    const successCount = data?.success_count || 0
    notifySuccess(t('admin.media.batch.deleteResult', { success: successCount, total: ids.length }))
    clearSelection()
    const nextPage = items.value.length <= successCount && pagination.page > 1 ? pagination.page - 1 : pagination.page
    await fetchMedia(nextPage)
  } catch (err: any) {
    notifyError(t('admin.media.errors.deleteFailed', { message: err?.message || '' }))
  } finally {
    batchOperating.value = false
  }
}

onMounted(() => fetchMedia(1))
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-4">
      <h1 class="text-2xl font-bold">{{ t('admin.media.title') }}</h1>
      <div class="flex flex-wrap items-center gap-2">
        <Button size="sm" :variant="batchMode ? 'secondary' : 'outline'" :disabled="loading || uploading" @click="toggleBatchMode">
          {{ batchMode ? t('admin.media.batch.exit') : t('admin.media.batch.mode') }}
        </Button>
        <FileInput
          accept="image/*"
          :multiple="true"
          :disabled="uploading"
          :button-text="uploading ? t('admin.media.uploadProgress', uploadProgress) : t('admin.media.uploadNew')"
          @change="handleFileChange"
        />
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap items-center gap-3">
      <Input
        v-model="filters.search"
        :placeholder="t('admin.media.searchPlaceholder')"
        class="w-64"
      />
      <Select v-model="filters.scene">
        <SelectTrigger class="w-40">
          <SelectValue :placeholder="t('admin.media.filters.scenePlaceholder')" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem v-for="opt in sceneOptions" :key="opt.value" :value="opt.value">
            {{ opt.label() }}
          </SelectItem>
        </SelectContent>
      </Select>
    </div>

    <div v-if="batchMode" class="flex flex-wrap items-center gap-3 rounded-lg border border-primary/20 bg-primary/5 px-4 py-3">
      <span class="text-sm font-medium">{{ t('admin.media.batch.selected', { count: selectedIds.size }) }}</span>
      <Button size="sm" variant="outline" :disabled="items.length === 0 || batchOperating" @click="toggleSelectAll">
        {{ allSelected ? t('admin.media.batch.deselectPage') : t('admin.media.batch.selectPage') }}
      </Button>
      <Button size="sm" variant="destructive" :disabled="selectedIds.size === 0 || batchOperating" @click="handleBatchDelete">
        {{ t('admin.media.batch.delete') }}
      </Button>
      <button class="ml-auto text-xs text-muted-foreground hover:text-foreground" :disabled="batchOperating" @click="clearSelection">
        {{ t('admin.media.batch.clearSelection') }}
      </button>
    </div>

    <!-- Grid -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <div class="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent"></div>
    </div>
    <div v-else-if="items.length === 0" class="flex flex-col items-center justify-center py-20 text-muted-foreground">
      <p>{{ t('admin.media.empty') }}</p>
    </div>
    <div v-else class="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6">
      <div
        v-for="item in items"
        :key="item.id"
        class="group relative overflow-hidden rounded-lg border bg-card transition-colors"
        :class="selectedIds.has(item.id) ? 'border-primary ring-2 ring-primary/20' : 'border-border'"
      >
        <!-- Thumbnail -->
        <div class="relative aspect-square overflow-hidden bg-muted">
          <img
            :src="getImageUrl(item.path)"
            :alt="item.name"
            class="h-full w-full object-contain"
            loading="lazy"
          />
          <button
            v-if="batchMode"
            type="button"
            class="absolute inset-0 z-10 cursor-pointer"
            :aria-label="t('admin.media.batch.toggleItem', { name: item.name })"
            :aria-pressed="selectedIds.has(item.id)"
            @click="toggleSelect(item.id)"
          ></button>
          <div v-if="batchMode" class="absolute left-2 top-2 z-20 rounded bg-background/90 p-1 shadow-sm">
            <Checkbox :model-value="selectedIds.has(item.id)" @update:model-value="() => toggleSelect(item.id)" />
          </div>
          <!-- Hover overlay with delete -->
          <div v-if="!batchMode" class="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 transition-opacity group-hover:opacity-100">
            <Button size="sm" variant="destructive" @click="handleDelete(item)">
              {{ t('admin.common.delete') }}
            </Button>
          </div>
        </div>
        <!-- Info -->
        <div class="space-y-1 p-2">
          <!-- Editable name -->
          <div v-if="editingId === item.id" class="flex">
            <Input
              v-model="editingName"
              class="h-7 text-xs"
              autofocus
              @blur="saveRename(item)"
              @keydown="handleRenameKeydown($event, item)"
            />
          </div>
          <p
            v-else
            class="cursor-pointer truncate text-xs font-medium hover:text-primary"
            :title="t('admin.media.card.editName')"
            @click="startRename(item)"
          >
            {{ item.name }}
          </p>
          <p class="truncate text-[10px] text-muted-foreground">
            {{ formatFileSize(item.size) }}
            <span v-if="item.width && item.height"> &middot; {{ item.width }} x {{ item.height }}</span>
          </p>
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
  </div>
</template>

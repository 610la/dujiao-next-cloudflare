<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useDebounceFn } from '@vueuse/core'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminMedia } from '@/api/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { getImageUrl } from '@/utils/image'
import { notifyError } from '@/utils/notify'
import { DEFAULT_UPLOAD_MAX_SIZE_BYTES, formatFileSizeLimit, splitFilesBySize } from '@/utils/upload'

const props = withDefaults(defineProps<{
  modelValue?: string | string[]
  multiple?: boolean
  scene?: string
  dialogOnly?: boolean
}>(), {
  modelValue: '',
  multiple: false,
  scene: 'common',
  dialogOnly: false,
})

const emit = defineEmits<{
  'update:modelValue': [value: string | string[]]
}>()

const { t } = useI18n()
const open = ref(false)
const activeTab = ref<'library' | 'upload'>('library')
const uploading = ref(false)
const uploadProgress = ref({ current: 0, total: 0 })
const loading = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)
const dialogFileInput = ref<HTMLInputElement | null>(null)
const isDragOver = ref(false)
const isDialogDragOver = ref(false)

const mediaItems = ref<AdminMedia[]>([])
const search = ref('')
const selected = ref<Set<string>>(new Set())

const pagination = reactive({
  page: 1,
  page_size: 18,
  total: 0,
  total_page: 0,
})

const currentImages = computed(() => {
  if (!props.modelValue) return []
  return Array.isArray(props.modelValue) ? props.modelValue.filter(Boolean) : [props.modelValue].filter(Boolean)
})

const hasImage = computed(() => currentImages.value.length > 0)

function filterFilesByUploadSize(files: File[]) {
  const { accepted, rejected } = splitFilesBySize(files)
  if (rejected.length > 0) {
    notifyError(t('admin.media.errors.fileTooLarge', {
      count: rejected.length,
      max: formatFileSizeLimit(DEFAULT_UPLOAD_MAX_SIZE_BYTES),
    }))
  }
  return accepted
}

// ── Fetch ──
async function fetchMedia(page = 1) {
  loading.value = true
  try {
    const params: Record<string, unknown> = {
      page,
      page_size: pagination.page_size,
    }
    if (search.value) params.search = search.value
    const res = await adminAPI.getMedia(params)
    mediaItems.value = (res.data.data as any)?.items || []
    const total = (res.data.data as any)?.total || 0
    pagination.total = total
    pagination.page = page
    pagination.total_page = Math.ceil(total / pagination.page_size)
  } catch {
    // silent
  } finally {
    loading.value = false
  }
}

const debouncedFetch = useDebounceFn(() => fetchMedia(1), 300)
watch(search, debouncedFetch)

// ── Selection ──
function toggleSelect(path: string) {
  if (props.multiple) {
    const s = new Set(selected.value)
    if (s.has(path)) s.delete(path)
    else s.add(path)
    selected.value = s
  } else {
    selected.value = new Set([path])
  }
}

function isSelected(path: string) {
  return selected.value.has(path)
}

function confirmSelection() {
  const paths = Array.from(selected.value)
  if (props.multiple) {
    emit('update:modelValue', paths)
  } else {
    emit('update:modelValue', paths[0] || '')
  }
  open.value = false
}

// ── Dialog upload ──
function triggerDialogUpload() {
  dialogFileInput.value?.click()
}

function handleDialogDrop(e: DragEvent) {
  isDialogDragOver.value = false
  const files = e.dataTransfer?.files
  if (files && files.length > 0 && dialogFileInput.value) {
    const dt = new DataTransfer()
    Array.from(files).forEach(f => dt.items.add(f))
    dialogFileInput.value.files = dt.files
    handleDialogUpload({ target: dialogFileInput.value } as any)
  }
}

async function handleDialogUpload(e: Event) {
  const files = (e.target as HTMLInputElement).files
  if (!files || files.length === 0) return
  const fileList = filterFilesByUploadSize(Array.from(files))
  if (fileList.length === 0) {
    if (dialogFileInput.value) dialogFileInput.value.value = ''
    return
  }

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
        const res = await adminAPI.upload(formData, props.scene)
        const url = (res.data.data as any)?.url
        if (url) {
          if (props.multiple) {
            selected.value.add(url)
          } else {
            selected.value = new Set([url])
          }
        }
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
  activeTab.value = 'library'
  await fetchMedia(1)
  uploading.value = false
  if (dialogFileInput.value) dialogFileInput.value.value = ''
}

// ── Trigger area: direct upload via drag/click ──
function triggerDirectUpload() {
  fileInput.value?.click()
}

function handleTriggerDrop(e: DragEvent) {
  isDragOver.value = false
  const files = e.dataTransfer?.files
  if (!files || files.length === 0) return
  const imageFiles = Array.from(files).filter(f => f.type.startsWith('image/'))
  if (imageFiles.length > 0) {
    doDirectUpload(imageFiles)
  }
}

async function handleDirectUpload(e: Event) {
  const files = (e.target as HTMLInputElement).files
  if (!files || files.length === 0) return
  doDirectUpload(Array.from(files))
}

async function doDirectUpload(files: File[]) {
  const fileList = filterFilesByUploadSize(files)
  if (fileList.length === 0) {
    if (fileInput.value) fileInput.value.value = ''
    return
  }

  uploading.value = true
  uploadProgress.value = { current: 0, total: fileList.length }
  let failCount = 0
  const uploadedUrls: string[] = []

  for (let i = 0; i < fileList.length; i += 3) {
    const batch = fileList.slice(i, i + 3)
    await Promise.allSettled(batch.map(async (file) => {
      const formData = new FormData()
      formData.append('file', file)
      try {
        const res = await adminAPI.upload(formData, props.scene)
        const url = (res.data.data as any)?.url
        if (url) uploadedUrls.push(url)
      } catch {
        failCount++
      } finally {
        uploadProgress.value.current++
      }
    }))
  }

  if (uploadedUrls.length > 0) {
    if (props.multiple) {
      const current = Array.isArray(props.modelValue) ? [...props.modelValue] : []
      emit('update:modelValue', [...current, ...uploadedUrls])
    } else {
      emit('update:modelValue', uploadedUrls[uploadedUrls.length - 1]!)
    }
  }
  if (failCount > 0) {
    notifyError(failCount === fileList.length
      ? t('admin.media.errors.uploadFailed', { message: `${fileList.length}` })
      : t('admin.media.errors.uploadPartialFailed', { fail: failCount, total: fileList.length }))
  }
  uploading.value = false
  if (fileInput.value) fileInput.value.value = ''
}

// ── Remove single image (for multiple mode) ──
function removeImage(path: string) {
  if (props.multiple) {
    const current = Array.isArray(props.modelValue) ? props.modelValue.filter(p => p !== path) : []
    emit('update:modelValue', current)
  } else {
    emit('update:modelValue', '')
  }
}

// ── Open dialog ──
function openPicker() {
  selected.value = new Set(currentImages.value)
  activeTab.value = 'library'
  search.value = ''
  open.value = true
  fetchMedia(1)
}

function changePage(page: number) {
  if (page < 1 || page > pagination.total_page) return
  fetchMedia(page)
}

defineExpose({ openPicker })
</script>

<template>
  <!-- ═══ Trigger Area ═══ -->
  <div
    v-if="!dialogOnly"
    class="relative rounded-xl border-2 border-dashed transition-colors"
    :class="[
      isDragOver ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/40',
      uploading ? 'pointer-events-none' : 'cursor-pointer',
    ]"
    @click="hasImage ? undefined : triggerDirectUpload()"
    @drop.prevent="handleTriggerDrop"
    @dragover.prevent="isDragOver = true"
    @dragleave="isDragOver = false"
  >
    <input ref="fileInput" type="file" class="hidden" accept="image/*" :multiple="multiple" @change="handleDirectUpload" />

    <!-- Has image(s) -->
    <div v-if="hasImage" class="p-4">
      <div class="flex flex-wrap gap-3">
        <div
          v-for="img in currentImages"
          :key="img"
          class="group relative overflow-hidden rounded-lg border border-border bg-muted"
          :class="multiple ? 'h-24 w-24' : 'h-36 w-full max-w-xs'"
        >
          <img :src="getImageUrl(img)" class="h-full w-full object-contain" />
          <!-- Hover overlay -->
          <div class="absolute inset-0 flex flex-col items-center justify-center gap-1.5 bg-black/50 opacity-0 transition-opacity group-hover:opacity-100">
            <button
              type="button"
              class="w-[calc(100%-12px)] truncate rounded-md bg-white/90 px-2 py-1 text-[11px] font-medium text-foreground shadow-sm hover:bg-white"
              @click.stop="openPicker"
            >
              {{ t('admin.mediaPicker.changeImage') }}
            </button>
            <button
              type="button"
              class="rounded-md bg-destructive/90 px-2.5 py-1 text-[11px] font-medium text-destructive-foreground shadow-sm hover:bg-destructive"
              @click.stop="removeImage(img)"
            >
              &times;
            </button>
          </div>
        </div>
        <!-- Add more (multiple mode) -->
        <button
          v-if="multiple"
          type="button"
          class="flex h-24 w-24 items-center justify-center rounded-lg border-2 border-dashed border-border text-muted-foreground transition-colors hover:border-primary/40 hover:text-primary"
          @click.stop="triggerDirectUpload"
        >
          <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
        </button>
      </div>
      <!-- Action bar -->
      <div class="mt-3 flex items-center gap-2 border-t border-border pt-3">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-md border border-border bg-background px-3 py-1.5 text-xs font-medium text-foreground shadow-sm transition-colors hover:bg-accent"
          @click.stop="openPicker"
        >
          <svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z" /></svg>
          {{ t('admin.mediaPicker.selectFromLibrary') }}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 text-xs text-muted-foreground transition-colors hover:text-foreground"
          @click.stop="triggerDirectUpload"
        >
          <svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" /></svg>
          {{ t('admin.mediaPicker.orUploadNew') }}
        </button>
      </div>
    </div>

    <!-- Empty state -->
    <div v-else class="flex flex-col items-center justify-center py-8 text-center">
      <div class="mb-3 rounded-full bg-muted p-3">
        <svg class="h-6 w-6 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z" /></svg>
      </div>
      <p class="text-sm text-muted-foreground">{{ t('admin.mediaPicker.uploadHint') }}</p>
      <div class="mt-3 flex items-center gap-2">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-md border border-border bg-background px-3 py-1.5 text-xs font-medium text-foreground shadow-sm transition-colors hover:bg-accent"
          @click.stop="openPicker"
        >
          {{ t('admin.mediaPicker.selectFromLibrary') }}
        </button>
      </div>
    </div>

    <!-- Upload overlay -->
    <div v-if="uploading" class="absolute inset-0 flex items-center justify-center rounded-xl bg-background/80">
      <div class="h-6 w-6 animate-spin rounded-full border-2 border-primary/30 border-t-primary"></div>
    </div>
  </div>

  <!-- ═══ Picker Dialog ═══ -->
  <Dialog v-model:open="open">
    <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-5xl p-0" @interact-outside="(e: Event) => e.preventDefault()">
      <div class="px-6 pt-6">
        <DialogHeader>
          <DialogTitle class="text-lg">{{ t('admin.mediaPicker.title') }}</DialogTitle>
        </DialogHeader>

        <!-- Tabs -->
        <div class="mt-4 flex gap-1 border-b border-border">
          <button
            type="button"
            class="-mb-px border-b-2 px-4 py-2.5 text-sm font-medium transition-colors"
            :class="activeTab === 'library' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground'"
            @click="activeTab = 'library'"
          >
            {{ t('admin.mediaPicker.tabLibrary') }}
          </button>
          <button
            type="button"
            class="-mb-px border-b-2 px-4 py-2.5 text-sm font-medium transition-colors"
            :class="activeTab === 'upload' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground'"
            @click="activeTab = 'upload'"
          >
            {{ t('admin.mediaPicker.tabUpload') }}
          </button>
        </div>
      </div>

      <!-- Library tab -->
      <div v-if="activeTab === 'library'" class="px-6 py-4">
        <Input
          v-model="search"
          :placeholder="t('admin.mediaPicker.searchPlaceholder')"
          class="mb-4 w-full sm:w-72"
        />

        <div v-if="loading" class="flex items-center justify-center py-16">
          <div class="h-7 w-7 animate-spin rounded-full border-2 border-primary border-t-transparent"></div>
        </div>
        <div v-else-if="mediaItems.length === 0" class="flex flex-col items-center justify-center py-16 text-muted-foreground">
          <svg class="mb-3 h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z" /></svg>
          <p class="text-sm">{{ t('admin.mediaPicker.empty') }}</p>
        </div>
        <div v-else class="grid grid-cols-3 gap-2.5 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6">
          <div
            v-for="item in mediaItems"
            :key="item.id"
            class="group cursor-pointer overflow-hidden rounded-lg border-2 transition-all"
            :class="isSelected(item.path) ? 'border-primary shadow-sm shadow-primary/20' : 'border-transparent hover:border-primary/30'"
            @click="toggleSelect(item.path)"
          >
            <div class="relative aspect-square overflow-hidden bg-muted">
              <img :src="getImageUrl(item.path)" :alt="item.name" class="h-full w-full object-contain transition-transform group-hover:scale-105" loading="lazy" />
              <!-- Check badge -->
              <Transition name="check">
                <div v-if="isSelected(item.path)" class="absolute right-1.5 top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-primary text-[10px] text-primary-foreground shadow">
                  &#10003;
                </div>
              </Transition>
            </div>
            <div class="px-2 py-1.5">
              <p class="truncate text-xs font-medium leading-tight" :title="item.name">{{ item.name }}</p>
              <p v-if="item.width && item.height" class="mt-0.5 text-[10px] text-muted-foreground">{{ item.width }}&times;{{ item.height }}</p>
            </div>
          </div>
        </div>

        <!-- Pagination -->
        <div v-if="pagination.total_page > 1" class="mt-4 flex items-center justify-center gap-2 border-t border-border pt-4">
          <Button variant="outline" size="sm" class="h-7" :disabled="pagination.page <= 1" @click="changePage(pagination.page - 1)">
            {{ t('admin.common.prevPage') }}
          </Button>
          <span class="min-w-[4rem] text-center text-xs text-muted-foreground">{{ pagination.page }} / {{ pagination.total_page }}</span>
          <Button variant="outline" size="sm" class="h-7" :disabled="pagination.page >= pagination.total_page" @click="changePage(pagination.page + 1)">
            {{ t('admin.common.nextPage') }}
          </Button>
        </div>
      </div>

      <!-- Upload tab -->
      <div v-if="activeTab === 'upload'" class="px-6 py-4">
        <div
          class="flex cursor-pointer flex-col items-center justify-center rounded-xl border-2 border-dashed py-20 transition-colors"
          :class="isDialogDragOver ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/40'"
          @click="triggerDialogUpload"
          @drop.prevent="handleDialogDrop"
          @dragover.prevent="isDialogDragOver = true"
          @dragleave="isDialogDragOver = false"
        >
          <div class="mb-4 rounded-full bg-muted p-4">
            <svg class="h-8 w-8 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" /></svg>
          </div>
          <p class="text-sm font-medium text-foreground">{{ t('admin.mediaPicker.uploadHint') }}</p>
          <p class="mt-1 text-xs text-muted-foreground">PNG, JPG, GIF, WebP, SVG</p>
          <div v-if="uploading" class="mt-4 flex items-center gap-2">
            <div class="h-5 w-5 animate-spin rounded-full border-2 border-primary border-t-transparent"></div>
            <span v-if="uploadProgress.total > 1" class="text-xs text-muted-foreground">{{ t('admin.media.uploadProgress', uploadProgress) }}</span>
          </div>
        </div>
        <input ref="dialogFileInput" type="file" class="hidden" accept="image/*" :multiple="multiple" @change="handleDialogUpload" />
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-between border-t border-border px-6 py-4">
        <span class="text-sm text-muted-foreground">
          <template v-if="selected.size > 0">{{ t('admin.mediaPicker.selected', { count: selected.size }) }}</template>
        </span>
        <div class="flex gap-2">
          <Button variant="outline" size="sm" @click="open = false">{{ t('admin.mediaPicker.cancel') }}</Button>
          <Button size="sm" :disabled="selected.size === 0" @click="confirmSelection">{{ t('admin.mediaPicker.confirm') }}</Button>
        </div>
      </div>
    </DialogScrollContent>
  </Dialog>
</template>

<style scoped>
.check-enter-active,
.check-leave-active {
  transition: all 0.15s ease;
}
.check-enter-from,
.check-leave-to {
  opacity: 0;
  transform: scale(0.5);
}
</style>

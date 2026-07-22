<script setup lang="ts">
import { computed, ref, reactive, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminCategory, LocalizedText } from '@/api/types'
import IdCell from '@/components/IdCell.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import TableSkeleton from '@/components/TableSkeleton.vue'
import MediaPicker from '@/components/admin/MediaPicker.vue'
import { getLocalizedText } from '@/utils/format'
import { getImageUrl } from '@/utils/image'
import { notifyError, notifySuccess } from '@/utils/notify'
import { confirmAction } from '@/utils/confirm'
import { buildAdminCategoryPath, createAdminCategoryMap, flattenAdminCategories } from '@/utils/category'
import { useFormValidation, rules } from '@/composables/useFormValidation'

const { t } = useI18n()
const loading = ref(false)
const showModal = ref(false)
const isEditing = ref(false)
const categories = ref<AdminCategory[]>([])
const currentLang = ref('zh-CN')
const route = useRoute()
const submitting = ref(false)

const languages = computed(() => [
  { code: 'zh-CN', name: t('admin.common.lang.zhCN') },
  { code: 'zh-TW', name: t('admin.common.lang.zhTW') },
  { code: 'en-US', name: t('admin.common.lang.enUS') },
])

const form = reactive({
  id: 0,
  parent_id: 0,
  name: { 'zh-CN': '', 'zh-TW': '', 'en-US': '' } as LocalizedText,
  slug: '',
  icon: '',
  sort_order: 0,
})

const categoryMap = computed(() => createAdminCategoryMap(categories.value))
const categoryHierarchyItems = computed(() => flattenAdminCategories(categories.value))

const hasChildren = (categoryId: number) => categories.value.some((item) => item.parent_id === categoryId)

const canChooseParent = computed(() => {
  if (!isEditing.value || form.id <= 0) return true
  const current = categoryMap.value.get(form.id)
  if (!current) return true
  if (current.parent_id > 0) return true
  return !hasChildren(current.id)
})

const parentCategoryOptions = computed(() => {
  const roots = categoryHierarchyItems.value
    .filter((item) => item.depth === 0 && item.category.id !== form.id)
    .map((item) => item.category)

  if (!canChooseParent.value) {
    return []
  }

  return roots
})

const getCategoryLevelText = (category: AdminCategory) => {
  return category.parent_id > 0 ? t('admin.categories.level.child') : t('admin.categories.level.root')
}

const getCategoryPath = (category: AdminCategory) => {
  return buildAdminCategoryPath(category, categoryMap.value, (item) => getLocalizedText(item.name))
}

const { errors, validate, clearErrors } = useFormValidation({
  slug: [rules.required('This field is required')],
  name: [rules.required('This field is required')],
})

const getCurrentLangName = () => {
  return languages.value.find((item) => item.code === currentLang.value)?.name || t('admin.common.lang.zhCN')
}

const fetchCategories = async () => {
  loading.value = true
  try {
    const res = await adminAPI.getCategories()
    categories.value = res.data.data || []
  } catch (err) {
    categories.value = []
  } finally {
    loading.value = false
  }
}

const openCreateModal = () => {
  isEditing.value = false
  currentLang.value = 'zh-CN'
  clearErrors()
  Object.assign(form, {
    id: 0,
    parent_id: 0,
    name: { 'zh-CN': '', 'zh-TW': '', 'en-US': '' },
    slug: '',
    icon: '',
    sort_order: 0,
  })
  showModal.value = true
}

const openEditModal = (category: AdminCategory) => {
  isEditing.value = true
  currentLang.value = 'zh-CN'

  const defaultName = { 'zh-CN': '', 'zh-TW': '', 'en-US': '' }
  const name = { ...defaultName, ...(category.name || {}) }

  Object.assign(form, {
    id: category.id,
    parent_id: category.parent_id || 0,
    name,
    slug: category.slug,
    icon: category.icon || '',
    sort_order: category.sort_order,
  })
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  clearErrors()
}

const handleSubmit = async () => {
  if (!validate({ slug: form.slug, name: form.name['zh-CN'] } as Record<string, unknown>)) return
  submitting.value = true
  try {
    const payload = { ...form }
    if (isEditing.value) {
      await adminAPI.updateCategory(form.id, payload)
    } else {
      await adminAPI.createCategory(payload)
    }
    closeModal()
    fetchCategories()
  } catch (err: any) {
    notifyError(t('admin.categories.errors.operationFailed', { message: err?.message || '' }))
  } finally {
    submitting.value = false
  }
}

const toggleActive = async (category: AdminCategory) => {
  const newStatus = !category.is_active
  try {
    category.is_active = newStatus
    await adminAPI.patchCategoryActive(category.id, newStatus)
    notifySuccess(newStatus ? t('admin.categories.status.activatedTip') : t('admin.categories.status.deactivatedTip'))
  } catch (err: any) {
    category.is_active = !newStatus
    notifyError(t('admin.categories.errors.toggleFailed', { message: err?.message || '' }))
  }
}

const handleDelete = async (category: AdminCategory) => {
  const confirmed = await confirmAction({ description: t('admin.categories.confirmDelete', { name: getLocalizedText(category.name) }), confirmText: t('admin.common.delete'), variant: 'destructive' })
  if (!confirmed) return
  try {
    await adminAPI.deleteCategory(category.id)
    fetchCategories()
  } catch (err: any) {
    notifyError(t('admin.categories.errors.deleteFailed', { message: err?.message || '' }))
  }
}

const openEditById = async (rawId: unknown) => {
  const id = Number(rawId)
  if (!Number.isFinite(id) || id <= 0) return
  if (!categories.value.length) {
    await fetchCategories()
  }
  const target = categories.value.find((item) => item.id === id)
  if (target) {
    openEditModal(target)
  }
}

onMounted(() => {
  fetchCategories()
  if (route.query.category_id) {
    openEditById(route.query.category_id)
  }
})

watch(
  () => route.query.category_id,
  (value) => {
    if (value) {
      openEditById(value)
    }
  }
)
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <h1 class="text-2xl font-semibold">{{ t('admin.categories.title') }}</h1>
      <Button class="w-full sm:w-auto" @click="openCreateModal">{{ t('admin.categories.create') }}</Button>
    </div>

    <div class="rounded-xl border border-border bg-card overflow-x-auto">
      <Table class="min-w-[760px]">
        <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
          <TableRow>
            <TableHead class="px-6 py-3">{{ t('admin.categories.table.id') }}</TableHead>
            <TableHead class="px-6 py-3">{{ t('admin.categories.table.icon') }}</TableHead>
            <TableHead class="px-6 py-3 min-w-[260px]">{{ t('admin.categories.table.name') }}</TableHead>
            <TableHead class="px-6 py-3 min-w-[220px]">{{ t('admin.categories.table.slug') }}</TableHead>
            <TableHead class="px-6 py-3">{{ t('admin.categories.table.sort') }}</TableHead>
            <TableHead class="px-6 py-3">{{ t('admin.categories.table.status') }}</TableHead>
            <TableHead class="px-6 py-3 min-w-[140px] text-right">{{ t('admin.categories.table.action') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody class="divide-y divide-border">
          <TableRow v-if="loading">
            <TableCell :colspan="7" class="p-0">
              <TableSkeleton :columns="7" :rows="5" />
            </TableCell>
          </TableRow>
          <TableRow v-else-if="categories.length === 0">
            <TableCell colspan="7" class="px-6 py-8 text-center text-muted-foreground">{{ t('admin.categories.empty') }}</TableCell>
          </TableRow>
          <TableRow v-for="item in categoryHierarchyItems" :key="item.category.id" class="hover:bg-muted/30">
            <TableCell class="px-6 py-4">
              <IdCell :value="item.category.id" />
            </TableCell>
            <TableCell class="px-6 py-4">
              <img v-if="item.category.icon" :src="getImageUrl(item.category.icon)" class="h-8 w-8 shrink-0 rounded object-cover" :alt="getLocalizedText(item.category.name)" />
              <span v-else class="text-xs text-muted-foreground">-</span>
            </TableCell>
            <TableCell class="min-w-[260px] px-6 py-4">
              <div class="space-y-1" :class="item.depth > 0 ? 'pl-6' : ''">
                <div class="flex items-start gap-2">
                  <span
                    class="inline-flex shrink-0 rounded-full border px-2 py-0.5 text-[11px]"
                    :class="item.depth > 0 ? 'border-sky-200 bg-sky-50 text-sky-700' : 'border-border bg-muted/30 text-muted-foreground'"
                  >
                    {{ getCategoryLevelText(item.category) }}
                  </span>
                  <span class="min-w-0 break-words font-medium text-foreground">{{ getLocalizedText(item.category.name) }}</span>
                </div>
                <div v-if="item.parent" class="text-xs text-muted-foreground break-words">
                  {{ t('admin.categories.table.parentPrefix', { name: getLocalizedText(item.parent.name) }) }}
                </div>
              </div>
            </TableCell>
            <TableCell class="min-w-[220px] px-6 py-4 font-mono text-muted-foreground break-all">{{ item.category.slug }}</TableCell>
            <TableCell class="px-6 py-4 font-mono text-muted-foreground">{{ item.category.sort_order }}</TableCell>
            <TableCell class="px-6 py-4">
              <span
                class="inline-flex cursor-pointer rounded-full border px-2.5 py-1 text-xs transition-colors"
                :class="item.category.is_active ? 'text-emerald-700 border-emerald-200 bg-emerald-50 hover:bg-emerald-100' : 'text-muted-foreground border-border bg-muted/30 hover:bg-muted/50'"
                :title="item.category.is_active ? t('admin.categories.status.clickToDeactivate') : t('admin.categories.status.clickToActivate')"
                @click="toggleActive(item.category)"
              >
                {{ item.category.is_active ? t('admin.categories.status.active') : t('admin.categories.status.inactive') }}
              </span>
            </TableCell>
            <TableCell class="min-w-[140px] px-6 py-4 text-right">
              <div class="flex items-center justify-end gap-2">
                <Button size="sm" variant="outline" @click="openEditModal(item.category)">{{ t('admin.categories.actions.edit') }}</Button>
                <Button size="sm" variant="destructive" @click="handleDelete(item.category)">{{ t('admin.categories.actions.delete') }}</Button>
              </div>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <Dialog v-model:open="showModal" @update:open="(value) => { if (!value) closeModal() }">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-lg p-4 sm:p-6" @interact-outside="(e) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ isEditing ? t('admin.categories.modal.editTitle') : t('admin.categories.modal.createTitle') }}</DialogTitle>
        </DialogHeader>
        <form class="space-y-6" @submit.prevent="handleSubmit">
          <div class="border-b border-border">
            <div class="flex gap-2 overflow-x-auto pb-1 sm:gap-4">
              <button
                v-for="lang in languages"
                :key="lang.code"
                type="button"
                class="shrink-0 border-b-2 px-3 py-2 text-sm font-medium sm:px-4"
                :class="currentLang === lang.code ? 'border-primary text-foreground' : 'border-transparent text-muted-foreground hover:text-foreground'"
                @click="currentLang = lang.code"
              >
                {{ lang.name }}
              </button>
            </div>
          </div>

          <div>
            <label class="block text-xs font-medium text-muted-foreground mb-1.5">{{ t('admin.categories.form.name', { lang: getCurrentLangName() }) }}</label>
            <Input v-model="form.name[currentLang]" :placeholder="t('admin.categories.form.namePlaceholder')" />
            <p v-if="errors.name" class="text-xs text-destructive mt-1">{{ errors.name }}</p>
          </div>

          <div>
            <label class="block text-xs font-medium text-muted-foreground mb-1.5">{{ t('admin.categories.form.slug') }}</label>
            <Input v-model="form.slug" :placeholder="t('admin.categories.form.slugPlaceholder')" />
            <p v-if="errors.slug" class="text-xs text-destructive mt-1">{{ errors.slug }}</p>
          </div>

          <div>
            <label class="block text-xs font-medium text-muted-foreground mb-1.5">{{ t('admin.categories.form.parent') }}</label>
            <Select
              :model-value="String(form.parent_id || 0)"
              @update:modelValue="(value) => { form.parent_id = Number(value || 0) || 0 }"
            >
              <SelectTrigger class="h-9 w-full">
                <SelectValue :placeholder="t('admin.categories.form.parentPlaceholder')" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="0">{{ t('admin.categories.form.parentRoot') }}</SelectItem>
                <SelectItem v-for="category in parentCategoryOptions" :key="category.id" :value="String(category.id)">
                  {{ getCategoryPath(category) }}
                </SelectItem>
              </SelectContent>
            </Select>
            <p class="text-xs text-muted-foreground mt-1">
              {{ canChooseParent ? t('admin.categories.form.parentTip') : t('admin.categories.form.parentLockedTip') }}
            </p>
          </div>

          <div>
            <label class="block text-xs font-medium text-muted-foreground mb-1.5">{{ t('admin.categories.form.icon') }}</label>
            <MediaPicker v-model="form.icon" scene="category" />
          </div>

          <div>
            <label class="block text-xs font-medium text-muted-foreground mb-1.5">{{ t('admin.categories.form.sortOrder') }}</label>
            <Input v-model.number="form.sort_order" type="number" placeholder="0" />
            <p class="text-xs text-muted-foreground mt-1">{{ t('admin.categories.form.sortTip') }}</p>
          </div>

          <div class="flex flex-col-reverse gap-3 border-t border-border pt-6 sm:flex-row sm:justify-end">
            <Button type="button" variant="outline" class="w-full sm:w-auto" @click="closeModal">{{ t('admin.common.cancel') }}</Button>
            <Button type="submit" class="w-full sm:w-auto" :disabled="submitting">{{ isEditing ? t('admin.categories.actions.saveChanges') : t('admin.categories.actions.createNow') }}</Button>
          </div>
        </form>
      </DialogScrollContent>
    </Dialog>
  </div>
</template>

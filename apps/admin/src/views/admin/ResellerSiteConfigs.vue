<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useDebounceFn } from '@vueuse/core'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import { adminAPI } from '@/api/admin'
import type {
  AdminResellerLocalizedText,
  AdminResellerSiteConfig,
  AdminResellerSiteConfigPayload,
} from '@/api/types'
import { Info, CircleCheck, CircleAlert } from 'lucide-vue-next'
import IdCell from '@/components/IdCell.vue'
import MediaPicker from '@/components/admin/MediaPicker.vue'
import RichEditor from '@/components/RichEditor.vue'
import ResellerLocaleSwitch from '@/components/admin/ResellerLocaleSwitch.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Textarea } from '@/components/ui/textarea'
import TableSkeleton from '@/components/TableSkeleton.vue'
import ListPagination from '@/components/ListPagination.vue'
import { useListRefresh, type ListFetchOptions } from '@/composables/useListRefresh'
import { confirmAction } from '@/utils/confirm'
import { formatDate } from '@/utils/format'
import { getImageUrl } from '@/utils/image'
import { notifyError, notifySuccess } from '@/utils/notify'
import {
  blankLocalizedText,
  canEditResellerSiteConfig,
  getLocalizedText,
  normalizeFooterLinksForForm,
  normalizeLocalizedTextForForm,
  type ResellerLocale,
  type ResellerLocalizedText,
} from '@/utils/resellerSiteConfig'

type ResellerSiteConfigForm = {
  site_name: string
  logo: string
  favicon: string
  announcement: {
    enabled: boolean
    type: string
    title: ResellerLocalizedText
    content: ResellerLocalizedText
  }
  support: {
    telegram: string
    whatsapp: string
    email: string
    support_url: string
  }
  seo: {
    title: ResellerLocalizedText
    keywords: ResellerLocalizedText
    description: ResellerLocalizedText
    default_og_image: string
  }
  footer_links: Array<{
    name: ResellerLocalizedText
    url: string
  }>
  nav_config: {
    builtin: Record<string, boolean>
  }
}

const { t, locale } = useI18n()
const route = useRoute()
const loading = ref(true)
const { refreshing, refreshList } = useListRefresh()
const saving = ref(false)
const operatingId = ref<number | null>(null)
const rows = ref<AdminResellerSiteConfig[]>([])
const selectedRow = ref<AdminResellerSiteConfig | null>(null)
const showEditor = ref(false)
const pagination = ref({
  page: 1,
  page_size: 20,
  total: 0,
  total_page: 1,
})

const filters = reactive({
  keyword: '',
  resellerId: '',
})

const queryString = (value: unknown) => (Array.isArray(value) ? value[0] : value)

const initFiltersFromQuery = () => {
  const resellerId = String(queryString(route.query.reseller_id) || '').trim()
  if (resellerId) filters.resellerId = resellerId
}

const pageSizeOptions = [10, 20, 50, 100]
const navBuiltinKeys = ['blog', 'notice', 'about']

const activeTab = ref<'brand' | 'announcement' | 'support' | 'seo' | 'footer' | 'nav'>('brand')
const activeLocale = ref<ResellerLocale>('zh-CN')
const localeLabels: Record<ResellerLocale, string> = {
  'zh-CN': '简体',
  'zh-TW': '繁體',
  'en-US': 'EN',
}
const announcementTypeOptions = [
  { value: 'info', icon: Info, iconClass: 'text-primary' },
  { value: 'success', icon: CircleCheck, iconClass: 'text-success' },
  { value: 'warning', icon: CircleAlert, iconClass: 'text-warning' },
]

const createBlankForm = (): ResellerSiteConfigForm => ({
  site_name: '',
  logo: '',
  favicon: '',
  announcement: {
    enabled: false,
    type: 'info',
    title: blankLocalizedText(),
    content: blankLocalizedText(),
  },
  support: {
    telegram: '',
    whatsapp: '',
    email: '',
    support_url: '',
  },
  seo: {
    title: blankLocalizedText(),
    keywords: blankLocalizedText(),
    description: blankLocalizedText(),
    default_og_image: '',
  },
  footer_links: [],
  nav_config: {
    builtin: {
      blog: true,
      notice: true,
      about: true,
    },
  },
})

const form = reactive<ResellerSiteConfigForm>(createBlankForm())

const userLabel = (row: AdminResellerSiteConfig) => {
  const user = row.profile?.user
  return user?.email || user?.display_name || `#${row.profile?.user_id || row.reseller_id}`
}

const localized = (value?: AdminResellerLocalizedText | string | null) =>
  getLocalizedText(value, locale.value)

const assignForm = (source: ResellerSiteConfigForm) => {
  Object.assign(form, source)
}

const normalizeConfigForForm = (row: AdminResellerSiteConfig): ResellerSiteConfigForm => {
  const announcement = row.announcement || {}
  const support = row.support || {}
  const seo = row.seo || {}
  const navConfig = row.nav_config || {}
  const builtin = {
    blog: navConfig.builtin?.blog !== false,
    notice: navConfig.builtin?.notice !== false,
    about: navConfig.builtin?.about !== false,
  }

  return {
    site_name: row.site_name || '',
    logo: row.logo || '',
    favicon: row.favicon || '',
    announcement: {
      enabled: announcement.enabled === true,
      type: String(announcement.type || 'info'),
      title: normalizeLocalizedTextForForm(announcement.title),
      content: normalizeLocalizedTextForForm(announcement.content),
    },
    support: {
      telegram: String(support.telegram || ''),
      whatsapp: String(support.whatsapp || ''),
      email: String(support.email || ''),
      support_url: String(support.support_url || ''),
    },
    seo: {
      title: normalizeLocalizedTextForForm(seo.title),
      keywords: normalizeLocalizedTextForForm(seo.keywords),
      description: normalizeLocalizedTextForForm(seo.description),
      default_og_image: String(seo.default_og_image || ''),
    },
    footer_links: normalizeFooterLinksForForm(row.footer_links),
    nav_config: { builtin },
  }
}

const buildPayload = (): AdminResellerSiteConfigPayload => ({
  site_name: form.site_name.trim(),
  logo: form.logo.trim(),
  favicon: form.favicon.trim(),
  announcement: {
    enabled: form.announcement.enabled,
    type: form.announcement.type.trim() || 'info',
    title: form.announcement.title,
    content: form.announcement.content,
  },
  support: {
    telegram: form.support.telegram.trim(),
    whatsapp: form.support.whatsapp.trim(),
    email: form.support.email.trim(),
    support_url: form.support.support_url.trim(),
  },
  seo: {
    title: form.seo.title,
    keywords: form.seo.keywords,
    description: form.seo.description,
    default_og_image: form.seo.default_og_image.trim(),
  },
  footer_links: form.footer_links
    .map((item) => ({
      name: item.name,
      url: item.url.trim(),
    }))
    .filter((item) => item.url || Object.values(item.name).some((value) => value.trim())),
  nav_config: {
    builtin: {
      blog: form.nav_config.builtin.blog !== false,
      notice: form.nav_config.builtin.notice !== false,
      about: form.nav_config.builtin.about !== false,
    },
    custom_items: [],
  },
})

const fetchRows = async (page = 1, options: ListFetchOptions = {}) => {
  if (!options.preserveRows) loading.value = true
  try {
    const response = await adminAPI.getResellerSiteConfigs({
      page,
      page_size: pagination.value.page_size,
      keyword: filters.keyword || undefined,
      reseller_id: filters.resellerId || undefined,
    })
    rows.value = response.data.data || []
    pagination.value = response.data.pagination || pagination.value
  } catch (err: any) {
    if (!options.preserveRows) rows.value = []
    notifyError(err?.message || t('admin.resellerSiteConfigs.messages.loadFailed'))
  } finally {
    if (!options.preserveRows) loading.value = false
  }
}

const handleSearch = () => {
  fetchRows(1, { preserveRows: true })
}

const debouncedSearch = useDebounceFn(handleSearch, 300)

const refreshCurrentPage = () => {
  refreshList(() => fetchRows(pagination.value.page, { preserveRows: true }))
}

const changePage = (page: number) => {
  if (page < 1 || page > pagination.value.total_page) return
  fetchRows(page)
}

const changePageSize = (size: number) => {
  if (size === pagination.value.page_size) return
  pagination.value.page_size = size
  fetchRows(1)
}

const openEditor = async (row: AdminResellerSiteConfig) => {
  operatingId.value = row.reseller_id
  try {
    const response = await adminAPI.getResellerSiteConfig(row.reseller_id)
    const latest = response.data.data as AdminResellerSiteConfig
    selectedRow.value = latest
    assignForm(normalizeConfigForForm(latest))
    activeTab.value = 'brand'
    activeLocale.value = 'zh-CN'
    showEditor.value = true
  } catch (err: any) {
    notifyError(err?.message || t('admin.resellerSiteConfigs.messages.loadFailed'))
  } finally {
    operatingId.value = null
  }
}

const addFooterLink = () => {
  form.footer_links.push({ name: blankLocalizedText(), url: '' })
}

const removeFooterLink = (index: number) => {
  form.footer_links.splice(index, 1)
}

const saveConfig = async () => {
  if (!selectedRow.value) return
  saving.value = true
  try {
    const response = await adminAPI.updateResellerSiteConfig(selectedRow.value.reseller_id, buildPayload())
    selectedRow.value = response.data.data as AdminResellerSiteConfig
    assignForm(normalizeConfigForForm(selectedRow.value))
    notifySuccess(t('admin.resellerSiteConfigs.messages.saveSuccess'))
    await fetchRows(pagination.value.page, { preserveRows: true })
  } catch (err: any) {
    notifyError(err?.message || t('admin.resellerSiteConfigs.messages.saveFailed'))
  } finally {
    saving.value = false
  }
}

const resetConfig = async (row: AdminResellerSiteConfig) => {
  const confirmed = await confirmAction({
    description: t('admin.resellerSiteConfigs.actions.resetConfirm', { id: row.reseller_id }),
    variant: 'destructive',
  })
  if (!confirmed) return
  operatingId.value = row.reseller_id
  try {
    await adminAPI.resetResellerSiteConfig(row.reseller_id)
    notifySuccess(t('admin.resellerSiteConfigs.messages.resetSuccess'))
    await fetchRows(pagination.value.page, { preserveRows: true })
    if (selectedRow.value?.reseller_id === row.reseller_id) {
      showEditor.value = false
      selectedRow.value = null
      assignForm(createBlankForm())
    }
  } catch (err: any) {
    notifyError(err?.message || t('admin.resellerSiteConfigs.messages.resetFailed'))
  } finally {
    operatingId.value = null
  }
}

onMounted(() => {
  initFiltersFromQuery()
  fetchRows()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold">{{ t('admin.resellerSiteConfigs.title') }}</h1>
        <p class="mt-1 text-sm text-muted-foreground">{{ t('admin.resellerSiteConfigs.subtitle') }}</p>
      </div>
    </div>

    <div class="rounded-xl border border-border bg-card p-4 shadow-sm">
      <div class="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center">
        <div class="w-full md:w-60">
          <Input v-model="filters.keyword" :placeholder="t('admin.resellerSiteConfigs.filters.keyword')" @update:modelValue="debouncedSearch" />
        </div>
        <div class="w-full md:w-36">
          <Input v-model="filters.resellerId" :placeholder="t('admin.resellerSiteConfigs.filters.resellerId')" @update:modelValue="debouncedSearch" />
        </div>
        <div class="hidden flex-1 sm:block"></div>
        <Button size="sm" variant="outline" class="w-full sm:w-auto" :disabled="refreshing" @click="refreshCurrentPage">
          {{ t('admin.common.refresh') }}
        </Button>
      </div>
    </div>

    <div class="rounded-xl border border-border bg-card overflow-x-auto">
      <Table class="min-w-[1120px]">
        <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
          <TableRow>
            <TableHead class="px-6 py-3">{{ t('admin.resellerSiteConfigs.table.id') }}</TableHead>
            <TableHead class="min-w-[190px] px-6 py-3">{{ t('admin.resellerSiteConfigs.table.reseller') }}</TableHead>
            <TableHead class="min-w-[170px] px-6 py-3">{{ t('admin.resellerSiteConfigs.table.siteName') }}</TableHead>
            <TableHead class="min-w-[150px] px-6 py-3">{{ t('admin.resellerSiteConfigs.table.logo') }}</TableHead>
            <TableHead class="min-w-[150px] px-6 py-3">{{ t('admin.resellerSiteConfigs.table.favicon') }}</TableHead>
            <TableHead class="min-w-[190px] px-6 py-3">{{ t('admin.resellerSiteConfigs.table.updatedAt') }}</TableHead>
            <TableHead class="min-w-[160px] px-6 py-3 text-right">{{ t('admin.resellerSiteConfigs.table.action') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody class="divide-y divide-border">
          <template v-if="loading">
            <TableRow v-for="n in 5" :key="n">
              <TableCell colspan="7" class="px-6 py-4">
                <TableSkeleton :rows="1" />
              </TableCell>
            </TableRow>
          </template>
          <template v-else-if="rows.length">
            <TableRow v-for="item in rows" :key="item.id">
              <TableCell class="px-6 py-4">
                <IdCell :value="item.id" />
              </TableCell>
              <TableCell class="px-6 py-4">
                <div class="font-medium text-foreground">#{{ item.reseller_id }}</div>
                <div class="text-xs text-muted-foreground break-all">{{ userLabel(item) }}</div>
              </TableCell>
              <TableCell class="px-6 py-4">
                <span class="text-sm text-foreground">{{ item.site_name || '-' }}</span>
              </TableCell>
              <TableCell class="px-6 py-4">
                <img v-if="item.logo" :src="getImageUrl(item.logo)" class="h-9 w-9 rounded border border-border bg-muted/30 object-contain" alt="logo" />
                <span v-else class="text-xs text-muted-foreground">-</span>
              </TableCell>
              <TableCell class="px-6 py-4">
                <img v-if="item.favicon" :src="getImageUrl(item.favicon)" class="h-9 w-9 rounded border border-border bg-muted/30 object-contain" alt="favicon" />
                <span v-else class="text-xs text-muted-foreground">-</span>
              </TableCell>
              <TableCell class="px-6 py-4 text-sm text-muted-foreground">{{ formatDate(item.updated_at) }}</TableCell>
              <TableCell class="px-6 py-4">
                <div class="flex justify-end gap-2">
                  <Button size="sm" variant="outline" :disabled="operatingId === item.reseller_id || !canEditResellerSiteConfig(item.profile)" @click="openEditor(item)">
                    {{ t('admin.resellerSiteConfigs.actions.edit') }}
                  </Button>
                  <Button size="sm" variant="outline" class="text-destructive" :disabled="operatingId === item.reseller_id" @click="resetConfig(item)">
                    {{ t('admin.resellerSiteConfigs.actions.reset') }}
                  </Button>
                </div>
              </TableCell>
            </TableRow>
          </template>
          <TableRow v-else>
            <TableCell colspan="7" class="px-6 py-12 text-center text-sm text-muted-foreground">
              {{ t('admin.resellerSiteConfigs.empty') }}
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <ListPagination
      :page="pagination.page"
      :total-page="pagination.total_page"
      :total="pagination.total"
      :page-size="pagination.page_size"
      :page-size-options="pageSizeOptions"
      @change-page="changePage"
      @change-page-size="changePageSize"
    />

    <Dialog v-model:open="showEditor" @update:open="(value) => { if (!value) selectedRow = null }">
      <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-5xl p-4 sm:p-6" @interact-outside="(e) => e.preventDefault()">
        <DialogHeader>
          <DialogTitle>{{ t('admin.resellerSiteConfigs.editor.title', { id: selectedRow?.reseller_id || '-' }) }}</DialogTitle>
        </DialogHeader>

        <Tabs v-model="activeTab" class="mt-2">
          <TabsList class="flex h-auto w-full flex-wrap justify-start gap-1 bg-muted/40 p-1">
            <TabsTrigger value="brand" class="flex-none">{{ t('admin.resellerSiteConfigs.editor.sections.brand') }}</TabsTrigger>
            <TabsTrigger value="announcement" class="flex-none">{{ t('admin.resellerSiteConfigs.editor.sections.announcement') }}</TabsTrigger>
            <TabsTrigger value="support" class="flex-none">{{ t('admin.resellerSiteConfigs.editor.sections.support') }}</TabsTrigger>
            <TabsTrigger value="seo" class="flex-none">{{ t('admin.resellerSiteConfigs.editor.sections.seo') }}</TabsTrigger>
            <TabsTrigger value="footer" class="flex-none">{{ t('admin.resellerSiteConfigs.editor.sections.footer') }}</TabsTrigger>
            <TabsTrigger value="nav" class="flex-none">{{ t('admin.resellerSiteConfigs.editor.sections.nav') }}</TabsTrigger>
          </TabsList>

          <!-- 品牌 -->
          <TabsContent value="brand" class="mt-4 space-y-4">
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.siteName') }}</Label>
              <Input v-model="form.site_name" />
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
              <div class="grid gap-2">
                <Label>{{ t('admin.resellerSiteConfigs.fields.logo') }}</Label>
                <MediaPicker v-model="form.logo" scene="reseller" />
              </div>
              <div class="grid gap-2">
                <Label>{{ t('admin.resellerSiteConfigs.fields.favicon') }}</Label>
                <MediaPicker v-model="form.favicon" scene="reseller" />
              </div>
            </div>
          </TabsContent>

          <!-- 公告 -->
          <TabsContent value="announcement" class="mt-4 space-y-4">
            <div class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-muted/20 p-3">
              <div class="flex items-center gap-2">
                <Switch v-model="form.announcement.enabled" />
                <span class="text-sm text-muted-foreground">{{ t('admin.resellerSiteConfigs.fields.announcementEnabled') }}</span>
              </div>
              <div class="grid gap-1">
                <span class="text-xs text-muted-foreground">{{ t('admin.resellerSiteConfigs.fields.announcementType') }}</span>
                <Select v-model="form.announcement.type">
                  <SelectTrigger class="h-9 w-44"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem v-for="opt in announcementTypeOptions" :key="opt.value" :value="opt.value">
                      <span class="flex items-center gap-2">
                        <component :is="opt.icon" class="h-4 w-4" :class="opt.iconClass" />
                        {{ t(`admin.resellerSiteConfigs.announcementTypes.${opt.value}`) }}
                      </span>
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div class="flex items-center justify-between gap-3">
              <Label>{{ t('admin.resellerSiteConfigs.editor.language') }}</Label>
              <ResellerLocaleSwitch v-model="activeLocale" :labels="localeLabels" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.announcementTitle') }}</Label>
              <Input v-model="form.announcement.title[activeLocale]" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.announcementContent') }}</Label>
              <RichEditor :key="`ann-${activeLocale}`" v-model="form.announcement.content[activeLocale]" />
            </div>
          </TabsContent>

          <!-- 联系方式 -->
          <TabsContent value="support" class="mt-4 grid gap-4 sm:grid-cols-2">
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.telegram') }}</Label>
              <Input v-model="form.support.telegram" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.whatsapp') }}</Label>
              <Input v-model="form.support.whatsapp" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.email') }}</Label>
              <Input v-model="form.support.email" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.supportUrl') }}</Label>
              <Input v-model="form.support.support_url" />
            </div>
          </TabsContent>

          <!-- SEO -->
          <TabsContent value="seo" class="mt-4 space-y-4">
            <div class="flex items-center justify-between gap-3">
              <Label>{{ t('admin.resellerSiteConfigs.editor.language') }}</Label>
              <ResellerLocaleSwitch v-model="activeLocale" :labels="localeLabels" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.seoTitle') }}</Label>
              <Input v-model="form.seo.title[activeLocale]" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.seoKeywords') }}</Label>
              <Input v-model="form.seo.keywords[activeLocale]" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.seoDescription') }}</Label>
              <Textarea v-model="form.seo.description[activeLocale]" rows="3" />
            </div>
            <div class="grid gap-2">
              <Label>{{ t('admin.resellerSiteConfigs.fields.ogImage') }}</Label>
              <MediaPicker v-model="form.seo.default_og_image" scene="reseller" />
            </div>
          </TabsContent>

          <!-- 页脚链接 -->
          <TabsContent value="footer" class="mt-4 space-y-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <ResellerLocaleSwitch v-model="activeLocale" :labels="localeLabels" />
              <Button type="button" size="sm" variant="outline" @click="addFooterLink">
                {{ t('admin.resellerSiteConfigs.actions.addLink') }}
              </Button>
            </div>
            <div v-if="form.footer_links.length" class="space-y-3">
              <div v-for="(link, index) in form.footer_links" :key="index" class="grid gap-3 rounded-md border border-border p-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
                <div class="grid gap-1">
                  <Label>{{ t('admin.resellerSiteConfigs.fields.linkName') }} · {{ localeLabels[activeLocale] }}</Label>
                  <Input v-model="link.name[activeLocale]" />
                </div>
                <div class="grid gap-1">
                  <Label>{{ t('admin.resellerSiteConfigs.fields.linkUrl') }}</Label>
                  <Input v-model="link.url" />
                </div>
                <Button type="button" size="sm" variant="outline" class="text-destructive" @click="removeFooterLink(index)">
                  {{ t('admin.resellerSiteConfigs.actions.removeLink') }}
                </Button>
              </div>
            </div>
            <p v-else class="text-sm text-muted-foreground">{{ t('admin.resellerSiteConfigs.emptyLinks') }}</p>
          </TabsContent>

          <!-- 导航 -->
          <TabsContent value="nav" class="mt-4 space-y-3">
            <div v-for="key in navBuiltinKeys" :key="key" class="flex items-center justify-between rounded-md border border-border px-3 py-2">
              <span class="text-sm text-foreground">{{ t(`admin.resellerSiteConfigs.navItems.${key}`) }}</span>
              <Switch v-model="form.nav_config.builtin[key]" />
            </div>
          </TabsContent>
        </Tabs>

        <div class="flex flex-col-reverse gap-2 pt-2 sm:flex-row sm:justify-end">
          <Button variant="outline" :disabled="saving" @click="showEditor = false">
            {{ t('admin.common.cancel') }}
          </Button>
          <Button :disabled="saving" @click="saveConfig">
            {{ saving ? t('admin.resellerSiteConfigs.actions.saving') : t('admin.resellerSiteConfigs.actions.save') }}
          </Button>
        </div>

        <div v-if="selectedRow" class="rounded-md bg-muted/40 p-3 text-xs text-muted-foreground">
          {{ t('admin.resellerSiteConfigs.previewLabel') }}:
          {{ selectedRow.site_name || localized(selectedRow.seo?.title) || userLabel(selectedRow) }}
        </div>
      </DialogScrollContent>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import RichEditor from '@/components/RichEditor.vue'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { notifyError, notifySuccess } from '@/utils/notify'

const { t } = useI18n()

const supportedLanguages = ['zh-CN', 'zh-TW', 'en-US'] as const
type SupportedLanguage = (typeof supportedLanguages)[number]

const props = defineProps<{
  currentLang: SupportedLanguage
}>()

const emit = defineEmits<{
  saved: []
}>()

const submitting = ref(false)
const loaded = ref(false)

const createLocalizedField = (): Record<SupportedLanguage, string> => ({
  'zh-CN': '',
  'zh-TW': '',
  'en-US': '',
})

const form = reactive({
  enabled: false,
  type: 'normal' as 'normal' | 'info' | 'warning',
  title: createLocalizedField(),
  content: createLocalizedField(),
  start_at: '',
  end_at: '',
})

// RFC3339 -> datetime-local 输入值（本地时区）
const toLocalInput = (rfc: string): string => {
  if (!rfc) return ''
  const date = new Date(rfc)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

// datetime-local 输入值 -> RFC3339（UTC）
const toRFC3339 = (local: string): string => {
  if (!local) return ''
  const date = new Date(local)
  if (Number.isNaN(date.getTime())) return ''
  return date.toISOString()
}

// 判断富文本是否为空（保留纯图片/表格类内容）
const isRichTextEmpty = (html: string): boolean => {
  if (!html) return true
  if (/<(img|table|iframe|hr|video)\b/i.test(html)) return false
  return html.replace(/<[^>]*>/g, '').replace(/&nbsp;/gi, '').trim() === ''
}

const fetchAnnouncement = async () => {
  try {
    const res = await adminAPI.getHomeAnnouncement()
    const data = res.data?.data
    if (data && typeof data === 'object') {
      const d = data as Record<string, unknown>
      form.enabled = d.enabled === true
      form.type = d.type === 'info' || d.type === 'warning' ? d.type : 'normal'
      const title = (d.title as Record<string, string>) || {}
      const content = (d.content as Record<string, string>) || {}
      for (const lang of supportedLanguages) {
        form.title[lang] = title[lang] || ''
        form.content[lang] = content[lang] || ''
      }
      form.start_at = toLocalInput((d.start_at as string) || '')
      form.end_at = toLocalInput((d.end_at as string) || '')
    }
  } catch {
    // 首次使用，无数据
  } finally {
    loaded.value = true
  }
}

const save = async () => {
  submitting.value = true
  try {
    const content = createLocalizedField()
    for (const lang of supportedLanguages) {
      content[lang] = isRichTextEmpty(form.content[lang]) ? '' : form.content[lang]
    }
    await adminAPI.updateHomeAnnouncement({
      enabled: form.enabled,
      type: form.type,
      title: { ...form.title },
      content,
      start_at: toRFC3339(form.start_at),
      end_at: toRFC3339(form.end_at),
      version: `home-${Date.now().toString(36)}`,
    })
    notifySuccess(t('admin.settings.alerts.saveSuccess'))
    emit('saved')
  } catch {
    notifyError(t('admin.settings.alerts.saveFailed'))
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchAnnouncement()
})

defineExpose({ save, submitting })
</script>

<template>
  <div v-if="loaded" class="space-y-6">
    <div class="rounded-xl border border-border bg-card">
      <div class="border-b border-border bg-muted/40 px-6 py-4">
        <h2 class="text-lg font-semibold">{{ t('admin.settings.homeAnnouncement.title') }}</h2>
        <p class="mt-1 text-xs text-muted-foreground">{{ t('admin.settings.homeAnnouncement.subtitle') }}</p>
      </div>
      <div class="space-y-5 px-6 py-5">
        <!-- 启用开关 -->
        <div class="flex items-center justify-between gap-4">
          <div>
            <Label class="text-sm font-medium">{{ t('admin.settings.homeAnnouncement.enabled') }}</Label>
            <p class="mt-1 text-xs text-muted-foreground">{{ t('admin.settings.homeAnnouncement.enabledDesc') }}</p>
          </div>
          <Switch v-model="form.enabled" />
        </div>

        <!-- 公告类型 -->
        <div class="space-y-2">
          <Label class="text-sm font-medium">{{ t('admin.settings.homeAnnouncement.type') }}</Label>
          <Select v-model="form.type">
            <SelectTrigger class="h-10 w-full sm:w-60">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="normal">{{ t('admin.settings.homeAnnouncement.typeNormal') }}</SelectItem>
              <SelectItem value="info">{{ t('admin.settings.homeAnnouncement.typeInfo') }}</SelectItem>
              <SelectItem value="warning">{{ t('admin.settings.homeAnnouncement.typeWarning') }}</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <!-- 公告标题 -->
        <div class="space-y-2">
          <div class="flex items-center gap-2">
            <Label class="text-sm font-medium">{{ t('admin.settings.homeAnnouncement.announceTitle') }}</Label>
            <span class="rounded bg-muted px-2 py-1 text-xs text-muted-foreground">{{ currentLang }}</span>
          </div>
          <Input v-model="form.title[currentLang]" :placeholder="t('admin.settings.homeAnnouncement.announceTitlePlaceholder')" />
        </div>

        <!-- 公告内容 -->
        <div class="space-y-2">
          <div class="flex items-center gap-2">
            <Label class="text-sm font-medium">{{ t('admin.settings.homeAnnouncement.content') }}</Label>
            <span class="rounded bg-muted px-2 py-1 text-xs text-muted-foreground">{{ currentLang }}</span>
          </div>
          <RichEditor :key="`announcement-${currentLang}`" v-model="form.content[currentLang]" :placeholder="t('admin.settings.homeAnnouncement.contentPlaceholder')" />
        </div>

        <!-- 排期 -->
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label class="text-sm font-medium">{{ t('admin.settings.homeAnnouncement.startAt') }}</Label>
            <Input v-model="form.start_at" type="datetime-local" />
          </div>
          <div class="space-y-2">
            <Label class="text-sm font-medium">{{ t('admin.settings.homeAnnouncement.endAt') }}</Label>
            <Input v-model="form.end_at" type="datetime-local" />
          </div>
        </div>
        <p class="text-xs text-muted-foreground">{{ t('admin.settings.homeAnnouncement.scheduleHint') }}</p>
      </div>
    </div>
  </div>
</template>

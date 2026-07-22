<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { notifyError, notifySuccess } from '@/utils/notify'

const { t } = useI18n()

const supportedLanguages = ['zh-CN', 'zh-TW', 'en-US'] as const
type SupportedLanguage = (typeof supportedLanguages)[number]

type OrderEmailLocalizedTemplate = { subject: string; body: string }
type OrderEmailSceneTemplate = Record<SupportedLanguage, OrderEmailLocalizedTemplate>

interface OrderEmailTemplateData {
  templates: {
    default: OrderEmailSceneTemplate
    paid: OrderEmailSceneTemplate
    delivered: OrderEmailSceneTemplate
    delivered_with_content: OrderEmailSceneTemplate
    canceled: OrderEmailSceneTemplate
    refunded: OrderEmailSceneTemplate
    partially_refunded: OrderEmailSceneTemplate
  }
  guest_tip: Record<SupportedLanguage, string>
}

const sceneKeys = ['default', 'paid', 'delivered', 'delivered_with_content', 'canceled', 'refunded', 'partially_refunded'] as const
type SceneKey = (typeof sceneKeys)[number]

const props = defineProps<{
  data: OrderEmailTemplateData
  currentLang: SupportedLanguage
}>()

const emit = defineEmits<{
  saved: []
}>()

const submitting = ref(false)
const resetting = ref(false)
const currentScene = ref<SceneKey>('default')

const createLocalizedTemplate = (): OrderEmailLocalizedTemplate => ({ subject: '', body: '' })
const createSceneTemplate = (): OrderEmailSceneTemplate => ({
  'zh-CN': createLocalizedTemplate(),
  'zh-TW': createLocalizedTemplate(),
  'en-US': createLocalizedTemplate(),
})

const deepCloneTemplate = (src: OrderEmailSceneTemplate): OrderEmailSceneTemplate => {
  const result = createSceneTemplate()
  ;(['zh-CN', 'zh-TW', 'en-US'] as const).forEach((lang) => {
    result[lang].subject = src[lang]?.subject || ''
    result[lang].body = src[lang]?.body || ''
  })
  return result
}

const form = reactive({
  templates: {
    default: createSceneTemplate(),
    paid: createSceneTemplate(),
    delivered: createSceneTemplate(),
    delivered_with_content: createSceneTemplate(),
    canceled: createSceneTemplate(),
    refunded: createSceneTemplate(),
    partially_refunded: createSceneTemplate(),
  },
  guest_tip: { 'zh-CN': '', 'zh-TW': '', 'en-US': '' } as Record<SupportedLanguage, string>,
})

const syncFromProps = () => {
  sceneKeys.forEach((key) => {
    form.templates[key] = deepCloneTemplate(props.data.templates[key])
  })
  supportedLanguages.forEach((lang) => {
    form.guest_tip[lang] = props.data.guest_tip[lang] || ''
  })
}

syncFromProps()

watch(() => props.data, syncFromProps, { deep: true })

const templateVariables = [
  { key: 'order_no', label: () => t('admin.settings.orderEmailTemplate.variableList.order_no') },
  { key: 'status', label: () => t('admin.settings.orderEmailTemplate.variableList.status') },
  { key: 'amount', label: () => t('admin.settings.orderEmailTemplate.variableList.amount') },
  { key: 'refund_amount', label: () => t('admin.settings.orderEmailTemplate.variableList.refund_amount') },
  { key: 'refund_reason', label: () => t('admin.settings.orderEmailTemplate.variableList.refund_reason') },
  { key: 'currency', label: () => t('admin.settings.orderEmailTemplate.variableList.currency') },
  { key: 'fulfillment_info', label: () => t('admin.settings.orderEmailTemplate.variableList.fulfillment_info') },
  { key: 'site_name', label: () => t('admin.settings.orderEmailTemplate.variableList.site_name') },
  { key: 'site_url', label: () => t('admin.settings.orderEmailTemplate.variableList.site_url') },
]

const notifyErrorIfNeeded = (err: unknown, fallback: string) => {
  const known = err as Error & { __notified?: boolean }
  if (known?.__notified) return
  notifyError(known?.message || fallback)
}

const save = async () => {
  submitting.value = true
  try {
    const payload: Record<string, unknown> = {
      templates: {} as Record<string, unknown>,
      guest_tip: { ...form.guest_tip },
    }
    const templates = payload.templates as Record<string, unknown>
    sceneKeys.forEach((key) => {
      const scene: Record<string, unknown> = {}
      supportedLanguages.forEach((lang) => {
        scene[lang] = {
          subject: form.templates[key][lang].subject,
          body: form.templates[key][lang].body,
        }
      })
      templates[key] = scene
    })
    await adminAPI.updateOrderEmailTemplateSettings(payload)
    notifySuccess(t('admin.settings.alerts.saveSuccess'))
    emit('saved')
  } catch (err) {
    notifyErrorIfNeeded(err, t('admin.settings.alerts.saveFailed'))
  } finally {
    submitting.value = false
  }
}

const resetToDefault = async () => {
  if (!confirm(t('admin.settings.orderEmailTemplate.resetConfirm'))) return
  resetting.value = true
  try {
    await adminAPI.resetOrderEmailTemplateSettings()
    notifySuccess(t('admin.settings.orderEmailTemplate.resetSuccess'))
    emit('saved')
  } catch (err) {
    notifyErrorIfNeeded(err, t('admin.settings.alerts.saveFailed'))
  } finally {
    resetting.value = false
  }
}

defineExpose({ save, submitting })
</script>

<template>
  <div class="space-y-6">
    <div class="rounded-xl border border-border bg-card">
      <div class="border-b border-border bg-muted/40 px-6 py-4">
        <h2 class="text-lg font-semibold">{{ t('admin.settings.orderEmailTemplate.title') }}</h2>
        <p class="mt-1 text-xs text-muted-foreground">{{ t('admin.settings.orderEmailTemplate.subtitle') }}</p>
      </div>

      <div class="space-y-6 p-6">
        <!-- 可用变量提示 -->
        <div class="rounded-lg border border-blue-200 bg-blue-50 p-4 dark:border-blue-800 dark:bg-blue-950/30">
          <h3 class="mb-2 text-sm font-medium text-blue-800 dark:text-blue-300">
            {{ t('admin.settings.orderEmailTemplate.variables') }}
          </h3>
          <div class="flex flex-wrap gap-2">
            <span
              v-for="v in templateVariables"
              :key="v.key"
              class="inline-flex items-center gap-1 rounded-md bg-blue-100 px-2 py-1 text-xs font-mono dark:bg-blue-900/50"
            >
              <code class="text-blue-700 dark:text-blue-300" v-text="'{{' + v.key + '}}'"></code>
              <span class="text-blue-600 dark:text-blue-400">{{ v.label() }}</span>
            </span>
          </div>
        </div>

        <!-- 场景选择 -->
        <div class="space-y-2">
          <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.orderEmailTemplate.scene') }}</label>
          <Select v-model="currentScene">
            <SelectTrigger class="w-full sm:w-64">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem v-for="key in sceneKeys" :key="key" :value="key">
                {{ t(`admin.settings.orderEmailTemplate.scenes.${key}`) }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <!-- 当前场景模板编辑 -->
        <div class="space-y-4 rounded-lg border border-border p-4">
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.orderEmailTemplate.subject') }}</label>
            <Input v-model="form.templates[currentScene][currentLang].subject" />
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.orderEmailTemplate.body') }}</label>
            <Textarea v-model="form.templates[currentScene][currentLang].body" rows="8" class="font-mono text-sm" />
          </div>
        </div>

        <!-- 游客提示 -->
        <div class="space-y-2">
          <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.orderEmailTemplate.guestTip') }}</label>
          <p class="text-xs text-muted-foreground">{{ t('admin.settings.orderEmailTemplate.guestTipDesc') }}</p>
          <Textarea v-model="form.guest_tip[currentLang]" rows="2" class="font-mono text-sm" />
        </div>

        <!-- 操作按钮 -->
        <div class="flex items-center gap-3">
          <Button :disabled="submitting || resetting" @click="save">
            <span v-if="submitting" class="mr-2 h-3 w-3 animate-spin rounded-full border-2 border-primary/30 border-t-primary"></span>
            {{ submitting ? t('admin.settings.actions.saving') : t('admin.settings.actions.save') }}
          </Button>
          <Button variant="outline" :disabled="submitting || resetting" @click="resetToDefault">
            <span v-if="resetting" class="mr-2 h-3 w-3 animate-spin rounded-full border-2 border-primary/30 border-t-primary"></span>
            {{ t('admin.settings.orderEmailTemplate.resetToDefault') }}
          </Button>
        </div>
      </div>
    </div>
  </div>
</template>

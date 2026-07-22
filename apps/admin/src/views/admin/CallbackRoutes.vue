<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  CALLBACK_ROUTE_KEYS,
  DEFAULT_CALLBACK_ROUTE_PATHS,
  buildCallbackRoutesSavePayload,
  getCallbackRouteDisplayValue,
  toCallbackRouteSaveValue,
  type CallbackRouteKey,
} from '@/utils/callbackRoutes'
import { notifyError, notifySuccess } from '@/utils/notify'

const { t } = useI18n()

const form = reactive({
  payment_callback: '',
  dujiaopay_webhook: '',
  paypal_webhook: '',
  stripe_webhook: '',
  upstream_callback: '',
})
const saving = ref(false)

const reservedRoutePrefixes = [
  '/api/v1/public/', '/api/v1/admin/', '/api/v1/auth/',
  '/api/v1/guest/', '/api/v1/channel/', '/api/v1/upstream/api/', '/api/v1/user/',
]

const load = async () => {
  try {
    const res = await adminAPI.getSettings({ key: 'callback_routes_config' })
    const data = res.data?.data as Record<string, string> | null
    if (data) {
      form.payment_callback = data.payment_callback || ''
      form.dujiaopay_webhook = data.dujiaopay_webhook || ''
      form.paypal_webhook = data.paypal_webhook || ''
      form.stripe_webhook = data.stripe_webhook || ''
      form.upstream_callback = data.upstream_callback || ''
    }
  } catch {
    // 未配置时保持空值
  }
}

const displayRouteValue = (key: CallbackRouteKey) => {
  return getCallbackRouteDisplayValue(key, form[key])
}

const setRouteValue = (key: CallbackRouteKey, value: string | number) => {
  form[key] = toCallbackRouteSaveValue(key, value)
}

const save = async () => {
  const payload = buildCallbackRoutesSavePayload(form)
  const fields = CALLBACK_ROUTE_KEYS.map((key) => ({ key, value: payload[key] }))
  const nonEmptyPaths: string[] = []
  for (const field of fields) {
    const v = field.value
    if (v && !v.startsWith('/api/')) {
      notifyError(t('admin.settings.callbackRoutes.mustStartWithApi'))
      return
    }
    if (v) {
      const vSlash = v + '/'
      if (reservedRoutePrefixes.some(p => vSlash.startsWith(p) || p.startsWith(vSlash))) {
        notifyError(t('admin.settings.callbackRoutes.conflictWithSystem'))
        return
      }
      if (nonEmptyPaths.includes(v)) {
        notifyError(t('admin.settings.callbackRoutes.duplicatePath'))
        return
      }
      nonEmptyPaths.push(v)
    }
  }

  saving.value = true
  try {
    await adminAPI.updateSettings({
      key: 'callback_routes_config',
      value: payload,
    } as any)
    notifySuccess(t('admin.settings.saved'))
  } catch (err: any) {
    notifyError(err?.message || t('admin.settings.saveFailed'))
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
      <div>
        <h1 class="text-2xl font-semibold">{{ t('admin.settings.callbackRoutes.title') }}</h1>
        <p class="mt-1 text-sm text-muted-foreground">{{ t('admin.settings.callbackRoutes.subtitle') }}</p>
      </div>
    </div>

    <div class="rounded-xl border border-border bg-card">
      <div class="space-y-6 p-6">
        <div class="rounded-lg border border-amber-500/30 bg-amber-500/5 p-4">
          <p class="text-xs text-amber-600 dark:text-amber-400">{{ t('admin.settings.callbackRoutes.warning') }}</p>
        </div>

        <div class="grid grid-cols-1 gap-6">
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.callbackRoutes.paymentCallback') }}</label>
            <Input :model-value="displayRouteValue('payment_callback')" type="text" :placeholder="t('admin.settings.callbackRoutes.paymentCallbackPlaceholder')" @update:model-value="(value) => setRouteValue('payment_callback', value)" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.callbackRoutes.defaultPath') }}: {{ DEFAULT_CALLBACK_ROUTE_PATHS.payment_callback }}</p>
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.callbackRoutes.dujiaopayWebhook') }}</label>
            <Input :model-value="displayRouteValue('dujiaopay_webhook')" type="text" :placeholder="t('admin.settings.callbackRoutes.webhookPlaceholder')" @update:model-value="(value) => setRouteValue('dujiaopay_webhook', value)" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.callbackRoutes.defaultPath') }}: {{ DEFAULT_CALLBACK_ROUTE_PATHS.dujiaopay_webhook }}</p>
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.callbackRoutes.paypalWebhook') }}</label>
            <Input :model-value="displayRouteValue('paypal_webhook')" type="text" :placeholder="t('admin.settings.callbackRoutes.webhookPlaceholder')" @update:model-value="(value) => setRouteValue('paypal_webhook', value)" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.callbackRoutes.defaultPath') }}: {{ DEFAULT_CALLBACK_ROUTE_PATHS.paypal_webhook }}</p>
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.callbackRoutes.stripeWebhook') }}</label>
            <Input :model-value="displayRouteValue('stripe_webhook')" type="text" :placeholder="t('admin.settings.callbackRoutes.webhookPlaceholder')" @update:model-value="(value) => setRouteValue('stripe_webhook', value)" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.callbackRoutes.defaultPath') }}: {{ DEFAULT_CALLBACK_ROUTE_PATHS.stripe_webhook }}</p>
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.callbackRoutes.upstreamCallback') }}</label>
            <Input :model-value="displayRouteValue('upstream_callback')" type="text" :placeholder="t('admin.settings.callbackRoutes.callbackPlaceholder')" @update:model-value="(value) => setRouteValue('upstream_callback', value)" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.callbackRoutes.defaultPath') }}: {{ DEFAULT_CALLBACK_ROUTE_PATHS.upstream_callback }}</p>
          </div>
        </div>

        <div class="flex justify-end border-t border-border pt-4">
          <Button :disabled="saving" @click="save">
            {{ saving ? t('admin.settings.actions.saving') : t('admin.settings.actions.save') }}
          </Button>
        </div>
      </div>
    </div>
  </div>
</template>

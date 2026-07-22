<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI, type AdminAffiliateSetting } from '@/api/admin'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { notifyError, notifySuccess } from '@/utils/notify'

const { t } = useI18n()
const loading = ref(false)

const form = reactive({
  enabled: false,
  commission_rate: 0,
  confirm_days: 0,
  min_withdraw_amount: 0,
  withdraw_channels_text: '',
})

const normalizeNumber = (value: unknown, fallback: number) => {
  if (value === null || value === undefined || value === '') return fallback
  const parsed = Number(value)
  if (Number.isNaN(parsed)) return fallback
  return parsed
}

const clampNumber = (value: unknown, min: number, max: number, fallback: number) => {
  const parsed = normalizeNumber(value, fallback)
  if (parsed < min) return min
  if (parsed > max) return max
  return parsed
}

const splitChannels = (raw: string) => {
  return raw
    .split(/\r?\n|,/)
    .map((item) => item.trim())
    .filter((item) => item !== '')
}

const joinChannels = (items: unknown) => {
  if (!Array.isArray(items)) return ''
  return items
    .map((item) => String(item || '').trim())
    .filter((item) => item !== '')
    .join('\n')
}

const fetchSettings = async () => {
  loading.value = true
  try {
    const res = await adminAPI.getAffiliateSettings()
    if (res.data && res.data.data) {
      const data = res.data.data as AdminAffiliateSetting
      form.enabled = Boolean(data.enabled)
      form.commission_rate = clampNumber(data.commission_rate, 0, 100, 0)
      form.confirm_days = clampNumber(data.confirm_days, 0, 3650, 0)
      form.min_withdraw_amount = Math.max(normalizeNumber(data.min_withdraw_amount, 0), 0)
      form.withdraw_channels_text = joinChannels(data.withdraw_channels)
    }
  } catch (err: any) {
    notifyError(err?.response?.data?.message || t('admin.settings.alerts.loadFailed'))
  } finally {
    loading.value = false
  }
}

const saveSettings = async () => {
  loading.value = true
  try {
    const payload = {
      enabled: form.enabled,
      commission_rate: clampNumber(form.commission_rate, 0, 100, 0),
      confirm_days: clampNumber(form.confirm_days, 0, 3650, 0),
      min_withdraw_amount: Math.max(normalizeNumber(form.min_withdraw_amount, 0), 0),
      withdraw_channels: splitChannels(form.withdraw_channels_text),
    }
    const response = await adminAPI.updateAffiliateSettings(payload)
    const data = response.data?.data as AdminAffiliateSetting | undefined
    if (data) {
      form.enabled = Boolean(data.enabled)
      form.commission_rate = clampNumber(data.commission_rate, 0, 100, payload.commission_rate)
      form.confirm_days = clampNumber(data.confirm_days, 0, 3650, payload.confirm_days)
      form.min_withdraw_amount = Math.max(normalizeNumber(data.min_withdraw_amount, payload.min_withdraw_amount), 0)
      form.withdraw_channels_text = joinChannels(data.withdraw_channels)
    }
    notifySuccess(t('admin.settings.alerts.saveSuccess'))
  } catch (err: any) {
    notifyError(err?.response?.data?.message || t('admin.settings.alerts.saveFailed'))
  } finally {
    loading.value = false
  }
}

onMounted(fetchSettings)
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <h1 class="text-2xl font-semibold">{{ t('admin.settings.affiliate.title') }}</h1>
    </div>

    <div class="rounded-xl border border-border bg-card">
      <div class="border-b border-border bg-muted/40 px-6 py-4">
        <p class="text-sm text-muted-foreground">{{ t('admin.settings.affiliate.subtitle') }}</p>
      </div>
      <div class="space-y-6 p-6">
        <div class="flex flex-col gap-3 rounded-lg border border-border bg-muted/20 px-4 py-3 sm:flex-row sm:items-center">
          <Switch id="affiliate-enabled" v-model="form.enabled" />
          <Label for="affiliate-enabled" class="text-sm font-medium">{{ t('admin.settings.affiliate.enabled') }}</Label>
        </div>

        <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.affiliate.commissionRate') }}</label>
            <Input v-model.number="form.commission_rate" type="number" min="0" max="100" step="0.01" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.affiliate.commissionRateHint') }}</p>
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.affiliate.confirmDays') }}</label>
            <Input v-model.number="form.confirm_days" type="number" min="0" max="3650" step="1" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.affiliate.confirmDaysHint') }}</p>
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.affiliate.minWithdrawAmount') }}</label>
            <Input v-model.number="form.min_withdraw_amount" type="number" min="0" step="0.01" />
            <p class="text-xs text-muted-foreground">{{ t('admin.settings.affiliate.minWithdrawAmountHint') }}</p>
          </div>
        </div>

        <div class="space-y-2">
          <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.affiliate.withdrawChannels') }}</label>
          <Textarea
            v-model="form.withdraw_channels_text"
            rows="5"
            :placeholder="t('admin.settings.affiliate.withdrawChannelsPlaceholder')"
          />
          <p class="text-xs text-muted-foreground">{{ t('admin.settings.affiliate.withdrawChannelsHint') }}</p>
        </div>

        <div class="flex justify-end pt-2">
          <Button class="w-full sm:w-auto" @click="saveSettings" :disabled="loading">
            {{ t('admin.settings.actions.save') }}
          </Button>
        </div>
      </div>
    </div>
  </div>
</template>

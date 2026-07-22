<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminPaymentChannel } from '@/api/types'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { notifyError, notifySuccess } from '@/utils/notify'
import ComplianceGuardWrapper from '@/components/ComplianceGuardWrapper.vue'

const { t } = useI18n()

const form = reactive({
  recharge_channel_ids: [] as number[],
  wallet_only_payment: false,
})
const channels = ref<AdminPaymentChannel[]>([])
const saving = ref(false)

const loadConfig = async () => {
  try {
    const res = await adminAPI.getSettings({ key: 'wallet_config' })
    const data = res.data?.data
    if (data && Array.isArray(data.recharge_channel_ids)) {
      form.recharge_channel_ids = data.recharge_channel_ids.filter((id: unknown) => typeof id === 'number' && id > 0)
    } else {
      form.recharge_channel_ids = []
    }
    form.wallet_only_payment = !!data?.wallet_only_payment
  } catch {
    form.recharge_channel_ids = []
    form.wallet_only_payment = false
  }
}

const loadChannels = async () => {
  try {
    const res = await adminAPI.getPaymentChannels({ page: 1, page_size: 200 })
    channels.value = (res.data?.data ?? []).filter((ch: AdminPaymentChannel) => ch.is_active)
  } catch {
    channels.value = []
  }
}

const toggleChannel = (channelId: number) => {
  const idx = form.recharge_channel_ids.indexOf(channelId)
  if (idx >= 0) {
    form.recharge_channel_ids.splice(idx, 1)
  } else {
    form.recharge_channel_ids.push(channelId)
  }
}

const save = async () => {
  saving.value = true
  try {
    await adminAPI.updateSettings({
      key: 'wallet_config',
      value: {
        recharge_channel_ids: form.recharge_channel_ids,
        wallet_only_payment: form.wallet_only_payment,
      },
    } as any)
    notifySuccess(t('admin.settings.saved'))
  } catch (err: any) {
    notifyError(err?.message || t('admin.settings.saveFailed'))
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  loadConfig()
  loadChannels()
})
</script>

<template>
  <ComplianceGuardWrapper>
  <div class="space-y-6">
    <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
      <div>
        <h1 class="text-2xl font-semibold">{{ t('admin.settings.wallet.title') }}</h1>
        <p class="mt-1 text-sm text-muted-foreground">{{ t('admin.settings.wallet.subtitle') }}</p>
      </div>
    </div>

    <div class="rounded-xl border border-border bg-card">
      <div class="space-y-4 p-6">
        <div class="flex items-center justify-between">
          <div>
            <Label for="wallet-only-payment" class="text-sm font-medium">{{ t('admin.settings.wallet.walletOnlyPayment') }}</Label>
            <p class="text-xs text-muted-foreground mt-0.5">{{ t('admin.settings.wallet.walletOnlyPaymentTip') }}</p>
          </div>
          <Switch id="wallet-only-payment" v-model="form.wallet_only_payment" />
        </div>
        <div class="border-t border-border pt-4">
          <Label class="block text-xs font-medium text-muted-foreground mb-2">{{ t('admin.settings.wallet.rechargeChannels') }}</Label>
          <div v-if="channels.length > 0" class="flex flex-wrap gap-2">
            <Label v-for="ch in channels" :key="ch.id" class="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-xs cursor-pointer select-none" :class="form.recharge_channel_ids.includes(ch.id) ? 'bg-primary/10 border-primary text-primary' : 'text-muted-foreground hover:border-primary/40'">
              <Checkbox :model-value="form.recharge_channel_ids.includes(ch.id)" @update:model-value="() => toggleChannel(ch.id)" />
              {{ ch.name }}
            </Label>
          </div>
          <p v-else class="text-xs text-muted-foreground">{{ t('admin.settings.wallet.noChannels') }}</p>
          <p class="mt-1 text-xs text-muted-foreground">{{ t('admin.settings.wallet.rechargeChannelsTip') }}</p>
        </div>
        <div class="flex justify-end border-t border-border pt-4">
          <Button :disabled="saving" @click="save">
            {{ saving ? t('admin.settings.actions.saving') : t('admin.settings.actions.save') }}
          </Button>
        </div>
      </div>
    </div>
  </div>
  </ComplianceGuardWrapper>
</template>

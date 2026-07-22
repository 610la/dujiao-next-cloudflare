<template>
  <div class="rounded-2xl border bg-card p-7 shadow-sm">
    <PanelHeading :title="t('personalCenter.wallet.rechargeTitle')" :description="t('personalCenter.wallet.rechargeSubtitle')" :icon="CreditCard" />
    <form class="grid grid-cols-1 gap-4 md:grid-cols-[1fr_1fr_2fr_auto]" @submit.prevent="$emit('submit')">
      <div>
        <Label class="mb-2 block">{{ t('personalCenter.wallet.amountLabel') }}</Label>
        <Input
          :model-value="amount"
          @update:model-value="(v) => $emit('update:amount', String(v).trim())"
          type="text"
          inputmode="decimal"
          :placeholder="t('personalCenter.wallet.amountPlaceholder')"
          class="h-11"
        />
      </div>
      <div>
        <Label class="mb-2 block">{{ t('personalCenter.wallet.channelLabel') }}</Label>
        <Select
          :model-value="String(channelId)"
          @update:model-value="(v) => $emit('update:channelId', Number(v))"
          :disabled="!hasChannels || channelLoading || recharging"
        >
          <SelectTrigger class="h-11 w-full">
            <SelectValue :placeholder="t('personalCenter.wallet.channelPlaceholder')" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="0">{{ t('personalCenter.wallet.channelPlaceholder') }}</SelectItem>
            <SelectItem v-for="channel in channels" :key="channel.id" :value="String(channel.id)">
              {{ channel.name }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div>
        <Label class="mb-2 block">{{ t('personalCenter.wallet.remarkLabel') }}</Label>
        <Input
          :model-value="remark"
          @update:model-value="(v) => $emit('update:remark', String(v).trim())"
          type="text"
          :placeholder="t('personalCenter.wallet.remarkPlaceholder')"
          class="h-11"
        />
      </div>
      <div class="flex items-end">
        <Button
          type="submit"
          :disabled="recharging || channelLoading || !hasChannels"
          class="h-11 w-full font-bold"
        >
          {{ recharging ? t('personalCenter.wallet.recharging') : t('personalCenter.wallet.rechargeSubmit') }}
        </Button>
      </div>
    </form>
    <div v-if="selectedChannel" class="mt-4 grid grid-cols-1 gap-3 text-sm md:grid-cols-3">
      <div class="rounded-xl border p-4">
        <div class="text-xs text-muted-foreground">{{ t('payment.feeRateLabel') }}</div>
        <div class="mt-1 font-semibold text-foreground">{{ feeRateDisplay }}</div>
      </div>
      <div class="rounded-xl border p-4">
        <div class="text-xs text-muted-foreground">{{ t('payment.fixedFeeLabel') }}</div>
        <div class="mt-1 font-semibold text-foreground">{{ fixedFeeDisplay }}</div>
      </div>
      <div class="rounded-xl border p-4">
        <div class="text-xs text-muted-foreground">{{ t('payment.feeAmountLabel') }}</div>
        <div class="mt-1 font-semibold text-foreground">{{ feeAmountDisplay }}</div>
      </div>
    </div>
    <p v-if="channelLoading" class="mt-3 text-xs text-muted-foreground">
      {{ t('common.loading') }}
    </p>
    <p v-else-if="!hasChannels" class="mt-3 text-xs text-amber-600">
      {{ t('payment.channelEmpty') }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { CreditCard } from 'lucide-vue-next'
import PanelHeading from '../shared/PanelHeading.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

defineProps<{
  amount: string
  channelId: number
  remark: string
  channels: Array<{ id: number; name: string }>
  hasChannels: boolean
  channelLoading: boolean
  recharging: boolean
  selectedChannel: { id: number; name: string } | null
  feeRateDisplay: string
  fixedFeeDisplay: string
  feeAmountDisplay: string
}>()

defineEmits<{
  (e: 'submit'): void
  (e: 'update:amount', value: string): void
  (e: 'update:channelId', value: number): void
  (e: 'update:remark', value: string): void
}>()

const { t } = useI18n()
</script>

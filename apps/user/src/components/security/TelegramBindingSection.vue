<template>
  <div class="mb-6 rounded-2xl border p-4">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h3 class="text-base font-semibold text-foreground">{{ t('personalCenter.security.telegramTitle') }}</h3>
        <p class="mt-1 text-xs text-muted-foreground">
          {{ telegramEnabled ? t('personalCenter.security.telegramSubtitle') : t('personalCenter.security.telegramDisabledTip') }}
        </p>
      </div>
      <Badge :variant="telegramBound ? 'success' : 'warning'" size="sm">
        {{ telegramBound ? t('personalCenter.security.telegramBound') : t('personalCenter.security.telegramUnbound') }}
      </Badge>
    </div>

    <div v-if="loadingTelegramBinding" class="mt-4 rounded-xl border border-dashed px-4 py-4 text-sm text-muted-foreground">
      {{ t('personalCenter.security.telegramLoading') }}
    </div>

    <div v-else-if="telegramBound" class="mt-4 space-y-4 rounded-xl border bg-card p-4">
      <div class="flex items-center gap-3">
        <img
          v-if="avatarUrl"
          :src="avatarUrl"
          alt="Telegram Avatar"
          class="h-11 w-11 rounded-full border object-cover"
        />
        <div>
          <p class="text-sm font-semibold text-foreground">{{ telegramDisplayName }}</p>
          <p class="text-xs text-muted-foreground">{{ t('personalCenter.security.telegramBindID', { id: providerUserId }) }}</p>
        </div>
      </div>
      <p class="text-xs text-muted-foreground">
        {{ t('personalCenter.security.telegramBindTime', { time: formattedAuthAt }) }}
      </p>
      <Button
        type="button"
        variant="outline"
        size="sm"
        :disabled="unbindingTelegram || !canUnbindTelegram"
        @click="$emit('unbind')"
      >
        {{ unbindingTelegram ? t('personalCenter.security.telegramUnbinding') : t('personalCenter.security.telegramUnbind') }}
      </Button>
      <p v-if="!canUnbindTelegram" class="text-xs text-muted-foreground">
        {{ t('personalCenter.security.telegramUnbindDisabledTip') }}
      </p>
      <div v-if="showTelegramMiniAppEntry" class="space-y-2 rounded-xl border border-dashed px-4 py-3">
        <p class="text-xs text-muted-foreground">
          {{ t('personalCenter.security.telegramMiniAppEntryHint') }}
        </p>
        <Button
          type="button"
          variant="outline"
          size="sm"
          @click="$emit('openMiniAppEntry')"
        >
          {{ t('personalCenter.security.telegramMiniAppEntryAction') }}
        </Button>
      </div>
    </div>

    <div v-else class="mt-4 space-y-3">
      <p class="text-xs text-muted-foreground">
        {{
          telegramEnabled
            ? (showMiniAppBindAction ? t('personalCenter.security.telegramMiniAppBindHint') : t('personalCenter.security.telegramUnboundTip'))
            : t('personalCenter.security.telegramDisabledTip')
        }}
      </p>
      <Button
        v-if="showMiniAppBindAction"
        type="button"
        :disabled="bindingTelegram || miniAppInitData === ''"
        @click="$emit('miniAppBind')"
      >
        {{
          bindingTelegram
            ? t('personalCenter.security.telegramMiniAppBinding')
            : t('personalCenter.security.telegramMiniAppBindAction')
        }}
      </Button>
      <div v-else-if="showTelegramWidget" ref="telegramWidgetRef" class="flex justify-start"></div>
      <div v-else-if="showTelegramOidcBind" class="space-y-2">
        <Button
          type="button"
          :disabled="bindingTelegram"
          @click="$emit('oidcBind')"
        >
          {{ t('personalCenter.security.telegramOidcBindButton') }}
        </Button>
        <p class="text-xs text-muted-foreground">
          {{ t('personalCenter.security.telegramOidcBindHint') }}
        </p>
      </div>
      <div v-if="showTelegramMiniAppEntry" class="space-y-2 rounded-xl border border-dashed px-4 py-3">
        <p class="text-xs text-muted-foreground">
          {{ t('personalCenter.security.telegramMiniAppEntryHint') }}
        </p>
        <Button
          type="button"
          variant="outline"
          size="sm"
          @click="$emit('openMiniAppEntry')"
        >
          {{ t('personalCenter.security.telegramMiniAppEntryAction') }}
        </Button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'

const { t } = useI18n()

defineProps<{
  telegramEnabled: boolean
  telegramBound: boolean
  loadingTelegramBinding: boolean
  avatarUrl: string
  telegramDisplayName: string
  providerUserId: string
  formattedAuthAt: string
  unbindingTelegram: boolean
  canUnbindTelegram: boolean
  showTelegramMiniAppEntry: boolean
  showMiniAppBindAction: boolean
  showTelegramWidget: boolean
  showTelegramOidcBind?: boolean
  bindingTelegram: boolean
  miniAppInitData: string
}>()

defineEmits<{
  unbind: []
  miniAppBind: []
  openMiniAppEntry: []
  oidcBind: []
}>()

const telegramWidgetRef = ref<HTMLDivElement | null>(null)

defineExpose({ telegramWidgetRef })
</script>

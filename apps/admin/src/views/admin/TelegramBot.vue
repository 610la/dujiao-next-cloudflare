<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminTelegramBotRuntimeStatus } from '@/api/types'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { formatDate } from '@/utils/format'
import { Bot, ExternalLink, Wifi, WifiOff, RefreshCw, Send, KeyRound, ShieldAlert } from 'lucide-vue-next'

const LICENSE_PURCHASE_URL = 'https://dujiao-next.com/services/telegram-bot'

const { t } = useI18n()

const loading = ref(false)
const runtimeStatus = ref<AdminTelegramBotRuntimeStatus | null>(null)

const isConnected = computed(() => {
  if (!runtimeStatus.value) return false
  return runtimeStatus.value.connected === true
})

const fetchRuntimeStatus = async () => {
  loading.value = true
  try {
    const res = await adminAPI.getTelegramBotRuntimeStatus()
    runtimeStatus.value = res.data?.data ?? null
  } catch {
    runtimeStatus.value = null
  } finally {
    loading.value = false
  }
}

const formatRuntimeDate = (value: unknown) => {
  if (typeof value !== 'string' || !value) return '-'
  return formatDate(value) || '-'
}

const formatWebhookStatus = (value?: string) => {
  if (!value) return '-'
  const normalized = value.trim().toLowerCase()
  if (['active', 'enabled', 'connected', 'ok'].includes(normalized)) {
    return t('telegramBot.status.webhookStatusActive')
  }
  if (['inactive', 'disabled', 'disconnected'].includes(normalized)) {
    return t('telegramBot.status.webhookStatusInactive')
  }
  return value
}

const formatLicenseStatus = (value?: string) => {
  if (!value) return t('telegramBot.status.licenseStatusUnknown')
  const normalized = value.trim().toLowerCase()
  if (normalized === 'active') return t('telegramBot.status.licenseStatusActive')
  if (normalized === 'expired') return t('telegramBot.status.licenseStatusExpired')
  if (normalized === 'revoked') return t('telegramBot.status.licenseStatusRevoked')
  if (normalized === 'suspended') return t('telegramBot.status.licenseStatusSuspended')
  if (normalized === 'inactive') return t('telegramBot.status.licenseStatusInactive')
  return value
}

const formatWarnings = (warnings?: string[]) => {
  if (!warnings?.length) return t('telegramBot.status.licenseWarningsEmpty')
  return warnings
    .map((warning) => {
      const normalized = warning.trim().toLowerCase()
      if (normalized === 'license_lease_expiring_soon') {
        return t('telegramBot.status.warningLeaseExpiringSoon')
      }
      if (normalized === 'license_lease_expired') {
        return t('telegramBot.status.warningLeaseExpired')
      }
      return warning
    })
    .join(' / ')
}

onMounted(() => {
  fetchRuntimeStatus()
})
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold tracking-tight">{{ t('telegramBot.overview.title') }}</h2>
      <p class="text-muted-foreground">{{ t('telegramBot.overview.subtitle') }}</p>
    </div>

    <!-- License Purchase Notice -->
    <Card class="border-amber-200 bg-amber-50/60 dark:border-amber-900/40 dark:bg-amber-950/20">
      <CardContent class="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between sm:p-5">
        <div class="flex items-start gap-3">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-amber-100 text-amber-700 dark:bg-amber-900/50 dark:text-amber-300">
            <KeyRound class="h-5 w-5" />
          </div>
          <div class="space-y-1.5">
            <p class="text-sm font-semibold text-amber-900 dark:text-amber-200">{{ t('telegramBot.licensePurchase.title') }}</p>
            <p class="text-sm text-amber-800/80 dark:text-amber-200/80">{{ t('telegramBot.licensePurchase.desc') }}</p>
            <p class="flex items-start gap-1.5 text-xs text-red-700 dark:text-red-300">
              <ShieldAlert class="mt-0.5 h-3.5 w-3.5 shrink-0" />
              <span>{{ t('telegramBot.licensePurchase.securityNote') }}</span>
            </p>
          </div>
        </div>
        <Button as-child size="sm" class="w-full bg-amber-600 hover:bg-amber-700 sm:w-auto">
          <a :href="LICENSE_PURCHASE_URL" target="_blank" rel="noopener noreferrer">
            {{ t('telegramBot.licensePurchase.action') }}
            <ExternalLink class="ml-1.5 h-3.5 w-3.5" />
          </a>
        </Button>
      </CardContent>
    </Card>

    <!-- Connection Status Card -->
    <Card>
      <CardHeader>
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-3">
            <Bot class="h-8 w-8 text-primary" />
            <div>
              <CardTitle>{{ t('telegramBot.overview.connectionTitle') }}</CardTitle>
              <CardDescription>{{ t('telegramBot.overview.connectionDesc') }}</CardDescription>
            </div>
          </div>
          <Badge :variant="isConnected ? 'default' : 'secondary'" class="w-fit">
            <component :is="isConnected ? Wifi : WifiOff" class="h-3 w-3 mr-1" />
            {{ isConnected ? t('telegramBot.overview.connected') : t('telegramBot.overview.notConnected') }}
          </Badge>
        </div>
      </CardHeader>
      <CardContent>
        <div v-if="isConnected && runtimeStatus" class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          <div>
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.botVersion') }}</p>
            <p class="text-sm font-medium">{{ runtimeStatus.bot_version || '-' }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.webhookStatus') }}</p>
            <p class="text-sm font-medium">{{ formatWebhookStatus(runtimeStatus.webhook_status) }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.lastSeenAt') }}</p>
            <p class="text-sm font-medium">{{ formatRuntimeDate(runtimeStatus.last_seen_at) }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.configVersion') }}</p>
            <p class="text-sm font-medium">{{ runtimeStatus.config_version ?? '-' }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.machineCode') }}</p>
            <p class="text-sm font-medium break-all font-mono">{{ runtimeStatus.machine_code || '-' }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.licenseStatusLabel') }}</p>
            <p class="text-sm font-medium">{{ formatLicenseStatus(runtimeStatus.license_status) }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.licenseExpiresAt') }}</p>
            <p class="text-sm font-medium">{{ formatRuntimeDate(runtimeStatus.license_expires_at) }}</p>
          </div>
          <div class="md:col-span-2 xl:col-span-3">
            <p class="text-sm text-muted-foreground">{{ t('telegramBot.status.licenseWarnings') }}</p>
            <p class="text-sm font-medium">{{ formatWarnings(runtimeStatus.warnings) }}</p>
          </div>
        </div>
        <div v-else class="rounded-lg border border-dashed p-6 text-center">
          <WifiOff class="h-10 w-10 mx-auto text-muted-foreground mb-3" />
          <p class="text-sm text-muted-foreground mb-1">{{ t('telegramBot.overview.notConnectedHint') }}</p>
          <p class="text-xs text-muted-foreground">{{ t('telegramBot.overview.notConnectedDesc') }}</p>
        </div>
      </CardContent>
    </Card>

    <!-- Feature Overview -->
    <div class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
      <Card>
        <CardHeader>
          <CardTitle class="text-base">{{ t('telegramBot.overview.featureBasicSettings') }}</CardTitle>
        </CardHeader>
        <CardContent>
          <p class="text-sm text-muted-foreground">{{ t('telegramBot.overview.featureBasicSettingsDesc') }}</p>
          <Button variant="link" class="px-0 mt-2" as-child>
            <RouterLink to="/telegram-bot/settings">
              {{ t('telegramBot.overview.goToSettings') }}
              <ExternalLink class="h-3 w-3 ml-1" />
            </RouterLink>
          </Button>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle class="text-base">{{ t('telegramBot.overview.featureConnectionStatus') }}</CardTitle>
        </CardHeader>
        <CardContent>
          <p class="text-sm text-muted-foreground">{{ t('telegramBot.overview.featureConnectionStatusDesc') }}</p>
          <Button variant="link" class="px-0 mt-2" as-child>
            <RouterLink to="/telegram-bot/status">
              {{ t('telegramBot.overview.goToStatus') }}
              <ExternalLink class="h-3 w-3 ml-1" />
            </RouterLink>
          </Button>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle class="text-base">{{ t('telegramBot.overview.featureChannelClients') }}</CardTitle>
        </CardHeader>
        <CardContent>
          <p class="text-sm text-muted-foreground">{{ t('telegramBot.overview.featureChannelClientsDesc') }}</p>
          <Button variant="link" class="px-0 mt-2" as-child>
            <RouterLink to="/telegram-bot/channel-clients">
              {{ t('telegramBot.overview.goToChannelClients') }}
              <ExternalLink class="h-3 w-3 ml-1" />
            </RouterLink>
          </Button>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle class="text-base">{{ t('telegramBot.overview.featureBroadcasts') }}</CardTitle>
        </CardHeader>
        <CardContent>
          <p class="text-sm text-muted-foreground">{{ t('telegramBot.overview.featureBroadcastsDesc') }}</p>
          <Button variant="link" class="px-0 mt-2" as-child>
            <RouterLink to="/telegram-bot/broadcasts">
              {{ t('telegramBot.overview.goToBroadcasts') }}
              <ExternalLink class="h-3 w-3 ml-1" />
            </RouterLink>
          </Button>
        </CardContent>
      </Card>
    </div>

    <!-- Quick Actions -->
    <Card>
      <CardHeader>
        <CardTitle>{{ t('telegramBot.overview.quickActions') }}</CardTitle>
      </CardHeader>
      <CardContent class="flex flex-col gap-3 sm:flex-row">
        <Button variant="outline" size="sm" class="w-full sm:w-auto" :disabled="loading" @click="fetchRuntimeStatus">
          <RefreshCw class="h-4 w-4 mr-2" :class="{ 'animate-spin': loading }" />
          {{ t('telegramBot.overview.refreshStatus') }}
        </Button>
        <Button variant="outline" size="sm" class="w-full sm:w-auto" as-child>
          <RouterLink to="/telegram-bot/broadcasts/create">
            <Send class="h-4 w-4 mr-2" />
            {{ t('telegramBot.overview.createBroadcast') }}
          </RouterLink>
        </Button>
      </CardContent>
    </Card>
  </div>
</template>

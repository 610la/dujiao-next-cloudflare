<template>
  <div class="rounded-2xl border bg-card p-7 shadow-sm">
    <div class="mb-4 flex items-center justify-between">
      <h3 class="text-lg font-bold text-foreground">{{ t('personalCenter.security.loginLogsTitle') }}</h3>
      <span class="text-xs text-muted-foreground">{{ t('personalCenter.security.loginLogsTip') }}</span>
    </div>
    <div v-if="loading" class="rounded-xl border px-4 py-6 text-center text-sm text-muted-foreground">
      {{ t('personalCenter.security.loginLogsLoading') }}
    </div>
    <div v-else-if="logs.length === 0" class="rounded-xl border border-dashed px-4 py-6 text-center text-sm text-muted-foreground">
      {{ t('personalCenter.security.loginLogsEmpty') }}
    </div>
    <div v-else class="overflow-x-auto rounded-xl border">
      <Table>
        <TableHeader>
          <TableRow class="bg-muted/50">
            <TableHead class="px-4">{{ t('personalCenter.security.loginLogsTime') }}</TableHead>
            <TableHead class="px-4">{{ t('personalCenter.security.loginLogsStatus') }}</TableHead>
            <TableHead class="px-4">{{ t('personalCenter.security.loginLogsIp') }}</TableHead>
            <TableHead class="px-4">{{ t('personalCenter.security.loginLogsReason') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-for="item in logs" :key="item.id">
            <TableCell class="px-4 text-muted-foreground">{{ formatDate(item.created_at) }}</TableCell>
            <TableCell class="px-4">
              <Badge size="sm" :variant="loginStatusVariant(item.status)">
                {{ loginStatusLabel(item.status) }}
              </Badge>
            </TableCell>
            <TableCell class="px-4 font-mono text-xs text-muted-foreground">{{ item.client_ip || '-' }}</TableCell>
            <TableCell class="px-4 text-xs text-muted-foreground">{{ loginReasonLabel(item.fail_reason) }}</TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import type { UserLoginLogItem } from '../../api/types'
import { formatSiteDateTime } from '../../utils/time'
import { Badge } from '@/components/ui/badge'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

const { t } = useI18n()

defineProps<{
  loading: boolean
  logs: UserLoginLogItem[]
}>()

const loginStatusLabel = (status?: string) => {
  const normalized = (status || '').trim() || 'failed'
  return t(`personalCenter.security.loginLogsStatusMap.${normalized}`)
}

const loginStatusVariant = (status?: string): 'success' | 'destructive' => {
  return (status || '').trim() === 'success' ? 'success' : 'destructive'
}

const loginReasonLabel = (reason?: string) => {
  const normalized = (reason || '').trim()
  if (!normalized) return '-'
  const key = `personalCenter.security.loginLogsReasonMap.${normalized}`
  const translated = t(key)
  return translated === key ? normalized : translated
}

const formatDate = (raw?: string | null) => {
  return formatSiteDateTime(raw)
}
</script>

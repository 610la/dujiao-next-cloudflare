<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RefreshCw } from 'lucide-vue-next'
import { adminAPI } from '@/api/admin'
import type {
  AdminResellerOperationsAlert,
  AdminResellerOperationsFinance,
  AdminResellerOperationsOverview,
} from '@/api/types'
import { useAdminAuthStore } from '@/stores/auth'
import ComplianceGuardWrapper from '@/components/ComplianceGuardWrapper.vue'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatDate, formatMoney, toRFC3339 } from '@/utils/format'
import {
  buildResellerOperationsAlertClass,
  formatResellerOperationsPeriod,
  hasFinancePermission,
  normalizeCurrencyRows,
} from '@/utils/resellerOperations'

const { t } = useI18n()
const authStore = useAdminAuthStore()

const overview = ref<AdminResellerOperationsOverview | null>(null)
const finance = ref<AdminResellerOperationsFinance | null>(null)
const loadingOverview = ref(false)
const loadingFinance = ref(false)
const pageError = ref('')
const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Shanghai'

const filters = reactive({
  range: '7d',
  from: '',
  to: '',
})

const canViewFinance = computed(() => hasFinancePermission((permission) => authStore.hasPermission(permission)))

const periodCurrencyRows = computed(() => normalizeCurrencyRows(finance.value?.period_currency_rows))
const currentCurrencyRows = computed(() => normalizeCurrencyRows(finance.value?.current_currency_rows))

const lifecycleKpis = computed(() => {
  const row = overview.value?.lifecycle
  return [
    { label: t('admin.resellerOperations.kpi.profilesTotal'), value: row?.profiles_total ?? 0 },
    { label: t('admin.resellerOperations.kpi.profilesPendingReview'), value: row?.profiles_pending_review ?? 0 },
    { label: t('admin.resellerOperations.kpi.profilesActive'), value: row?.profiles_active ?? 0 },
    { label: t('admin.resellerOperations.kpi.profilesSettlementFrozen'), value: row?.profiles_settlement_frozen ?? 0 },
    { label: t('admin.resellerOperations.kpi.domainsTotal'), value: row?.domains_total ?? 0 },
    { label: t('admin.resellerOperations.kpi.domainsPendingReview'), value: row?.domains_pending_review ?? 0 },
    { label: t('admin.resellerOperations.kpi.domainsActive'), value: row?.domains_active ?? 0 },
    { label: t('admin.resellerOperations.kpi.activeWithoutSiteConfig'), value: row?.active_profiles_without_site_config ?? 0 },
  ]
})

const orderKpis = computed(() => {
  const row = overview.value?.orders
  return [
    { label: t('admin.resellerOperations.kpi.ordersTotal'), value: row?.orders_total ?? 0 },
    { label: t('admin.resellerOperations.kpi.paidOrders'), value: row?.paid_orders ?? 0 },
    { label: t('admin.resellerOperations.kpi.completedOrders'), value: row?.completed_orders ?? 0 },
    { label: t('admin.resellerOperations.kpi.refundedOrders'), value: row?.refunded_orders ?? 0 },
    { label: t('admin.resellerOperations.kpi.selfDealingBlockedOrders'), value: row?.self_dealing_blocked_orders ?? 0 },
    { label: t('admin.resellerOperations.kpi.activeResellersWithOrders'), value: row?.active_resellers_with_orders ?? 0 },
    { label: t('admin.resellerOperations.kpi.averagePaidOrders'), value: row?.average_paid_orders_per_active_reseller ?? '0.00' },
  ]
})

const buildParams = () => {
  const params: Record<string, unknown> = {
    range: filters.range,
    tz: browserTimezone,
  }
  const from = toRFC3339(filters.from)
  const to = toRFC3339(filters.to)
  if (from) params.from = from
  if (to) params.to = to
  return params
}

const ensureCustomRange = () => {
  if (filters.range !== 'custom') return true
  if (toRFC3339(filters.from) && toRFC3339(filters.to)) return true
  pageError.value = t('admin.resellerOperations.errors.customRangeRequired')
  return false
}

const loadOverview = async () => {
  loadingOverview.value = true
  try {
    const response = await adminAPI.getResellerOperationsOverview(buildParams())
    overview.value = response.data.data as AdminResellerOperationsOverview
  } catch (err: any) {
    pageError.value = err?.message || t('admin.resellerOperations.errors.loadFailed')
    overview.value = null
  } finally {
    loadingOverview.value = false
  }
}

const loadFinance = async () => {
  if (!canViewFinance.value) {
    finance.value = null
    return
  }
  loadingFinance.value = true
  try {
    const response = await adminAPI.getResellerOperationsFinance(buildParams())
    finance.value = response.data.data as AdminResellerOperationsFinance
  } catch (err: any) {
    pageError.value = err?.message || t('admin.resellerOperations.errors.loadFailed')
    finance.value = null
  } finally {
    loadingFinance.value = false
  }
}

const loadAll = async () => {
  if (!ensureCustomRange()) return
  pageError.value = ''
  await loadOverview()
  await loadFinance()
}

const alertLabel = (item: AdminResellerOperationsAlert) =>
  t(`admin.resellerOperations.alerts.${item.type}`)

const money = (amount?: string | number, currency?: string) => formatMoney(amount, currency)

onMounted(() => {
  loadAll()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 xl:flex-row xl:items-end xl:justify-between">
      <div>
        <h1 class="text-2xl font-semibold tracking-normal">{{ t('admin.resellerOperations.title') }}</h1>
        <p class="mt-1 text-sm text-muted-foreground">{{ t('admin.resellerOperations.subtitle') }}</p>
      </div>
      <div class="rounded-xl border border-border bg-card p-3 shadow-sm">
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-[150px_190px_190px_auto] lg:items-end">
          <div>
            <div class="mb-1 text-xs text-muted-foreground">{{ t('admin.resellerOperations.filters.range') }}</div>
            <Select v-model="filters.range">
              <SelectTrigger class="h-9 w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="today">{{ t('admin.resellerOperations.filters.today') }}</SelectItem>
                <SelectItem value="7d">{{ t('admin.resellerOperations.filters.last7Days') }}</SelectItem>
                <SelectItem value="30d">{{ t('admin.resellerOperations.filters.last30Days') }}</SelectItem>
                <SelectItem value="custom">{{ t('admin.resellerOperations.filters.custom') }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <div class="mb-1 text-xs text-muted-foreground">{{ t('admin.resellerOperations.filters.from') }}</div>
            <Input v-model="filters.from" type="datetime-local" class="h-9" />
          </div>
          <div>
            <div class="mb-1 text-xs text-muted-foreground">{{ t('admin.resellerOperations.filters.to') }}</div>
            <Input v-model="filters.to" type="datetime-local" class="h-9" />
          </div>
          <Button size="sm" :disabled="loadingOverview || loadingFinance" @click="loadAll">
            <RefreshCw class="size-4" :class="{ 'animate-spin': loadingOverview || loadingFinance }" />
            {{ t('admin.resellerOperations.actions.refresh') }}
          </Button>
        </div>
      </div>
    </div>

    <div v-if="pageError" class="rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
      {{ pageError }}
    </div>

    <section class="space-y-3">
      <div class="flex items-center justify-between">
        <h2 class="text-base font-semibold">{{ t('admin.resellerOperations.sections.lifecycle') }}</h2>
        <span v-if="overview" class="font-mono text-xs text-muted-foreground">{{ formatResellerOperationsPeriod(overview.from, overview.to) }}</span>
      </div>
      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card v-for="item in lifecycleKpis" :key="item.label" class="rounded-lg">
          <CardHeader class="pb-2">
            <CardTitle class="text-xs font-medium text-muted-foreground">{{ item.label }}</CardTitle>
          </CardHeader>
          <CardContent>
            <div class="font-mono text-2xl font-semibold">{{ loadingOverview ? '-' : item.value }}</div>
          </CardContent>
        </Card>
      </div>
    </section>

    <section class="space-y-3">
      <h2 class="text-base font-semibold">{{ t('admin.resellerOperations.sections.orders') }}</h2>
      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card v-for="item in orderKpis" :key="item.label" class="rounded-lg">
          <CardHeader class="pb-2">
            <CardTitle class="text-xs font-medium text-muted-foreground">{{ item.label }}</CardTitle>
          </CardHeader>
          <CardContent>
            <div class="font-mono text-2xl font-semibold">{{ loadingOverview ? '-' : item.value }}</div>
          </CardContent>
        </Card>
      </div>
    </section>

    <section class="space-y-3">
      <h2 class="text-base font-semibold">{{ t('admin.resellerOperations.sections.alerts') }}</h2>
      <div v-if="overview?.alerts?.length" class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <div
          v-for="item in overview.alerts"
          :key="item.type"
          class="rounded-lg border px-4 py-3 text-sm"
          :class="buildResellerOperationsAlertClass(item.level)"
        >
          <div class="font-medium">{{ alertLabel(item) }}</div>
          <div class="mt-1 font-mono text-xl font-semibold">{{ item.value }}</div>
        </div>
      </div>
      <div v-else class="rounded-lg border border-border bg-muted/20 px-4 py-6 text-center text-sm text-muted-foreground">
        {{ t('admin.resellerOperations.empty.alerts') }}
      </div>
    </section>

    <section class="space-y-3">
      <h2 class="text-base font-semibold">{{ t('admin.resellerOperations.sections.topResellers') }}</h2>
      <div class="overflow-x-auto rounded-xl border border-border bg-card">
        <Table class="min-w-[860px]">
          <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
            <TableRow>
              <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.reseller') }}</TableHead>
              <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.ordersTotal') }}</TableHead>
              <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.paidOrders') }}</TableHead>
              <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.activeDomains') }}</TableHead>
              <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.siteConfigured') }}</TableHead>
              <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.lastOrderAt') }}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-if="!overview?.top_resellers?.length">
              <TableCell colspan="6" class="px-5 py-8 text-center text-sm text-muted-foreground">
                {{ t('admin.resellerOperations.empty.topResellers') }}
              </TableCell>
            </TableRow>
            <TableRow v-for="item in overview?.top_resellers || []" :key="item.reseller_id" class="hover:bg-muted/30">
              <TableCell class="px-5 py-4">
                <div class="font-medium">{{ item.display_name || item.email || `#${item.reseller_id}` }}</div>
                <div class="mt-1 font-mono text-xs text-muted-foreground">#{{ item.reseller_id }} / U{{ item.user_id }}</div>
              </TableCell>
              <TableCell class="px-5 py-4 font-mono text-sm">{{ item.orders_total }}</TableCell>
              <TableCell class="px-5 py-4 font-mono text-sm">{{ item.paid_orders }}</TableCell>
              <TableCell class="px-5 py-4 font-mono text-sm">{{ item.active_domains }}</TableCell>
              <TableCell class="px-5 py-4 text-sm">
                {{ item.site_configured ? t('admin.common.yes') : t('admin.common.no') }}
              </TableCell>
              <TableCell class="px-5 py-4 text-sm text-muted-foreground">{{ formatDate(item.last_order_at) || '-' }}</TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </div>
    </section>

    <ComplianceGuardWrapper v-if="canViewFinance">
      <section class="space-y-3">
        <h2 class="text-base font-semibold">{{ t('admin.resellerOperations.sections.financePeriod') }}</h2>
        <div class="overflow-x-auto rounded-xl border border-border bg-card">
          <Table class="min-w-[860px]">
            <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
              <TableRow>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.currency') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.ordersTotal') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.paidOrders') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.gmvPaid') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.profitEarned') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.refundDeducted') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.withdrawPaid') }}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-if="periodCurrencyRows.length === 0">
                <TableCell colspan="7" class="px-5 py-8 text-center text-sm text-muted-foreground">
                  {{ loadingFinance ? t('admin.common.loading') : t('admin.resellerOperations.empty.financeRows') }}
                </TableCell>
              </TableRow>
              <TableRow v-for="item in periodCurrencyRows" :key="item.currency" class="hover:bg-muted/30">
                <TableCell class="px-5 py-4 font-mono text-sm font-semibold">{{ item.currency }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ item.orders_total }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ item.paid_orders }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ money(item.gmv_paid, item.currency) }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ money(item.profit_earned, item.currency) }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ money(item.refund_deducted, item.currency) }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ money(item.withdraw_paid, item.currency) }}</TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
      </section>

      <section class="space-y-3">
        <h2 class="text-base font-semibold">{{ t('admin.resellerOperations.sections.financeCurrent') }}</h2>
        <div class="overflow-x-auto rounded-xl border border-border bg-card">
          <Table class="min-w-[860px]">
            <TableHeader class="border-b border-border bg-muted/40 text-xs uppercase text-muted-foreground">
              <TableRow>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.currency') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.availableBalance') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.lockedBalance') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.negativeBalance') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.pendingWithdraw') }}</TableHead>
                <TableHead class="px-5 py-3">{{ t('admin.resellerOperations.table.abnormalAccounts') }}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-if="currentCurrencyRows.length === 0">
                <TableCell colspan="6" class="px-5 py-8 text-center text-sm text-muted-foreground">
                  {{ loadingFinance ? t('admin.common.loading') : t('admin.resellerOperations.empty.financeRows') }}
                </TableCell>
              </TableRow>
              <TableRow v-for="item in currentCurrencyRows" :key="item.currency" class="hover:bg-muted/30">
                <TableCell class="px-5 py-4 font-mono text-sm font-semibold">{{ item.currency }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ money(item.available_balance, item.currency) }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ money(item.locked_balance, item.currency) }}</TableCell>
                <TableCell class="px-5 py-4 font-mono text-sm">{{ money(item.negative_balance, item.currency) }}</TableCell>
                <TableCell class="px-5 py-4 text-sm">
                  <div class="font-mono">{{ money(item.pending_withdraw_amount, item.currency) }}</div>
                  <div class="mt-1 text-xs text-muted-foreground">
                    {{ t('admin.resellerOperations.finance.pendingWithdrawCount', { count: item.pending_withdraw_count }) }}
                  </div>
                </TableCell>
                <TableCell class="px-5 py-4 text-xs text-muted-foreground">
                  <div>{{ t('admin.resellerOperations.finance.negativeBalanceAccounts', { count: item.negative_balance_accounts }) }}</div>
                  <div class="mt-1">{{ t('admin.resellerOperations.finance.frozenBalanceAccounts', { count: item.frozen_balance_accounts }) }}</div>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
      </section>
    </ComplianceGuardWrapper>

    <div v-else class="rounded-lg border border-border bg-muted/20 px-4 py-6 text-center text-sm text-muted-foreground">
      {{ t('admin.resellerOperations.finance.noPermission') }}
    </div>
  </div>
</template>

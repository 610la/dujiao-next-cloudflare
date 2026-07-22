<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminTelegramBroadcast } from '@/api/types'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatDate, toRFC3339 } from '@/utils/format'
import { confirmAction } from '@/utils/confirm'
import { notifyError, notifySuccess } from '@/utils/notify'
import { Eye, Loader2, Send, Trash2 } from 'lucide-vue-next'

const { t } = useI18n()

const loading = ref(false)
const items = ref<AdminTelegramBroadcast[]>([])
const deletingId = ref<number | null>(null)
const pagination = ref({
  page: 1,
  page_size: 20,
  total: 0,
  total_page: 1,
})
const filters = reactive({
  keyword: '',
  recipientType: '__all__',
  status: '__all__',
  createdFrom: '',
  createdTo: '',
})

const normalizeFilterValue = (value: string) => (value === '__all__' ? '' : value)

const fetchBroadcasts = async (page = 1) => {
  loading.value = true
  try {
    const res = await adminAPI.getTelegramBroadcasts({
      page,
      page_size: pagination.value.page_size,
      keyword: filters.keyword || undefined,
      recipient_type: normalizeFilterValue(filters.recipientType) || undefined,
      status: normalizeFilterValue(filters.status) || undefined,
      created_from: toRFC3339(filters.createdFrom),
      created_to: toRFC3339(filters.createdTo),
    })
    items.value = res.data?.data || []
    pagination.value = res.data?.pagination || pagination.value
  } catch {
    items.value = []
  } finally {
    loading.value = false
  }
}

const formatRecipientType = (value: string) =>
  value === 'specific' ? t('telegramBot.broadcasts.recipientTypeSpecific') : t('telegramBot.broadcasts.recipientTypeAll')

const formatStatus = (value: string) => {
  const normalized = String(value || '').trim().toLowerCase()
  if (normalized === 'running') return t('telegramBot.broadcasts.statusRunning')
  if (normalized === 'completed') return t('telegramBot.broadcasts.statusCompleted')
  if (normalized === 'failed') return t('telegramBot.broadcasts.statusFailed')
  return t('telegramBot.broadcasts.statusPending')
}

const changePage = (page: number) => {
  if (page < 1 || page > pagination.value.total_page || page === pagination.value.page) return
  fetchBroadcasts(page)
}

const handleSearch = () => {
  fetchBroadcasts(1)
}

const resetFilters = () => {
  filters.keyword = ''
  filters.recipientType = '__all__'
  filters.status = '__all__'
  filters.createdFrom = ''
  filters.createdTo = ''
  fetchBroadcasts(1)
}

const canDelete = (item: AdminTelegramBroadcast) => {
  const normalized = String(item.status || '').trim().toLowerCase()
  return normalized === 'completed' || normalized === 'failed'
}

const handleDelete = async (item: AdminTelegramBroadcast) => {
  if (!canDelete(item)) return
  const confirmed = await confirmAction({
    description: t('telegramBot.broadcasts.deleteConfirm', { title: item.title }),
    confirmText: t('telegramBot.broadcasts.delete'),
    variant: 'destructive',
  })
  if (!confirmed) return

  deletingId.value = item.id
  try {
    await adminAPI.deleteTelegramBroadcast(item.id)
    notifySuccess(t('telegramBot.broadcasts.deleteSuccess'))
    const nextPage = items.value.length === 1 && pagination.value.page > 1 ? pagination.value.page - 1 : pagination.value.page
    await fetchBroadcasts(nextPage)
  } catch (err: any) {
    notifyError(err?.response?.data?.message || err?.message || t('telegramBot.broadcasts.deleteFailed'))
  } finally {
    deletingId.value = null
  }
}

onMounted(() => {
  fetchBroadcasts()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2 class="text-2xl font-bold tracking-tight">{{ t('telegramBot.broadcasts.title') }}</h2>
        <p class="text-muted-foreground">{{ t('telegramBot.broadcasts.subtitle') }}</p>
      </div>
      <Button class="w-full sm:w-auto" as-child>
        <RouterLink to="/telegram-bot/broadcasts/create">
          <Send class="h-4 w-4 mr-2" />
          {{ t('telegramBot.broadcasts.create') }}
        </RouterLink>
      </Button>
    </div>

    <Card>
      <CardContent class="space-y-4 p-4">
        <div class="flex flex-wrap items-center gap-3">
          <div class="w-full md:w-56">
            <Input v-model="filters.keyword" :placeholder="t('telegramBot.broadcasts.filterTitleKeyword')" @keyup.enter="handleSearch" />
          </div>
          <div class="w-full md:w-40">
            <Select v-model="filters.recipientType">
              <SelectTrigger class="w-full">
                <SelectValue :placeholder="t('telegramBot.broadcasts.filterRecipientTypeAll')" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__all__">{{ t('telegramBot.broadcasts.filterRecipientTypeAll') }}</SelectItem>
                <SelectItem value="all">{{ t('telegramBot.broadcasts.recipientTypeAll') }}</SelectItem>
                <SelectItem value="specific">{{ t('telegramBot.broadcasts.recipientTypeSpecific') }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="w-full md:w-40">
            <Select v-model="filters.status">
              <SelectTrigger class="w-full">
                <SelectValue :placeholder="t('telegramBot.broadcasts.filterStatusAll')" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__all__">{{ t('telegramBot.broadcasts.filterStatusAll') }}</SelectItem>
                <SelectItem value="pending">{{ t('telegramBot.broadcasts.statusPending') }}</SelectItem>
                <SelectItem value="running">{{ t('telegramBot.broadcasts.statusRunning') }}</SelectItem>
                <SelectItem value="completed">{{ t('telegramBot.broadcasts.statusCompleted') }}</SelectItem>
                <SelectItem value="failed">{{ t('telegramBot.broadcasts.statusFailed') }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="w-full md:w-48">
            <Input v-model="filters.createdFrom" type="datetime-local" />
          </div>
          <div class="w-full md:w-48">
            <Input v-model="filters.createdTo" type="datetime-local" />
          </div>
          <Button size="sm" class="w-full sm:w-auto" @click="handleSearch">{{ t('telegramBot.broadcasts.search') }}</Button>
          <Button variant="outline" size="sm" class="w-full sm:w-auto" @click="resetFilters">{{ t('telegramBot.broadcasts.resetFilters') }}</Button>
        </div>
        <div class="overflow-x-auto">
          <Table class="min-w-[920px]">
            <TableHeader>
              <TableRow>
                <TableHead>ID</TableHead>
                <TableHead class="min-w-[200px]">{{ t('telegramBot.broadcasts.tableTitle') }}</TableHead>
                <TableHead class="min-w-[100px]">{{ t('telegramBot.broadcasts.tableRecipientType') }}</TableHead>
                <TableHead class="min-w-[100px]">{{ t('telegramBot.broadcasts.tableStatus') }}</TableHead>
                <TableHead>{{ t('telegramBot.broadcasts.tableRecipientCount') }}</TableHead>
                <TableHead>{{ t('telegramBot.broadcasts.tableSuccessCount') }}</TableHead>
                <TableHead>{{ t('telegramBot.broadcasts.tableFailedCount') }}</TableHead>
                <TableHead class="min-w-[100px]">{{ t('telegramBot.broadcasts.tableCreatedAt') }}</TableHead>
                <TableHead class="min-w-[100px]">{{ t('telegramBot.broadcasts.tableCompletedAt') }}</TableHead>
                <TableHead class="min-w-[100px] text-right">{{ t('telegramBot.broadcasts.tableActions') }}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-if="loading">
                <TableCell :colspan="10" class="py-10 text-center text-muted-foreground">
                  <Loader2 class="mx-auto h-5 w-5 animate-spin" />
                </TableCell>
              </TableRow>
              <TableRow v-else-if="items.length === 0">
                <TableCell :colspan="10" class="py-10 text-center text-muted-foreground">
                  {{ t('telegramBot.broadcasts.empty') }}
                </TableCell>
              </TableRow>
              <TableRow v-for="item in items" :key="item.id">
                <TableCell>{{ item.id }}</TableCell>
                <TableCell class="min-w-[200px]">
                  <div class="space-y-1">
                    <div class="break-words font-medium">{{ item.title }}</div>
                    <div v-if="item.last_error" class="break-words text-xs text-destructive">{{ item.last_error }}</div>
                  </div>
                </TableCell>
                <TableCell class="min-w-[100px]">{{ formatRecipientType(item.recipient_type) }}</TableCell>
                <TableCell class="min-w-[100px]">{{ formatStatus(item.status) }}</TableCell>
                <TableCell>{{ item.recipient_count }}</TableCell>
                <TableCell>{{ item.success_count }}</TableCell>
                <TableCell>{{ item.failed_count }}</TableCell>
                <TableCell class="min-w-[100px]">{{ formatDate(item.created_at) || '-' }}</TableCell>
                <TableCell class="min-w-[100px]">{{ formatDate(item.completed_at || '') || '-' }}</TableCell>
                <TableCell class="min-w-[100px] text-right">
                  <div class="flex items-center justify-end gap-2">
                    <Button variant="outline" size="sm" as-child>
                      <RouterLink :to="`/telegram-bot/broadcasts/${item.id}`">
                        <Eye class="mr-2 h-4 w-4" />
                        {{ t('telegramBot.broadcasts.detail') }}
                      </RouterLink>
                    </Button>
                    <Button
                      variant="destructive"
                      size="sm"
                      :disabled="!canDelete(item) || deletingId === item.id"
                      @click="handleDelete(item)"
                    >
                      <Trash2 class="mr-2 h-4 w-4" />
                      {{ deletingId === item.id ? t('admin.common.loading') : t('telegramBot.broadcasts.delete') }}
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>

    <div class="flex flex-wrap items-center justify-end gap-3">
      <Button variant="outline" size="sm" :disabled="pagination.page <= 1" @click="changePage(pagination.page - 1)">
        {{ t('telegramBot.broadcasts.prevPage') }}
      </Button>
      <span class="text-sm text-muted-foreground">
        {{ t('telegramBot.broadcasts.pageSummary', { page: pagination.page, total: pagination.total_page }) }}
      </span>
      <Button variant="outline" size="sm" :disabled="pagination.page >= pagination.total_page" @click="changePage(pagination.page + 1)">
        {{ t('telegramBot.broadcasts.nextPage') }}
      </Button>
    </div>
  </div>
</template>

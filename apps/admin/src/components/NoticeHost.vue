<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { AlertCircle, CheckCircle2, Info, X } from 'lucide-vue-next'
import { useNoticeStore, type NoticeItem } from '@/stores/notice'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'

const noticeStore = useNoticeStore()
const { t } = useI18n()

const notices = computed(() => noticeStore.items)

const getAlertVariant = (notice: NoticeItem) => {
  if (notice.type === 'error') {
    return 'destructive'
  }
  return 'default'
}

const getContainerClass = (notice: NoticeItem) => {
  if (notice.type === 'success') {
    return 'border-emerald-300 bg-emerald-50 text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950 dark:text-emerald-100'
  }
  if (notice.type === 'info') {
    return 'border-sky-300 bg-sky-50 text-sky-900 dark:border-sky-800 dark:bg-sky-950 dark:text-sky-100'
  }
  return 'border-rose-300 bg-rose-50 text-rose-900 dark:border-rose-800 dark:bg-rose-950 dark:text-rose-100'
}

const getTitle = (notice: NoticeItem) => {
  if (notice.type === 'success') {
    return t('admin.common.success')
  }
  if (notice.type === 'info') {
    return t('admin.common.notice')
  }
  return t('admin.common.error')
}

const getIcon = (notice: NoticeItem) => {
  if (notice.type === 'success') {
    return CheckCircle2
  }
  if (notice.type === 'info') {
    return Info
  }
  return AlertCircle
}
</script>

<template>
  <div class="pointer-events-none fixed right-4 top-4 z-[120] flex w-[min(420px,calc(100vw-2rem))] flex-col gap-3">
    <TransitionGroup name="notice-fade" tag="div" class="flex flex-col gap-3">
      <Alert
        v-for="notice in notices"
        :key="notice.id"
        :variant="getAlertVariant(notice)"
        class="pointer-events-auto shadow-lg"
        :class="getContainerClass(notice)"
      >
        <component :is="getIcon(notice)" class="h-4 w-4" />
        <div>
          <div class="flex items-start justify-between gap-3">
            <AlertTitle class="text-sm font-semibold">{{ getTitle(notice) }}</AlertTitle>
            <Button
              variant="ghost"
              size="icon-sm"
              class="-mt-1 -mr-1 h-7 w-7 rounded-full hover:bg-black/5 dark:hover:bg-white/10"
              @click="noticeStore.remove(notice.id)"
            >
              <X class="h-4 w-4" />
              <span class="sr-only">{{ t('admin.common.close') }}</span>
            </Button>
          </div>
          <AlertDescription class="pr-2 text-sm">
            {{ notice.message }}
          </AlertDescription>
        </div>
      </Alert>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.notice-fade-enter-active,
.notice-fade-leave-active {
  transition: all 0.2s ease;
}

.notice-fade-enter-from,
.notice-fade-leave-to {
  opacity: 0;
  transform: translateY(-8px) scale(0.98);
}
</style>

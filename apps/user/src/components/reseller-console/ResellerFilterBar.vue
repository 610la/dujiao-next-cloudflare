<template>
  <form
    class="rounded-xl border bg-card p-4 shadow-sm"
    @submit.prevent="$emit('search')"
  >
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <slot name="fields" />
    </div>
    <div class="mt-3 flex flex-wrap items-center justify-end gap-2">
      <Button type="button" variant="outline" size="sm" @click="$emit('reset')">
        <RotateCcw class="h-4 w-4" />
        {{ t('resellerConsole.common.reset') }}
      </Button>
      <Button type="submit" size="sm">
        <Search class="h-4 w-4" />
        {{ t('orders.filters.search') }}
      </Button>
    </div>
  </form>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { RotateCcw, Search } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

defineEmits<{ (e: 'search'): void; (e: 'reset'): void }>()

const { t } = useI18n()
</script>

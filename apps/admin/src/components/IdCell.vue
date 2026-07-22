<script setup lang="ts">
import { Copy } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import { copyText } from '@/utils/clipboard'
import { notifyError } from '@/utils/notify'

const props = defineProps<{
  value: number | string
}>()

const { t } = useI18n()

const handleCopy = async () => {
  try {
    await copyText(String(props.value))
  } catch (error) {
    notifyError(t('admin.common.copyFailed'))
  }
}
</script>

<template>
  <div class="flex items-center gap-2 text-xs text-muted-foreground">
    <span class="font-mono text-foreground">#{{ value }}</span>
    <button type="button" class="inline-flex h-6 w-6 items-center justify-center rounded-md border border-border/60 text-muted-foreground hover:text-foreground hover:border-border" :title="t('admin.common.copy')" @click="handleCopy">
      <Copy class="h-3.5 w-3.5" />
    </button>
  </div>
</template>

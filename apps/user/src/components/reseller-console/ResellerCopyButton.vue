<template>
  <Button
    type="button"
    variant="ghost"
    :size="showLabel ? 'sm' : 'icon-sm'"
    :class="cn('text-muted-foreground hover:text-foreground', copied && 'text-primary hover:text-primary')"
    :aria-label="label || t('resellerConsole.common.copy')"
    @click="onCopy"
  >
    <Check v-if="copied" class="h-4 w-4" />
    <Copy v-else class="h-4 w-4" />
    <span v-if="showLabel">{{ copied ? t('resellerConsole.common.copied') : (label || t('resellerConsole.common.copy')) }}</span>
  </Button>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check, Copy } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import { copyText } from '../../utils/clipboard'

const props = withDefaults(
  defineProps<{ value: string; label?: string; showLabel?: boolean }>(),
  { showLabel: true },
)

const { t } = useI18n()
const copied = ref(false)
let timer: ReturnType<typeof setTimeout> | null = null

const onCopy = async () => {
  if (!props.value) return
  try {
    await copyText(props.value)
    copied.value = true
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => {
      copied.value = false
    }, 1800)
  } catch {
    // ignore copy failure silently
  }
}
</script>

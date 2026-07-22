<template>
  <Badge variant="outline" :class="cn('gap-1.5 font-semibold', toneClass)">
    <span v-if="dot" class="h-1.5 w-1.5 rounded-full" :class="dotClass"></span>
    <slot>{{ label }}</slot>
  </Badge>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

export type ResellerBadgeTone = 'success' | 'warning' | 'info' | 'accent' | 'neutral'

const props = withDefaults(
  defineProps<{ label?: string; tone?: ResellerBadgeTone; dot?: boolean }>(),
  { tone: 'neutral', dot: false },
)

const toneClass = computed(
  () =>
    ({
      success: 'border-success/30 bg-success/10 text-success',
      warning: 'border-warning/30 bg-warning/10 text-warning',
      info: 'border-info/30 bg-info/10 text-info',
      accent: 'border-primary/30 bg-primary/10 text-primary',
      neutral: 'border-border bg-muted text-muted-foreground',
    })[props.tone],
)

const dotClass = computed(
  () =>
    ({
      success: 'bg-success',
      warning: 'bg-warning',
      info: 'bg-info',
      accent: 'bg-primary',
      neutral: 'bg-muted-foreground',
    })[props.tone],
)
</script>

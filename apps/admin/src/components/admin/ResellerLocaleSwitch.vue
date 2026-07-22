<script setup lang="ts">
import { resellerLocales, type ResellerLocale } from '@/utils/resellerSiteConfig'

defineProps<{ modelValue: ResellerLocale; labels?: Record<string, string> }>()
const emit = defineEmits<{ (e: 'update:modelValue', value: ResellerLocale): void }>()
</script>

<template>
  <div class="inline-flex rounded-lg border border-border bg-muted/40 p-0.5">
    <button
      v-for="loc in resellerLocales"
      :key="loc"
      type="button"
      class="rounded-md px-3 py-1 text-xs font-semibold transition-colors"
      :class="
        loc === modelValue
          ? 'bg-background text-foreground shadow-sm'
          : 'text-muted-foreground hover:text-foreground'
      "
      @click="emit('update:modelValue', loc)"
    >
      {{ labels?.[loc] ?? loc }}
    </button>
  </div>
</template>

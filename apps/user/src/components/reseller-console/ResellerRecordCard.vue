<template>
  <Card class="space-y-3 p-4">
    <div v-if="$slots.header" class="flex items-start justify-between gap-3">
      <slot name="header" />
    </div>
    <dl v-if="$slots.default" class="grid grid-cols-2 gap-x-3 gap-y-2.5 text-xs">
      <slot />
    </dl>
    <div v-if="$slots.footer" class="flex items-center justify-between gap-2 border-t pt-3">
      <slot name="footer" />
    </div>
  </Card>
</template>

<script setup lang="ts">
import { Card } from '@/components/ui/card'
</script>

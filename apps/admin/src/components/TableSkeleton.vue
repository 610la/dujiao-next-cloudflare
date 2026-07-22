<script setup lang="ts">
defineProps<{
  columns?: number
  rows?: number
}>()
</script>

<template>
  <div class="w-full">
    <!-- Header skeleton -->
    <div class="flex gap-4 border-b border-border px-6 py-3">
      <div
        v-for="col in (columns ?? 5)"
        :key="col"
        class="h-4 rounded bg-muted animate-pulse"
        :class="col === 1 ? 'w-12' : 'flex-1'"
      />
    </div>
    <!-- Row skeletons -->
    <div
      v-for="row in (rows ?? 5)"
      :key="row"
      class="flex items-center gap-4 border-b border-border px-6 py-4"
    >
      <div
        v-for="col in (columns ?? 5)"
        :key="col"
        class="h-4 rounded bg-muted/60 animate-pulse"
        :class="col === 1 ? 'w-12' : 'flex-1'"
        :style="{ animationDelay: `${(row * 50 + col * 30)}ms` }"
      />
    </div>
  </div>
</template>

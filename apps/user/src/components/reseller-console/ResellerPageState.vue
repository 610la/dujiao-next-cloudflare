<template>
  <!-- Loading skeleton -->
  <div v-if="loading" class="space-y-4" role="status" aria-busy="true">
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <Card v-for="n in skeletonCards" :key="n" class="p-5">
        <div class="h-3 w-1/2 animate-pulse rounded bg-muted"></div>
        <div class="mt-4 h-6 w-2/3 animate-pulse rounded bg-muted"></div>
      </Card>
    </div>
    <Card class="p-5">
      <div v-for="n in 4" :key="n" class="flex items-center gap-4 border-t py-3 first:border-t-0">
        <div class="h-3 flex-1 animate-pulse rounded bg-muted"></div>
        <div class="h-3 w-20 animate-pulse rounded bg-muted"></div>
        <div class="h-3 w-16 animate-pulse rounded bg-muted"></div>
      </div>
    </Card>
    <span class="sr-only">{{ title }}</span>
  </div>

  <!-- Empty / message state -->
  <Card v-else class="border-dashed px-5 py-10 text-center shadow-none">
    <span class="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-muted text-muted-foreground">
      <component :is="icon || Inbox" class="h-6 w-6" />
    </span>
    <h2 class="mt-4 text-base font-bold text-foreground">{{ title }}</h2>
    <p v-if="description" class="mx-auto mt-2 max-w-xl text-sm text-muted-foreground">{{ description }}</p>
    <div v-if="$slots.default" class="mt-5">
      <slot />
    </div>
  </Card>
</template>

<script setup lang="ts">
import { type Component } from 'vue'
import { Inbox } from 'lucide-vue-next'
import { Card } from '@/components/ui/card'

withDefaults(
  defineProps<{ title: string; description?: string; loading?: boolean; icon?: Component; skeletonCards?: number }>(),
  { loading: false, skeletonCards: 4 },
)
</script>

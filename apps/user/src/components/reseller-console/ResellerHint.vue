<template>
  <TooltipProvider :delay-duration="100">
    <Tooltip>
      <TooltipTrigger as-child>
        <button
          type="button"
          class="inline-flex h-4 w-4 shrink-0 items-center justify-center rounded-full align-middle text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
          :aria-label="text"
        >
          <Info class="h-4 w-4" />
        </button>
      </TooltipTrigger>
      <TooltipContent class="max-w-xs leading-relaxed">
        {{ text }}
      </TooltipContent>
    </Tooltip>
  </TooltipProvider>
</template>

<script setup lang="ts">
import { Info } from 'lucide-vue-next'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

defineProps<{ text: string }>()
</script>

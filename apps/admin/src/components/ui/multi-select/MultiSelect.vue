<script setup lang="ts">
import { computed } from 'vue'
import { Check, ChevronDown, X } from 'lucide-vue-next'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

const props = defineProps<{
  options: { label: string; value: string | number }[]
  modelValue: (string | number)[]
  placeholder?: string
  class?: string
  disabled?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: (string | number)[]]
}>()

const selectedOptions = computed(() =>
  props.options.filter((option) => props.modelValue.includes(option.value))
)

const toggleOption = (value: string | number) => {
  const newValue = [...props.modelValue]
  const index = newValue.indexOf(value)
  if (index > -1) {
    newValue.splice(index, 1)
  } else {
    newValue.push(value)
  }
  emit('update:modelValue', newValue)
}

const removeOption = (value: string | number) => {
  const newValue = props.modelValue.filter((v) => v !== value)
  emit('update:modelValue', newValue)
}
</script>

<template>
  <Popover>
    <PopoverTrigger as-child>
      <button
        type="button"
        :disabled="props.disabled"
        :class="cn(
          'flex h-auto min-h-9 w-full items-center justify-between rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring disabled:cursor-not-allowed disabled:opacity-50 overflow-hidden',
          props.class
        )"
      >
        <div class="flex flex-wrap gap-1 items-center min-w-0">
          <template v-if="selectedOptions.length > 0">
            <Badge
              v-for="option in selectedOptions"
              :key="option.value"
              variant="secondary"
              class="rounded-sm px-1 font-normal h-5 shrink-0"
            >
              <span class="truncate max-w-[100px]">{{ option.label }}</span>
              <button
                type="button"
                class="ml-1 rounded-full outline-none ring-offset-background focus:ring-2 focus:ring-ring focus:ring-offset-2"
                @click.stop="removeOption(option.value)"
              >
                <X class="h-3 w-3 text-muted-foreground hover:text-foreground" />
              </button>
            </Badge>
          </template>
          <span v-else class="text-muted-foreground truncate">{{ placeholder }}</span>
        </div>
        <ChevronDown class="h-4 w-4 opacity-50 shrink-0 ml-2" />
      </button>
    </PopoverTrigger>
    <PopoverContent class="w-[--reka-popover-trigger-width] min-w-32 p-1" align="start">
      <div class="max-h-64 overflow-y-auto">
        <div
          v-for="option in options"
          :key="option.value"
          class="relative flex w-full cursor-pointer select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none hover:bg-accent hover:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
          @click="toggleOption(option.value)"
        >
          <span class="absolute left-2 flex h-3.5 w-3.5 items-center justify-center">
            <Check
              v-if="modelValue.includes(option.value)"
              class="h-4 w-4"
            />
          </span>
          <span class="truncate">{{ option.label }}</span>
        </div>
      </div>
    </PopoverContent>
  </Popover>
</template>

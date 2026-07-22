<script setup lang="ts">
import { ref } from 'vue'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

interface Props {
  accept?: string
  multiple?: boolean
  disabled?: boolean
  buttonText?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  accept: '*',
  multiple: false,
  disabled: false,
  buttonText: '选择文件',
})

const emit = defineEmits<{
  (e: 'change', files: FileList | null): void
}>()

const inputRef = ref<HTMLInputElement | null>(null)
const fileName = ref<string>('')

function trigger() {
  inputRef.value?.click()
}

function onChange(e: Event) {
  const target = e.target as HTMLInputElement
  const files = target.files
  fileName.value = files && files.length > 0
    ? (files.length === 1 ? (files[0]?.name ?? '') : `已选 ${files.length} 个文件`)
    : ''
  emit('change', files)
}
</script>

<template>
  <div :class="cn('flex items-center gap-2', props.class)">
    <input
      ref="inputRef"
      type="file"
      :accept="accept"
      :multiple="multiple"
      :disabled="disabled"
      class="hidden"
      @change="onChange"
    />
    <Button type="button" variant="outline" :disabled="disabled" @click="trigger">
      {{ buttonText }}
    </Button>
    <span v-if="fileName" class="text-sm text-muted-foreground">{{ fileName }}</span>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { Image as ImageIcon } from 'lucide-vue-next'

const props = withDefaults(
  defineProps<{
    src?: string | null
    alt?: string
    imgClass?: string
    loading?: 'lazy' | 'eager'
    decoding?: 'async' | 'sync' | 'auto'
  }>(),
  {
    alt: '',
    loading: 'lazy',
    decoding: 'async',
  },
)

const errored = ref(false)
watch(
  () => props.src,
  () => { errored.value = false },
)

const handleError = () => { errored.value = true }
</script>

<template>
  <img
    v-if="src && !errored"
    :src="src"
    :alt="alt"
    :loading="loading"
    :decoding="decoding"
    :class="imgClass"
    @error="handleError"
  />
  <slot v-else name="fallback">
    <div
      class="flex h-full w-full items-center justify-center text-muted-foreground bg-muted"
      role="img"
      :aria-label="alt || undefined"
    >
      <ImageIcon class="h-8 w-8 opacity-60" :stroke-width="1.5" aria-hidden="true" />
    </div>
  </slot>
</template>

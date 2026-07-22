<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

interface TurnstileRenderOptions {
  sitekey: string
  theme?: 'auto' | 'light' | 'dark'
  callback?: (token: string) => void
  'expired-callback'?: () => void
  'error-callback'?: () => void
}

interface TurnstileAPI {
  render: (container: HTMLElement, options: TurnstileRenderOptions) => string
  reset: (widgetID?: string) => void
  remove: (widgetID: string) => void
}

declare global {
  interface Window {
    turnstile?: TurnstileAPI
  }
}

const props = defineProps<{
  modelValue?: string
  siteKey: string
}>()

const emit = defineEmits<{
  (event: 'update:modelValue', value: string): void
}>()

const containerRef = ref<HTMLElement | null>(null)
const widgetID = ref<string>('')

let turnstileScriptPromise: Promise<void> | null = null

const loadScript = async () => {
  if (window.turnstile) return
  if (!turnstileScriptPromise) {
    turnstileScriptPromise = new Promise((resolve, reject) => {
      const existing = document.querySelector<HTMLScriptElement>('script[data-turnstile="1"]')
      if (existing) {
        existing.addEventListener('load', () => resolve(), { once: true })
        existing.addEventListener('error', () => reject(new Error('failed to load turnstile script')), { once: true })
        return
      }
      const script = document.createElement('script')
      script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
      script.async = true
      script.defer = true
      script.dataset.turnstile = '1'
      script.onload = () => resolve()
      script.onerror = () => reject(new Error('failed to load turnstile script'))
      document.head.appendChild(script)
    })
  }
  await turnstileScriptPromise
}

const renderWidget = async () => {
  if (!props.siteKey || !containerRef.value) {
    emit('update:modelValue', '')
    return
  }

  await loadScript()
  if (!window.turnstile || !containerRef.value) return

  if (widgetID.value) {
    window.turnstile.remove(widgetID.value)
    widgetID.value = ''
  }

  containerRef.value.innerHTML = ''
  widgetID.value = window.turnstile.render(containerRef.value, {
    sitekey: props.siteKey,
    theme: 'auto',
    callback: (token: string) => emit('update:modelValue', token || ''),
    'expired-callback': () => emit('update:modelValue', ''),
    'error-callback': () => emit('update:modelValue', ''),
  })
}

const reset = () => {
  if (window.turnstile && widgetID.value) {
    window.turnstile.reset(widgetID.value)
  }
  emit('update:modelValue', '')
}

watch(
  () => props.siteKey,
  () => {
    renderWidget().catch(() => {
      emit('update:modelValue', '')
    })
  },
)

onMounted(() => {
  renderWidget().catch(() => {
    emit('update:modelValue', '')
  })
})

onBeforeUnmount(() => {
  if (window.turnstile && widgetID.value) {
    window.turnstile.remove(widgetID.value)
  }
})

defineExpose({
  reset,
})
</script>

<template>
  <div ref="containerRef" class="min-h-[65px]"></div>
</template>

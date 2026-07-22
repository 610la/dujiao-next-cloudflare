<template>
  <slot v-if="!error" />
  <div v-else class="flex flex-col items-center justify-center py-16 px-4 text-center">
    <Card class="rounded-2xl p-8 max-w-md w-full">
      <AlertCircle class="mx-auto h-12 w-12 text-muted-foreground opacity-50" :stroke-width="1.5" />
      <h3 class="mt-4 text-lg font-bold text-foreground">{{ t('common.error') }}</h3>
      <p class="mt-2 text-sm text-muted-foreground">{{ displayMessage }}</p>
      <Button class="mt-6" @click="retry">
        <RotateCw />
        {{ t('errorBoundary.retry') }}
      </Button>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { ref, onErrorCaptured } from 'vue'
import { useI18n } from 'vue-i18n'
import { AlertCircle, RotateCw } from 'lucide-vue-next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'

const { t } = useI18n()

const error = ref<Error | null>(null)

const displayMessage = ref('')

onErrorCaptured((err: Error) => {
  error.value = err
  displayMessage.value = err.message || t('errorBoundary.defaultMessage')
  return false
})

const retry = () => {
  error.value = null
  displayMessage.value = ''
}
</script>

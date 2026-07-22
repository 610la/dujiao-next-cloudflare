<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { AlertTriangle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

const { t } = useI18n()
const router = useRouter()
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-[60vh] px-6 text-center">
    <div class="w-16 h-16 rounded-full bg-amber-100 text-amber-600 flex items-center justify-center mb-4">
      <AlertTriangle class="w-8 h-8" />
    </div>
    <h2 class="text-xl font-semibold mb-2">{{ t('compliance.required.title') }}</h2>
    <p class="text-muted-foreground max-w-xl mb-6 leading-relaxed">
      {{ t('compliance.required.message') }}
    </p>
    <Button variant="outline" @click="router.push({ name: 'dashboard' })">
      {{ t('compliance.required.back') }}
    </Button>
  </div>
</template>

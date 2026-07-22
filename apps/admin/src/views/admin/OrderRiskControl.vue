<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { Button } from '@/components/ui/button'
import SettingsOrderRiskControlTab from './components/SettingsOrderRiskControlTab.vue'

const { t } = useI18n()
const tabRef = ref<InstanceType<typeof SettingsOrderRiskControlTab>>()
const saving = ref(false)

const onSave = async () => {
  saving.value = true
  try {
    await tabRef.value?.save()
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
      <div>
        <h1 class="text-2xl font-semibold">{{ t('admin.settings.orderRiskControl.title') }}</h1>
        <p class="mt-1 text-sm text-muted-foreground">{{ t('admin.settings.orderRiskControl.subtitle') }}</p>
      </div>
      <Button size="sm" :disabled="saving" @click="onSave">
        {{ saving ? t('admin.settings.actions.saving') : t('admin.settings.actions.save') }}
      </Button>
    </div>
    <SettingsOrderRiskControlTab ref="tabRef" />
  </div>
</template>

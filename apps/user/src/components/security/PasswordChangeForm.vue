<template>
  <div class="rounded-2xl border bg-card p-7 shadow-sm">
    <h3 class="text-lg font-bold text-foreground">
      {{ requiresOldPassword ? t('personalCenter.security.passwordTitle') : t('personalCenter.security.setPasswordTitle') }}
    </h3>
    <p class="mt-1 text-sm text-muted-foreground">
      {{ requiresOldPassword ? t('personalCenter.security.passwordSubtitle') : t('personalCenter.security.setPasswordSubtitle') }}
    </p>

    <form class="mt-6 space-y-6" @submit.prevent="$emit('submit')">
      <div v-if="requiresOldPassword">
        <Label class="mb-2 block">{{ t('personalCenter.security.currentPasswordLabel') }}</Label>
        <Input
          :model-value="oldPassword"
          @update:model-value="(v) => $emit('update:oldPassword', String(v))"
          type="password"
          :placeholder="t('personalCenter.security.passwordPlaceholder')"
          class="h-11"
        />
      </div>

      <div class="grid grid-cols-1 gap-5 md:grid-cols-2">
        <div>
          <Label class="mb-2 block">{{ t('personalCenter.security.newPasswordLabel') }}</Label>
          <Input
            :model-value="newPassword"
            @update:model-value="(v) => $emit('update:newPassword', String(v))"
            type="password"
            :placeholder="t('personalCenter.security.passwordPlaceholder')"
            class="h-11"
          />
        </div>

        <div>
          <Label class="mb-2 block">{{ t('personalCenter.security.confirmPasswordLabel') }}</Label>
          <Input
            :model-value="confirmPassword"
            @update:model-value="(v) => $emit('update:confirmPassword', String(v))"
            type="password"
            :placeholder="t('personalCenter.security.passwordPlaceholder')"
            class="h-11"
          />
        </div>
      </div>

      <div class="border-t pt-5">
        <Button type="submit" variant="outline" :disabled="changingPassword" class="h-11">
          {{
            changingPassword
              ? (requiresOldPassword ? t('personalCenter.security.changePasswordSubmitting') : t('personalCenter.security.setPasswordSubmitting'))
              : (requiresOldPassword ? t('personalCenter.security.changePassword') : t('personalCenter.security.setPassword'))
          }}
        </Button>
      </div>
    </form>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const { t } = useI18n()

defineProps<{
  requiresOldPassword: boolean
  oldPassword: string
  newPassword: string
  confirmPassword: string
  changingPassword: boolean
}>()

defineEmits<{
  submit: []
  'update:oldPassword': [value: string]
  'update:newPassword': [value: string]
  'update:confirmPassword': [value: string]
}>()
</script>

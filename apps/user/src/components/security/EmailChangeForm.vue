<template>
  <form class="space-y-6" @submit.prevent="$emit('submit')">
    <div>
      <Label class="mb-2 block">{{ t('personalCenter.security.currentEmailLabel') }}</Label>
      <Input :model-value="currentEmailDisplay" disabled class="h-11" />
      <p v-if="!requiresOldEmailCode" class="mt-2 text-xs text-muted-foreground">
        {{ t('personalCenter.security.bindOnlyTip') }}
      </p>
    </div>

    <div>
      <Label class="mb-2 block">{{ t('personalCenter.security.newEmailLabel') }}</Label>
      <Input
        :model-value="newEmail"
        @update:model-value="(v) => $emit('update:newEmail', String(v))"
        type="email"
        :placeholder="t('personalCenter.security.newEmailPlaceholder')"
        class="h-11"
      />
    </div>

    <div class="grid grid-cols-1 gap-4" :class="requiresOldEmailCode ? 'lg:grid-cols-2' : ''">
      <div v-if="requiresOldEmailCode">
        <Label class="mb-2 block">{{ t('personalCenter.security.oldCodeLabel') }}</Label>
        <div class="flex flex-col gap-2 sm:flex-row">
          <Input
            :model-value="oldCode"
            @update:model-value="(v) => $emit('update:oldCode', String(v))"
            :placeholder="t('personalCenter.security.codePlaceholder')"
            class="h-11 flex-1"
          />
          <Button
            type="button"
            variant="outline"
            size="sm"
            class="h-11 whitespace-nowrap"
            :disabled="sendingCode || oldCodeCooldown > 0"
            @click="$emit('sendOldCode')"
          >
            {{ oldCodeCooldown > 0 ? t('personalCenter.security.countdown', { seconds: oldCodeCooldown }) : t('personalCenter.security.sendOldCode') }}
          </Button>
        </div>
      </div>

      <div>
        <Label class="mb-2 block">{{ t('personalCenter.security.newCodeLabel') }}</Label>
        <div class="flex flex-col gap-2 sm:flex-row">
          <Input
            :model-value="newCode"
            @update:model-value="(v) => $emit('update:newCode', String(v))"
            :placeholder="t('personalCenter.security.codePlaceholder')"
            class="h-11 flex-1"
          />
          <Button
            type="button"
            variant="outline"
            size="sm"
            class="h-11 whitespace-nowrap"
            :disabled="sendingCode || newCodeCooldown > 0"
            @click="$emit('sendNewCode')"
          >
            {{ newCodeCooldown > 0 ? t('personalCenter.security.countdown', { seconds: newCodeCooldown }) : t('personalCenter.security.sendNewCode') }}
          </Button>
        </div>
      </div>
    </div>

    <div class="border-t pt-5">
      <Button type="submit" :disabled="changingEmail" class="h-11 font-bold">
        {{
          changingEmail
            ? t('personalCenter.security.submitting')
            : (requiresOldEmailCode ? t('personalCenter.security.submit') : t('personalCenter.security.bindSubmit'))
        }}
      </Button>
    </div>
  </form>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const { t } = useI18n()

defineProps<{
  currentEmailDisplay: string
  requiresOldEmailCode: boolean
  newEmail: string
  oldCode: string
  newCode: string
  sendingCode: boolean
  oldCodeCooldown: number
  newCodeCooldown: number
  changingEmail: boolean
}>()

defineEmits<{
  submit: []
  sendOldCode: []
  sendNewCode: []
  'update:newEmail': [value: string]
  'update:oldCode': [value: string]
  'update:newCode': [value: string]
}>()
</script>

<script setup lang="ts">
import { ref, watch } from 'vue'
import QRCode from 'qrcode'
import { useI18n } from 'vue-i18n'
import { adminAPI, type SetupTwoFAResponse } from '@/api/admin'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { notifyError, notifySuccess } from '@/utils/notify'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{
  (e: 'update:open', value: boolean): void
  (e: 'enabled', recoveryCodes: string[]): void
}>()

const { t } = useI18n()
const setupData = ref<SetupTwoFAResponse | null>(null)
const qrDataUrl = ref('')
const code = ref('')
const loading = ref(false)
const submitting = ref(false)

const close = () => emit('update:open', false)

const init = async () => {
  loading.value = true
  setupData.value = null
  qrDataUrl.value = ''
  code.value = ''
  try {
    const res = await adminAPI.setup2FA()
    const data = res.data?.data as SetupTwoFAResponse
    setupData.value = data
    qrDataUrl.value = await QRCode.toDataURL(data.otpauth_url, { margin: 1, width: 240 })
  } catch (err: unknown) {
    // client.ts 已对业务错误做过 notifyError，仅在未通知过时再 fallback 提示
    if (!(err as { __notified?: boolean })?.__notified) {
      notifyError(t('admin.twofa.errors.setupFailed'))
    }
    close()
  } finally {
    loading.value = false
  }
}

const submit = async () => {
  if (code.value.length !== 6) {
    notifyError(t('admin.twofa.errors.codeFormat'))
    return
  }
  submitting.value = true
  try {
    const res = await adminAPI.enable2FA({ code: code.value })
    const data = res.data?.data as { recovery_codes: string[] }
    emit('enabled', data.recovery_codes)
    close()
  } catch (err: unknown) {
    if (!(err as { __notified?: boolean })?.__notified) {
      notifyError(t('admin.twofa.errors.enableFailed'))
    }
  } finally {
    submitting.value = false
  }
}

const copySecret = async () => {
  if (setupData.value?.secret) {
    await navigator.clipboard.writeText(setupData.value.secret)
    notifySuccess(t('admin.twofa.recovery.copied'))
  }
}

watch(
  () => props.open,
  (val) => {
    if (val) init()
  },
  { immediate: true },
)
</script>

<template>
  <Dialog :open="open" @update:open="(v) => emit('update:open', v)">
    <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-md p-4 sm:p-6">
      <DialogHeader>
        <DialogTitle>{{ t('admin.twofa.setup.title') }}</DialogTitle>
      </DialogHeader>

      <p class="text-sm text-muted-foreground">{{ t('admin.twofa.setup.description') }}</p>

      <div v-if="loading" class="text-center py-8 text-sm text-muted-foreground">
        {{ t('admin.twofa.setup.generating') }}
      </div>

      <div v-else-if="setupData" class="space-y-4 pt-2">
        <div class="flex justify-center">
          <img :src="qrDataUrl" alt="QR" class="w-60 h-60 bg-white p-2 rounded border" />
        </div>
        <div class="space-y-1">
          <Label class="text-xs text-muted-foreground">{{ t('admin.twofa.setup.secretLabel') }}</Label>
          <div class="flex gap-2">
            <code class="flex-1 px-3 py-2 rounded bg-muted text-xs font-mono break-all">{{ setupData.secret }}</code>
            <Button type="button" variant="outline" size="sm" @click="copySecret">
              {{ t('admin.twofa.setup.copy') }}
            </Button>
          </div>
        </div>
        <div class="space-y-1">
          <Label for="totp-setup-code" class="text-xs text-muted-foreground">{{ t('admin.twofa.setup.codeLabel') }}</Label>
          <Input
            id="totp-setup-code"
            v-model="code"
            inputmode="numeric"
            maxlength="6"
            placeholder="123456"
            autocomplete="one-time-code"
          />
        </div>
      </div>

      <div class="flex justify-end gap-2 pt-4">
        <Button variant="outline" @click="close" :disabled="submitting">
          {{ t('admin.common.cancel') }}
        </Button>
        <Button @click="submit" :disabled="loading || submitting || code.length !== 6">
          {{ submitting ? t('admin.common.submitting') : t('admin.twofa.setup.confirm') }}
        </Button>
      </div>
    </DialogScrollContent>
  </Dialog>
</template>

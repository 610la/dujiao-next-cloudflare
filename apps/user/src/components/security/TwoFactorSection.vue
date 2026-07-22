<template>
  <div class="rounded-2xl border bg-card p-7 shadow-sm">
    <div class="mb-4 flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
      <div>
        <h3 class="text-lg font-bold text-foreground">{{ t('personalCenter.security.twofa.title') }}</h3>
        <p class="mt-1 text-sm text-muted-foreground">{{ t('personalCenter.security.twofa.subtitle') }}</p>
      </div>
      <Badge :variant="status?.enabled ? 'success' : 'neutral'" size="sm">
        {{ status?.enabled ? t('personalCenter.security.twofa.statusEnabled') : t('personalCenter.security.twofa.statusDisabled') }}
      </Badge>
    </div>

    <Alert v-if="alert" class="mb-4" :variant="pageAlertVariant(alert.level)" :class="pageAlertToneClass(alert.level)">
      <AlertDescription>{{ alert.message }}</AlertDescription>
    </Alert>

    <!-- 已启用：显示状态、关闭、重新生成恢复码 -->
    <div v-if="status?.enabled" class="space-y-4">
      <div class="rounded-xl border px-4 py-3 text-sm text-muted-foreground">
        <div>{{ t('personalCenter.security.twofa.enabledAt', { date: formatDate(status.enabled_at) }) }}</div>
        <div class="mt-1">
          {{ t('personalCenter.security.twofa.recoveryRemaining', {
            remaining: status.recovery_codes_remaining,
            total: status.recovery_codes_total,
          }) }}
        </div>
      </div>

      <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
        <Button type="button" variant="outline" class="h-11 font-semibold" @click="openRegenerate">
          {{ t('personalCenter.security.twofa.regenerateAction') }}
        </Button>
        <Button type="button" variant="destructive" class="h-11 font-semibold" @click="openDisable">
          {{ t('personalCenter.security.twofa.disableAction') }}
        </Button>
      </div>

      <!-- Disable 表单 -->
      <div v-if="mode === 'disable'" class="space-y-3 rounded-xl border px-4 py-4">
        <p class="text-sm text-muted-foreground">{{ t('personalCenter.security.twofa.disableHint') }}</p>
        <div class="flex gap-2">
          <button
            type="button"
            class="text-xs"
            :class="disableMode === 'code' ? 'text-primary font-bold' : 'text-muted-foreground transition-colors hover:text-foreground'"
            @click="disableMode = 'code'"
          >
            {{ t('personalCenter.security.twofa.useCode') }}
          </button>
          <span class="text-muted-foreground text-xs">/</span>
          <button
            type="button"
            class="text-xs"
            :class="disableMode === 'recovery' ? 'text-primary font-bold' : 'text-muted-foreground transition-colors hover:text-foreground'"
            @click="disableMode = 'recovery'"
          >
            {{ t('personalCenter.security.twofa.useRecovery') }}
          </button>
        </div>
        <Input
          v-if="disableMode === 'code'"
          v-model="disableCode"
          inputmode="numeric"
          maxlength="6"
          class="h-11 text-center tracking-[0.4em]"
          :placeholder="t('personalCenter.security.twofa.codePlaceholder')"
        />
        <Input
          v-else
          v-model="disableRecovery"
          autocomplete="off"
          class="h-11"
          :placeholder="t('personalCenter.security.twofa.recoveryPlaceholder')"
        />
        <div class="grid grid-cols-2 gap-2">
          <Button type="button" variant="destructive" :disabled="loading" class="h-11 font-semibold" @click="submitDisable">
            {{ loading ? t('personalCenter.security.twofa.disableSubmitting') : t('personalCenter.security.twofa.disableSubmit') }}
          </Button>
          <Button type="button" variant="outline" class="h-11 font-semibold" @click="resetMode">
            {{ t('personalCenter.security.twofa.cancel') }}
          </Button>
        </div>
      </div>

      <!-- Regenerate 表单 -->
      <div v-if="mode === 'regenerate'" class="space-y-3 rounded-xl border px-4 py-4">
        <p class="text-sm text-muted-foreground">{{ t('personalCenter.security.twofa.regenerateHint') }}</p>
        <Input
          v-model="regenerateCode"
          inputmode="numeric"
          maxlength="6"
          class="h-11 text-center tracking-[0.4em]"
          :placeholder="t('personalCenter.security.twofa.codePlaceholder')"
        />
        <div class="grid grid-cols-2 gap-2">
          <Button type="button" :disabled="loading" class="h-11 font-bold" @click="submitRegenerate">
            {{ loading ? t('personalCenter.security.twofa.regenerateSubmitting') : t('personalCenter.security.twofa.regenerateSubmit') }}
          </Button>
          <Button type="button" variant="outline" class="h-11 font-semibold" @click="resetMode">
            {{ t('personalCenter.security.twofa.cancel') }}
          </Button>
        </div>
      </div>
    </div>

    <!-- 未启用：显示绑定流程 -->
    <div v-else class="space-y-4">
      <p class="text-sm text-muted-foreground">{{ t('personalCenter.security.twofa.notEnabledHint') }}</p>

      <div v-if="!setupResult">
        <Button type="button" :disabled="loading" class="h-11 font-bold" @click="startSetup">
          {{ loading ? t('personalCenter.security.twofa.startingSetup') : t('personalCenter.security.twofa.startSetup') }}
        </Button>
      </div>

      <div v-else class="space-y-3 rounded-xl border px-4 py-4">
        <p class="text-sm text-muted-foreground">{{ t('personalCenter.security.twofa.setupStep1') }}</p>
        <img
          v-if="qrcodeDataUrl"
          :src="qrcodeDataUrl"
          alt="2FA QR"
          class="mx-auto w-48 h-48 rounded-lg border bg-white p-2"
        />
        <div class="rounded-lg border bg-card px-3 py-2 text-center">
          <div class="text-xs text-muted-foreground">{{ t('personalCenter.security.twofa.secret') }}</div>
          <div class="mt-1 font-mono text-sm break-all text-foreground">{{ setupResult.secret }}</div>
        </div>

        <p class="text-sm text-muted-foreground">{{ t('personalCenter.security.twofa.setupStep2') }}</p>
        <Input
          v-model="enableCode"
          inputmode="numeric"
          maxlength="6"
          class="h-11 text-center tracking-[0.4em]"
          :placeholder="t('personalCenter.security.twofa.codePlaceholder')"
        />

        <div class="grid grid-cols-2 gap-2">
          <Button type="button" :disabled="loading" class="h-11 font-bold" @click="submitEnable">
            {{ loading ? t('personalCenter.security.twofa.enableSubmitting') : t('personalCenter.security.twofa.enableSubmit') }}
          </Button>
          <Button type="button" variant="outline" class="h-11 font-semibold" @click="cancelSetup">
            {{ t('personalCenter.security.twofa.cancel') }}
          </Button>
        </div>
      </div>
    </div>

    <!-- 恢复码展示弹窗（启用成功 / 重新生成成功后） -->
    <div
      v-if="recoveryCodes.length > 0"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4"
      @click.self="recoveryCodes = []"
    >
      <div class="w-full max-w-md rounded-2xl border bg-card p-6 shadow-sm">
        <h4 class="text-lg font-bold text-foreground">{{ t('personalCenter.security.twofa.recoveryTitle') }}</h4>
        <p class="mt-2 text-sm text-muted-foreground">{{ t('personalCenter.security.twofa.recoveryWarning') }}</p>
        <div class="mt-4 grid grid-cols-2 gap-2">
          <code
            v-for="(c, idx) in recoveryCodes"
            :key="idx"
            class="rounded-lg border px-3 py-2 text-center font-mono text-sm text-foreground"
          >{{ c }}</code>
        </div>
        <div class="mt-5 flex gap-2">
          <Button type="button" variant="outline" class="flex-1" @click="copyRecoveryCodes">
            {{ copied ? t('personalCenter.security.twofa.copied') : t('personalCenter.security.twofa.copy') }}
          </Button>
          <Button type="button" class="font-bold" @click="acknowledgeRecoveryCodes">
            {{ t('personalCenter.security.twofa.acknowledge') }}
          </Button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import QRCode from 'qrcode'
import { userTotpAPI } from '../../api/auth'
import { useUserAuthStore } from '../../stores/userAuth'
import { pageAlertVariant, pageAlertToneClass, type PageAlert } from '../../utils/alerts'
import { formatSiteDateTime } from '../../utils/time'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

const { t } = useI18n()
const userAuthStore = useUserAuthStore()

interface TwoFactorStatus {
  enabled: boolean
  enabled_at?: string | null
  recovery_codes_remaining: number
  recovery_codes_total: number
}

interface SetupResult {
  secret: string
  otpauth_url: string
  expires_at: string
}

const status = ref<TwoFactorStatus | null>(null)
const setupResult = ref<SetupResult | null>(null)
const qrcodeDataUrl = ref('')
const enableCode = ref('')
const recoveryCodes = ref<string[]>([])
const copied = ref(false)
const loading = ref(false)
const alert = ref<PageAlert | null>(null)

const mode = ref<'idle' | 'disable' | 'regenerate'>('idle')
const disableMode = ref<'code' | 'recovery'>('code')
const disableCode = ref('')
const disableRecovery = ref('')
const regenerateCode = ref('')

const formatDate = (raw?: string | null) => {
  return formatSiteDateTime(raw) || '-'
}

const refreshStatus = async () => {
  try {
    const res = await userTotpAPI.status()
    status.value = res.data.data
  } catch (err: any) {
    alert.value = { level: 'error', message: err?.message || t('personalCenter.security.twofa.loadFailed') }
  }
}

const startSetup = async () => {
  alert.value = null
  loading.value = true
  try {
    const res = await userTotpAPI.setup()
    setupResult.value = res.data.data
    qrcodeDataUrl.value = await QRCode.toDataURL(setupResult.value!.otpauth_url, { width: 240, margin: 1 })
    enableCode.value = ''
  } catch (err: any) {
    alert.value = { level: 'error', message: err?.message || t('personalCenter.security.twofa.setupFailed') }
  } finally {
    loading.value = false
  }
}

const cancelSetup = () => {
  setupResult.value = null
  qrcodeDataUrl.value = ''
  enableCode.value = ''
  alert.value = null
}

const submitEnable = async () => {
  alert.value = null
  const code = enableCode.value.trim()
  if (code === '') {
    alert.value = { level: 'warning', message: t('personalCenter.security.twofa.codeRequired') }
    return
  }
  loading.value = true
  try {
    const res = await userTotpAPI.enable({ code })
    const data = res.data.data || {}
    recoveryCodes.value = data.recovery_codes || []
    if (data.token) {
      // 启用 2FA 后旧 token 已失效，立即用服务端返回的新 token 替换，避免被中间件登出
      localStorage.setItem('user_token', data.token)
      userAuthStore.token = data.token
    }
    setupResult.value = null
    qrcodeDataUrl.value = ''
    enableCode.value = ''
    alert.value = { level: 'success', message: t('personalCenter.security.twofa.enableSuccess') }
    await refreshStatus()
  } catch (err: any) {
    alert.value = { level: 'error', message: err?.message || t('personalCenter.security.twofa.enableFailed') }
  } finally {
    loading.value = false
  }
}

const openDisable = () => {
  mode.value = 'disable'
  disableMode.value = 'code'
  disableCode.value = ''
  disableRecovery.value = ''
  alert.value = null
}

const openRegenerate = () => {
  mode.value = 'regenerate'
  regenerateCode.value = ''
  alert.value = null
}

const resetMode = () => {
  mode.value = 'idle'
  disableCode.value = ''
  disableRecovery.value = ''
  regenerateCode.value = ''
}

const submitDisable = async () => {
  alert.value = null
  const payload: { code?: string; recovery_code?: string } = {}
  if (disableMode.value === 'code') {
    const code = disableCode.value.trim()
    if (code === '') {
      alert.value = { level: 'warning', message: t('personalCenter.security.twofa.codeRequired') }
      return
    }
    payload.code = code
  } else {
    const rc = disableRecovery.value.trim()
    if (rc === '') {
      alert.value = { level: 'warning', message: t('personalCenter.security.twofa.recoveryRequired') }
      return
    }
    payload.recovery_code = rc
  }
  loading.value = true
  try {
    await userTotpAPI.disable(payload)
    alert.value = { level: 'success', message: t('personalCenter.security.twofa.disableSuccess') }
    resetMode()
    await refreshStatus()
  } catch (err: any) {
    alert.value = { level: 'error', message: err?.message || t('personalCenter.security.twofa.disableFailed') }
  } finally {
    loading.value = false
  }
}

const submitRegenerate = async () => {
  alert.value = null
  const code = regenerateCode.value.trim()
  if (code === '') {
    alert.value = { level: 'warning', message: t('personalCenter.security.twofa.codeRequired') }
    return
  }
  loading.value = true
  try {
    const res = await userTotpAPI.regenerateRecoveryCodes({ code })
    recoveryCodes.value = res.data.data?.recovery_codes || []
    resetMode()
    alert.value = { level: 'success', message: t('personalCenter.security.twofa.regenerateSuccess') }
    await refreshStatus()
  } catch (err: any) {
    alert.value = { level: 'error', message: err?.message || t('personalCenter.security.twofa.regenerateFailed') }
  } finally {
    loading.value = false
  }
}

const copyRecoveryCodes = async () => {
  try {
    await navigator.clipboard.writeText(recoveryCodes.value.join('\n'))
    copied.value = true
    setTimeout(() => { copied.value = false }, 2000)
  } catch (err) {
    /* ignore */
  }
}

const acknowledgeRecoveryCodes = () => {
  recoveryCodes.value = []
}

watch(setupResult, async (val) => {
  if (val) {
    qrcodeDataUrl.value = await QRCode.toDataURL(val.otpauth_url, { width: 240, margin: 1 })
  } else {
    qrcodeDataUrl.value = ''
  }
})

onMounted(() => {
  refreshStatus()
})
</script>

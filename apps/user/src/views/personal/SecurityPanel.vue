<template>
  <div class="space-y-6">
    <div class="rounded-2xl border bg-card p-7 shadow-sm">
      <PanelHeading
        :title="t('personalCenter.security.title')"
        :description="requiresOldEmailCode ? t('personalCenter.security.subtitle') : t('personalCenter.security.subtitleBindOnly')"
        :icon="ShieldCheck"
      >
        <template #actions>
          <Badge variant="accent" size="sm">{{ t('personalCenter.tabs.security') }}</Badge>
        </template>
      </PanelHeading>

      <Alert v-if="securityAlert" class="mb-5" :variant="pageAlertVariant(securityAlert.level)" :class="pageAlertToneClass(securityAlert.level)">
        <AlertDescription>{{ securityAlert.message }}</AlertDescription>
      </Alert>

      <TelegramBindingSection
        :telegram-enabled="telegramEnabled"
        :telegram-bound="telegramBound"
        :loading-telegram-binding="userProfileStore.loadingTelegramBinding"
        :avatar-url="userProfileStore.telegramBinding?.avatar_url || ''"
        :telegram-display-name="telegramDisplayName"
        :provider-user-id="userProfileStore.telegramBinding?.provider_user_id || '-'"
        :formatted-auth-at="formatDate(userProfileStore.telegramBinding?.auth_at) || '-'"
        :unbinding-telegram="userProfileStore.unbindingTelegram"
        :can-unbind-telegram="canUnbindTelegram"
        :show-telegram-mini-app-entry="showTelegramMiniAppEntry"
        :show-mini-app-bind-action="showMiniAppBindAction"
        :show-telegram-widget="showTelegramWidget"
        :show-telegram-oidc-bind="showTelegramOidcBind"
        :binding-telegram="userProfileStore.bindingTelegram"
        :mini-app-init-data="miniAppInitData"
        ref="telegramSectionRef"
        @unbind="handleUnbindTelegram"
        @mini-app-bind="handleTelegramMiniAppBind"
        @open-mini-app-entry="openTelegramMiniAppEntry"
        @oidc-bind="startTelegramOidcBind"
      />

      <EmailChangeForm
        :current-email-display="currentEmailDisplay"
        :requires-old-email-code="requiresOldEmailCode"
        v-model:new-email="securityForm.newEmail"
        v-model:old-code="securityForm.oldCode"
        v-model:new-code="securityForm.newCode"
        :sending-code="userProfileStore.sendingCode"
        :old-code-cooldown="oldCodeCooldown"
        :new-code-cooldown="newCodeCooldown"
        :changing-email="userProfileStore.changingEmail"
        @submit="handleChangeEmail"
        @send-old-code="handleSendOldCode"
        @send-new-code="handleSendNewCode"
      />
    </div>

    <LoginHistorySection
      :loading="userProfileStore.loadingLoginLogs"
      :logs="userProfileStore.recentLoginLogs"
    />

    <PasswordChangeForm
      v-if="canManagePassword"
      :requires-old-password="requiresOldPassword"
      v-model:old-password="passwordForm.oldPassword"
      v-model:new-password="passwordForm.newPassword"
      v-model:confirm-password="passwordForm.confirmPassword"
      :changing-password="userProfileStore.changingPassword"
      @submit="handleChangePassword"
    />

    <TwoFactorSection v-if="canManagePassword" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import { ShieldCheck } from 'lucide-vue-next'
import { pageAlertVariant, pageAlertToneClass, type PageAlert } from '../../utils/alerts'
import PanelHeading from '../../components/shared/PanelHeading.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { userProfileAPI } from '../../api/user'
import type { TelegramAuthPayload } from '../../api'
import { useAppStore } from '../../stores/app'
import { useTelegramMiniAppStore } from '../../stores/telegramMiniApp'
import { useUserProfileStore } from '../../stores/userProfile'
import { useUserAuthStore } from '../../stores/userAuth'
import { buildTelegramMiniAppEntryLink, openTelegramCompatibleLink } from '../../utils/telegramMiniApp'
import { formatSiteDateTime } from '../../utils/time'
import TelegramBindingSection from '../../components/security/TelegramBindingSection.vue'
import EmailChangeForm from '../../components/security/EmailChangeForm.vue'
import LoginHistorySection from '../../components/security/LoginHistorySection.vue'
import PasswordChangeForm from '../../components/security/PasswordChangeForm.vue'
import TwoFactorSection from '../../components/security/TwoFactorSection.vue'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const telegramMiniAppStore = useTelegramMiniAppStore()
const userProfileStore = useUserProfileStore()
const userAuthStore = useUserAuthStore()

const securityForm = reactive({
  newEmail: '',
  oldCode: '',
  newCode: '',
})

const passwordForm = reactive({
  oldPassword: '',
  newPassword: '',
  confirmPassword: '',
})

const securityAlert = ref<PageAlert | null>(null)
const oldCodeCooldown = ref(0)
const newCodeCooldown = ref(0)
const telegramSectionRef = ref<InstanceType<typeof TelegramBindingSection> | null>(null)
let cooldownTimer: number | null = null
const telegramCallbackName = '__dujiaoSecurityTelegramBind'

const telegramConfig = computed(() => appStore.config?.telegram_auth || null)
const telegramBotUsername = computed(() => String(telegramConfig.value?.bot_username || '').trim())
const telegramMiniAppURL = computed(() => String(telegramConfig.value?.mini_app_url || '').trim())
const telegramLoginMode = computed(() => String(telegramConfig.value?.mode || '').trim())
const telegramEnabled = computed(() => !!telegramConfig.value?.enabled && telegramBotUsername.value !== '')
const telegramBound = computed(() => !!userProfileStore.telegramBinding?.bound)
const isTelegramMiniApp = computed(() => telegramMiniAppStore.isMiniApp && telegramMiniAppStore.isReady)
const miniAppInitData = computed(() => String(telegramMiniAppStore.initData || '').trim())
const showMiniAppBindAction = computed(() => telegramEnabled.value && !telegramBound.value && isTelegramMiniApp.value)
const showTelegramWidget = computed(() => telegramLoginMode.value !== 'oidc' && telegramEnabled.value && !telegramBound.value && !isTelegramMiniApp.value)
const showTelegramOidcBind = computed(() => telegramLoginMode.value === 'oidc' && telegramEnabled.value && !telegramBound.value && !isTelegramMiniApp.value)
const telegramMiniAppEntryLink = computed(() => buildTelegramMiniAppEntryLink(telegramBotUsername.value, telegramMiniAppURL.value))
const showTelegramMiniAppEntry = computed(() => !isTelegramMiniApp.value && telegramMiniAppEntryLink.value !== '')
const emailChangeMode = computed(() => userProfileStore.profile?.email_change_mode || 'change_with_old_and_new')
const requiresOldEmailCode = computed(() => emailChangeMode.value !== 'bind_only')
const canManagePassword = computed(() => requiresOldEmailCode.value)
const passwordChangeMode = computed(() => userProfileStore.profile?.password_change_mode || 'change_with_old')
const requiresOldPassword = computed(() => passwordChangeMode.value !== 'set_without_old')
const canUnbindTelegram = computed(() => requiresOldEmailCode.value)
const currentEmailDisplay = computed(() => {
  if (!requiresOldEmailCode.value) {
    return t('personalCenter.security.bindOnlyEmailDisplay')
  }
  return userProfileStore.profile?.email || ''
})
const telegramDisplayName = computed(() => {
  if (userProfileStore.telegramBinding?.username) {
    return `@${userProfileStore.telegramBinding.username}`
  }
  return t('personalCenter.security.telegramDisplayFallback')
})

const openTelegramMiniAppEntry = () => {
  if (telegramMiniAppEntryLink.value === '') return
  openTelegramCompatibleLink(telegramMiniAppEntryLink.value)
}

const startCooldown = (kind: 'old' | 'new') => {
  if (kind === 'old') {
    oldCodeCooldown.value = 60
  } else {
    newCodeCooldown.value = 60
  }
  if (cooldownTimer !== null) return
  cooldownTimer = window.setInterval(() => {
    if (oldCodeCooldown.value > 0) {
      oldCodeCooldown.value -= 1
    }
    if (newCodeCooldown.value > 0) {
      newCodeCooldown.value -= 1
    }
    if (oldCodeCooldown.value === 0 && newCodeCooldown.value === 0 && cooldownTimer !== null) {
      window.clearInterval(cooldownTimer)
      cooldownTimer = null
    }
  }, 1000)
}

const handleSendOldCode = async () => {
  securityAlert.value = null
  if (!requiresOldEmailCode.value) {
    securityAlert.value = {
      level: 'warning',
      message: t('personalCenter.security.bindOnlyOldCodeDisabled'),
    }
    return
  }
  const ok = await userProfileStore.sendChangeEmailCode({ kind: 'old' })
  if (!ok) {
    securityAlert.value = {
      level: 'error',
      message: userProfileStore.securityError || t('personalCenter.security.sendCodeFailed'),
    }
    return
  }
  startCooldown('old')
  securityAlert.value = {
    level: 'success',
    message: t('personalCenter.security.sendOldCodeSuccess'),
  }
}

const handleSendNewCode = async () => {
  securityAlert.value = null
  const newEmail = securityForm.newEmail.trim()
  if (!newEmail) {
    securityAlert.value = {
      level: 'warning',
      message: t('personalCenter.security.newEmailRequired'),
    }
    return
  }
  const ok = await userProfileStore.sendChangeEmailCode({ kind: 'new', new_email: newEmail })
  if (!ok) {
    securityAlert.value = {
      level: 'error',
      message: userProfileStore.securityError || t('personalCenter.security.sendCodeFailed'),
    }
    return
  }
  startCooldown('new')
  securityAlert.value = {
    level: 'success',
    message: t('personalCenter.security.sendNewCodeSuccess'),
  }
}

const handleChangeEmail = async () => {
  securityAlert.value = null
  const requiresOldCode = requiresOldEmailCode.value
  const oldCode = securityForm.oldCode.trim()
  const payload = {
    new_email: securityForm.newEmail.trim(),
    new_code: securityForm.newCode.trim(),
    ...(requiresOldCode ? { old_code: oldCode } : {}),
  }
  if (!payload.new_email || !payload.new_code || (requiresOldCode && !oldCode)) {
    securityAlert.value = {
      level: 'warning',
      message: requiresOldCode
        ? t('personalCenter.security.changeEmailRequired')
        : t('personalCenter.security.bindEmailRequired'),
    }
    return
  }

  const ok = await userProfileStore.changeEmail(payload)
  if (!ok) {
    securityAlert.value = {
      level: 'error',
      message: userProfileStore.securityError || t('personalCenter.security.changeEmailFailed'),
    }
    return
  }

  securityForm.newEmail = ''
  securityForm.oldCode = ''
  securityForm.newCode = ''
  oldCodeCooldown.value = 0
  newCodeCooldown.value = 0
  securityAlert.value = {
    level: 'success',
    message: requiresOldCode
      ? t('personalCenter.security.changeEmailSuccess')
      : t('personalCenter.security.bindEmailSuccess'),
  }
}

const handleChangePassword = async () => {
  securityAlert.value = null
  const oldPassword = passwordForm.oldPassword.trim()
  const newPassword = passwordForm.newPassword.trim()
  const confirmPassword = passwordForm.confirmPassword.trim()
  const needOldPassword = requiresOldPassword.value

  if (!newPassword || !confirmPassword || (needOldPassword && !oldPassword)) {
    securityAlert.value = {
      level: 'warning',
      message: needOldPassword
        ? t('personalCenter.security.changePasswordRequired')
        : t('personalCenter.security.setPasswordRequired'),
    }
    return
  }

  if (newPassword !== confirmPassword) {
    securityAlert.value = {
      level: 'warning',
      message: t('personalCenter.security.passwordMismatch'),
    }
    return
  }

  const payload = {
    ...(needOldPassword ? { old_password: oldPassword } : {}),
    new_password: newPassword,
  }
  const ok = await userProfileStore.changePassword(payload)

  if (!ok) {
    securityAlert.value = {
      level: 'error',
      message: userProfileStore.securityError || t('personalCenter.security.changePasswordFailed'),
    }
    return
  }

  passwordForm.oldPassword = ''
  passwordForm.newPassword = ''
  passwordForm.confirmPassword = ''
  securityAlert.value = {
    level: 'success',
    message: needOldPassword
      ? t('personalCenter.security.changePasswordSuccess')
      : t('personalCenter.security.setPasswordSuccess'),
  }

  userAuthStore.logout('/auth/login?reason=password_changed')
}

const buildTelegramPayload = (raw: any): TelegramAuthPayload | null => {
  const id = Number(raw?.id)
  const authDate = Number(raw?.auth_date)
  const hash = String(raw?.hash || '').trim()
  if (!Number.isFinite(id) || id <= 0 || !Number.isFinite(authDate) || authDate <= 0 || hash === '') {
    return null
  }
  return {
    id,
    first_name: String(raw?.first_name || '').trim(),
    last_name: String(raw?.last_name || '').trim(),
    username: String(raw?.username || '').trim(),
    photo_url: String(raw?.photo_url || '').trim(),
    auth_date: authDate,
    hash,
  }
}

const clearTelegramWidget = () => {
  const widgetEl = telegramSectionRef.value?.telegramWidgetRef
  if (widgetEl) {
    widgetEl.innerHTML = ''
  }
}

const renderTelegramWidget = () => {
  if (telegramLoginMode.value === 'oidc') {
    clearTelegramWidget()
    return
  }
  const widgetEl = telegramSectionRef.value?.telegramWidgetRef
  if (!showTelegramWidget.value || !widgetEl) {
    clearTelegramWidget()
    return
  }
  clearTelegramWidget()
  const script = document.createElement('script')
  script.async = true
  script.src = 'https://telegram.org/js/telegram-widget.js?22'
  script.setAttribute('data-telegram-login', telegramBotUsername.value)
  script.setAttribute('data-size', 'large')
  script.setAttribute('data-userpic', 'false')
  script.setAttribute('data-request-access', 'write')
  script.setAttribute('data-onauth', `${telegramCallbackName}(user)`)
  script.onerror = () => {
    securityAlert.value = {
      level: 'error',
      message: t('personalCenter.security.telegramWidgetLoadFailed'),
    }
  }
  widgetEl.appendChild(script)
}

const handleTelegramBind = async (raw: any) => {
  securityAlert.value = null
  const payload = buildTelegramPayload(raw)
  if (!payload) {
    securityAlert.value = {
      level: 'warning',
      message: t('personalCenter.security.telegramInvalidPayload'),
    }
    return
  }
  const ok = await userProfileStore.bindTelegram(payload)
  if (!ok) {
    securityAlert.value = {
      level: 'error',
      message: userProfileStore.securityError || t('personalCenter.security.telegramBindFailed'),
    }
    return
  }
  securityAlert.value = {
    level: 'success',
    message: t('personalCenter.security.telegramBindSuccess'),
  }
  renderTelegramWidget()
}

const handleTelegramMiniAppBind = async () => {
  securityAlert.value = null
  if (miniAppInitData.value === '') {
    securityAlert.value = {
      level: 'warning',
      message: t('personalCenter.security.telegramMiniAppInitDataMissing'),
    }
    return
  }

  const ok = await userProfileStore.bindTelegramMiniApp(miniAppInitData.value)
  if (!ok) {
    securityAlert.value = {
      level: 'error',
      message: userProfileStore.securityError || t('personalCenter.security.telegramBindFailed'),
    }
    return
  }

  securityAlert.value = {
    level: 'success',
    message: t('personalCenter.security.telegramBindSuccess'),
  }
}

const startTelegramOidcBind = async () => {
  securityAlert.value = null
  try {
    sessionStorage.setItem('tg_oidc_intent', 'bind')
    const res = await userProfileAPI.telegramOidcBindStart()
    const url = String(res?.data?.data?.auth_url || '')
    if (!url) {
      securityAlert.value = {
        level: 'error',
        message: t('personalCenter.security.telegramOidcBindFailed'),
      }
      return
    }
    window.location.href = url
  } catch (err: any) {
    securityAlert.value = {
      level: 'error',
      message: err?.message || t('personalCenter.security.telegramOidcBindFailed'),
    }
  }
}

const handleUnbindTelegram = async () => {
  securityAlert.value = null
  const ok = await userProfileStore.unbindTelegram()
  if (!ok) {
    securityAlert.value = {
      level: 'error',
      message: userProfileStore.securityError || t('personalCenter.security.telegramUnbindFailed'),
    }
    return
  }
  securityAlert.value = {
    level: 'success',
    message: t('personalCenter.security.telegramUnbindSuccess'),
  }
  renderTelegramWidget()
}

const formatDate = (raw?: string | null) => {
  return formatSiteDateTime(raw)
}

onMounted(async () => {
  await Promise.all([
    appStore.loadConfig(),
    userProfileStore.loadRecentLoginLogs(10),
    userProfileStore.loadTelegramBinding(),
  ])
  const win = window as Window & Record<string, any>
  win[telegramCallbackName] = handleTelegramBind
  renderTelegramWidget()

  if (route.query.tgBound === '1') {
    await userProfileStore.loadTelegramBinding()
    securityAlert.value = {
      level: 'success',
      message: t('personalCenter.security.telegramBoundOk'),
    }
    const nextQuery = { ...route.query }
    delete nextQuery.tgBound
    router.replace({ path: route.path, query: nextQuery })
  }
})

onUnmounted(() => {
  const win = window as Window & Record<string, any>
  delete win[telegramCallbackName]
  clearTelegramWidget()
  if (cooldownTimer !== null) {
    window.clearInterval(cooldownTimer)
    cooldownTimer = null
  }
})

watch([showTelegramWidget, telegramBotUsername], () => {
  renderTelegramWidget()
})
</script>

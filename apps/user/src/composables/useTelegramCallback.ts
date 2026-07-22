import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useUserAuthStore } from '../stores/userAuth'
import { userProfileAPI } from '../api'

/**
 * Telegram OIDC 回调页共享逻辑（classic + vault 双模板共用）。
 * 完整保留原 views/auth/TelegramCallback.vue 的行为，仅抽离为 composable。
 */
export function useTelegramCallback() {
  const { t } = useI18n()
  const route = useRoute()
  const router = useRouter()
  const userAuthStore = useUserAuthStore()
  const loading = ref(true)
  const errMsg = ref('')

  onMounted(async () => {
    const code = String(route.query.code || '')
    const state = String(route.query.state || '')
    const oauthErr = String(route.query.error || '')
    const intent = sessionStorage.getItem('tg_oidc_intent') || 'login'
    const savedRedirect = sessionStorage.getItem('tg_oidc_redirect') || ''
    sessionStorage.removeItem('tg_oidc_intent')
    sessionStorage.removeItem('tg_oidc_redirect')

    if (oauthErr || !code || !state) {
      errMsg.value = t('auth.telegramCallback.failed')
      loading.value = false
      return
    }

    try {
      if (intent === 'bind') {
        await userProfileAPI.telegramOidcBindCallback({ code, state })
        await router.replace({ path: '/me/security', query: { tgBound: '1' } })
        return
      }
      const result = await userAuthStore.telegramOidcLogin({ code, state })
      if (result?.requiresTotp) {
        const query: Record<string, string> = { tg2fa: '1' }
        if (savedRedirect) {
          query.redirect = savedRedirect
        }
        await router.replace({ path: '/auth/login', query })
        return
      }
      await router.replace(savedRedirect || '/me/orders')
    } catch (err: any) {
      errMsg.value = err?.message || t('auth.telegramCallback.failed')
      loading.value = false
    }
  })

  return {
    loading,
    errMsg,
  }
}

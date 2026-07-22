import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { guestOrderAPI } from '../api'
import { debounceAsync } from '../utils/debounce'
import { useOrderDisplayHelpers } from './useOrderDisplayHelpers'

/**
 * 游客订单详情逻辑（classic + vault 共用）。
 */
export function useGuestOrderDetail() {
  const route = useRoute()
  const router = useRouter()
  const { t } = useI18n()

  const loading = ref(true)
  const order = ref<any>(null)
  const authError = ref('')
  const auth = ref({
    email: '',
    order_password: '',
  })
  const fulfillmentDownloading = ref(false)

  const helpers = useOrderDisplayHelpers(order)

  const handleDownloadFulfillment = async (orderNo: string) => {
    if (fulfillmentDownloading.value) return
    fulfillmentDownloading.value = true
    try {
      const res = await guestOrderAPI.downloadFulfillment(orderNo, {
        email: auth.value.email,
        order_password: auth.value.order_password,
      })
      const blob = new Blob([res.data], { type: 'text/plain; charset=utf-8' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `fulfillment-${orderNo}.txt`
      a.click()
      URL.revokeObjectURL(url)
    } catch {} finally {
      fulfillmentDownloading.value = false
    }
  }

  const loadSavedAuth = () => {
    const saved = localStorage.getItem('guest_order_auth')
    const savedAuth = saved ? JSON.parse(saved) : {}
    auth.value = {
      email: savedAuth.email || '',
      order_password: savedAuth.order_password || '',
    }
  }

  const hasAuth = computed(() => Boolean(auth.value.email && auth.value.order_password))
  const showAuthForm = computed(() => !hasAuth.value || authError.value !== '')

  const loadOrder = async () => {
    loading.value = true
    try {
      if (!hasAuth.value) {
        order.value = null
        authError.value = t('guestOrderDetail.authRequired')
        return
      }
      const response = await guestOrderAPI.detail(String(route.params.order_no || '').trim(), {
        email: auth.value.email,
        order_password: auth.value.order_password,
      })
      order.value = response.data.data
      authError.value = ''
    } catch (error) {
      order.value = null
      authError.value = t('guestOrderDetail.authInvalid')
    } finally {
      loading.value = false
    }
  }

  const debouncedLoadOrder = debounceAsync(loadOrder, 300)

  const persistAuth = () => {
    localStorage.setItem('guest_order_auth', JSON.stringify({
      email: auth.value.email,
      order_password: auth.value.order_password,
    }))
  }

  const handleAuthSubmit = async () => {
    authError.value = ''
    if (!hasAuth.value) {
      authError.value = t('guestOrderDetail.authRequired')
      return
    }
    persistAuth()
    await debouncedLoadOrder()
  }

  const clearAuth = () => {
    localStorage.removeItem('guest_order_auth')
    auth.value = { email: '', order_password: '' }
    order.value = null
    authError.value = t('guestOrderDetail.authRequired')
  }

  onMounted(() => {
    if (!route.params.order_no) {
      router.push('/guest/orders')
      return
    }
    loadSavedAuth()
    loadOrder()
  })

  onUnmounted(() => {
    debouncedLoadOrder.cancel()
  })

  return {
    loading,
    order,
    authError,
    auth,
    showAuthForm,
    handleAuthSubmit,
    clearAuth,
    fulfillmentDownloading,
    handleDownloadFulfillment,
    ...helpers,
  }
}

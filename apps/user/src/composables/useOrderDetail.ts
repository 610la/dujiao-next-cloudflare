import { onMounted, onUnmounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { userOrderAPI } from '../api'
import { debounceAsync } from '../utils/debounce'
import { useConfirmDialog } from './useConfirmDialog'
import { toast } from './useToast'
import { useOrderDisplayHelpers } from './useOrderDisplayHelpers'

/**
 * 已登录用户订单详情逻辑（classic + vault 共用）。
 */
export function useOrderDetail() {
  const route = useRoute()
  const router = useRouter()
  const { confirm: showConfirm } = useConfirmDialog()
  const { t } = useI18n()

  const loading = ref(true)
  const order = ref<any>(null)
  const fulfillmentDownloading = ref(false)

  const helpers = useOrderDisplayHelpers(order)

  const handleDownloadFulfillment = async (orderNo: string) => {
    if (fulfillmentDownloading.value) return
    fulfillmentDownloading.value = true
    try {
      const res = await userOrderAPI.downloadFulfillment(orderNo)
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

  const loadOrder = async () => {
    loading.value = true
    try {
      const response = await userOrderAPI.detail(String(route.params.order_no || '').trim())
      order.value = response.data.data
    } catch (error) {
      order.value = null
    } finally {
      loading.value = false
    }
  }

  const debouncedLoadOrder = debounceAsync(loadOrder, 300)

  const cancelOrder = async () => {
    if (!order.value) return
    const confirmed = await showConfirm({
      title: t('orderDetail.cancel'),
      message: t('orderDetail.cancelConfirm'),
      confirmText: t('common.confirm'),
      cancelText: t('common.cancel'),
      variant: 'danger',
    })
    if (!confirmed) return
    try {
      await userOrderAPI.cancel(order.value.order_no)
      await debouncedLoadOrder()
    } catch {
      toast.error(t('orderDetail.cancelFailed'))
    }
  }

  onMounted(() => {
    if (!route.params.order_no) {
      router.push('/me/orders')
      return
    }
    loadOrder()
  })

  onUnmounted(() => {
    debouncedLoadOrder.cancel()
  })

  return {
    loading,
    order,
    debouncedLoadOrder,
    cancelOrder,
    fulfillmentDownloading,
    handleDownloadFulfillment,
    ...helpers,
  }
}

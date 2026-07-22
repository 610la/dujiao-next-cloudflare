<template>
  <div class="space-y-6">
    <WalletBalanceCard
      :alert="walletAlert"
      :balance-display="balanceDisplay"
      :total-transactions="pagination.total"
      :current-page="pagination.page"
      :total-pages="pagination.total_page"
    />

    <WalletRechargeForm
      :amount="rechargeForm.amount"
      :channel-id="rechargeForm.channelId"
      :remark="rechargeForm.remark"
      :channels="channels"
      :has-channels="hasChannels"
      :recharging="recharging"
      :channel-loading="channelLoading"
      :selected-channel="selectedChannel"
      :fee-rate-display="selectedChannelFeeRateDisplay"
      :fixed-fee-display="selectedChannelFixedFeeDisplay"
      :fee-amount-display="selectedChannelFeeAmountDisplay"
      @update:amount="rechargeForm.amount = $event"
      @update:channel-id="rechargeForm.channelId = $event"
      @update:remark="rechargeForm.remark = $event"
      @submit="handleRecharge"
    />

    <WalletTransactionList
      :loading="loading"
      :transactions="transactions"
      :current-page="pagination.page"
      :total-pages="pagination.total_page"
      @refresh="refreshCurrentPage"
      @change-page="changePage"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { walletAPI } from '../../api'
import { useAppStore } from '../../stores/app'
import type { PageAlert } from '../../utils/alerts'
import { amountToCents, basisPointsToPercent, calculateFeeCents, centsToAmount, rateToBasisPoints } from '../../utils/money'
import WalletBalanceCard from '../../components/wallet/WalletBalanceCard.vue'
import WalletRechargeForm from '../../components/wallet/WalletRechargeForm.vue'
import WalletTransactionList from '../../components/wallet/WalletTransactionList.vue'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

const loading = ref(true)
const recharging = ref(false)
const wallet = ref<any>(null)
const transactions = ref<any[]>([])
const pagination = ref({
  page: 1,
  page_size: 20,
  total: 0,
  total_page: 1,
})
const walletAlert = ref<PageAlert | null>(null)
const channels = ref<any[]>([])
const channelFetchTimer = ref<number | null>(null)
const channelFetchSeq = ref(0)
const channelLoading = ref(false)
const channelsResolvedAmount = ref('')

const rechargeForm = reactive({
  amount: '',
  channelId: 0,
  remark: '',
})

const hasChannels = computed(() => {
  const amount = rechargeForm.amount.trim()
  const amountCents = amountToCents(amount)
  if (!amount || amountCents === null || amountCents <= 0) {
    return true
  }
  if (channelLoading.value) {
    return true
  }
  if (channelsResolvedAmount.value !== amount) {
    return true
  }
  return channels.value.length > 0
})

const selectedChannel = computed(() => channels.value.find((item: any) => item.id === rechargeForm.channelId) || null)

const EPAY_ALLOWED_CHANNEL_TYPES = new Set(['wechat', 'wxpay', 'alipay', 'qqpay'])

const channelLimitMeta = (channel?: any) => {
  const minCents = amountToCents(String(channel?.min_amount ?? ''))
  const maxCents = amountToCents(String(channel?.max_amount ?? ''))
  return {
    minCents,
    maxCents,
    hasMin: minCents !== null && minCents > 0,
    hasMax: maxCents !== null && maxCents > 0,
  }
}

const isSupportedEpayChannel = (channel: any) => {
  const providerType = String(channel?.provider_type || '').toLowerCase()
  if (providerType !== 'epay') return true
  const channelType = String(channel?.channel_type || '').toLowerCase()
  return EPAY_ALLOWED_CHANNEL_TYPES.has(channelType)
}

const isChannelOutOfRange = (channel: any, targetAmountCents: number) => {
  const meta = channelLimitMeta(channel)
  if (!meta.hasMin && !meta.hasMax) return false
  const lessThanMin = meta.hasMin && meta.minCents !== null && targetAmountCents < meta.minCents
  const greaterThanMax = meta.hasMax && meta.maxCents !== null && targetAmountCents > meta.maxCents
  return Boolean(lessThanMin || greaterThanMax)
}

const shouldHideChannelForAmount = (channel: any, targetAmountCents: number) => {
  if (!Boolean(channel?.hide_amount_out_range)) return false
  return isChannelOutOfRange(channel, targetAmountCents)
}

const getAllowedChannelIdSet = () => {
  const allowedIds = appStore.config?.wallet_recharge_channel_ids
  if (!Array.isArray(allowedIds) || allowedIds.length === 0) return null
  return new Set(allowedIds.map(Number))
}

const isChannelAllowedByConfig = (channel: any, allowedIdSet: Set<number> | null) => {
  if (!allowedIdSet) return true
  return allowedIdSet.has(Number(channel?.id))
}

const mapChannel = (channel: any) => ({
  id: Number(channel.id),
  name: String(channel.name || channel.channel_type || channel.id),
  channel_type: String(channel.channel_type || ''),
  fee_rate: String(channel.fee_rate ?? '0'),
  fixed_fee: String(channel.fixed_fee ?? '0'),
  min_amount: String(channel.min_amount ?? '0'),
  max_amount: String(channel.max_amount ?? '0'),
  hide_amount_out_range: Boolean(channel.hide_amount_out_range),
})

const normalizeChannels = (list: any[], targetAmountCents: number) => {
  const allowedIdSet = getAllowedChannelIdSet()
  return list
    .filter((channel: any) => isSupportedEpayChannel(channel))
    .filter((channel: any) => !shouldHideChannelForAmount(channel, targetAmountCents))
    .filter((channel: any) => isChannelAllowedByConfig(channel, allowedIdSet))
    .map(mapChannel)
    .filter((channel: any) => Number.isFinite(channel.id) && channel.id > 0)
}

const getSelectedChannelAmountHint = (channel: any, amountCents: number) => {
  if (!isChannelOutOfRange(channel, amountCents)) return ''

  const meta = channelLimitMeta(channel)
  if (meta.hasMin && meta.hasMax && meta.minCents !== null && meta.maxCents !== null) {
    return t('payment.channelAmountLimitHint', {
      min: formatMoney(centsToAmount(meta.minCents), selectedChannelCurrency.value),
      max: formatMoney(centsToAmount(meta.maxCents), selectedChannelCurrency.value),
    })
  }
  if (meta.hasMin && meta.minCents !== null) {
    return t('payment.channelAmountMinHint', {
      min: formatMoney(centsToAmount(meta.minCents), selectedChannelCurrency.value),
    })
  }
  if (meta.hasMax && meta.maxCents !== null) {
    return t('payment.channelAmountMaxHint', {
      max: formatMoney(centsToAmount(meta.maxCents), selectedChannelCurrency.value),
    })
  }
  return ''
}

const selectedChannelAmountHint = computed(() => {
  const channel = selectedChannel.value
  if (!channel) return ''
  const amountCents = amountToCents(rechargeForm.amount.trim())
  if (amountCents === null || amountCents <= 0) return ''
  return getSelectedChannelAmountHint(channel, amountCents)
})

const loadPaymentChannels = async (seq: number, amount: string) => {
  if (seq !== channelFetchSeq.value) return
  const amountCents = amountToCents(amount)
  if (!amount || amountCents === null || amountCents <= 0) {
    if (seq !== channelFetchSeq.value) return
    channels.value = []
    channelsResolvedAmount.value = ''
    return
  }

  try {
    const response = await walletAPI.getPaymentChannels(amount)
    if (seq !== channelFetchSeq.value) return
    const list = Array.isArray(response.data.data) ? response.data.data : []
    channels.value = normalizeChannels(list, amountCents)
  } catch {
    if (seq !== channelFetchSeq.value) return
    channels.value = []
  } finally {
    if (seq === channelFetchSeq.value) {
      channelsResolvedAmount.value = amount
      channelLoading.value = false
    }
  }
}

const scheduleLoadPaymentChannels = () => {
  const amount = rechargeForm.amount.trim()
  const amountCents = amountToCents(amount)
  if (!amount || amountCents === null || amountCents <= 0) {
    channelFetchSeq.value += 1
    if (channelFetchTimer.value) {
      window.clearTimeout(channelFetchTimer.value)
      channelFetchTimer.value = null
    }
    channelLoading.value = false
    channelsResolvedAmount.value = ''
    channels.value = []
    return
  }

  const seq = channelFetchSeq.value + 1
  channelFetchSeq.value = seq
  channelLoading.value = true

  if (channelFetchTimer.value) {
    window.clearTimeout(channelFetchTimer.value)
    channelFetchTimer.value = null
  }
  channelFetchTimer.value = window.setTimeout(() => {
    channelFetchTimer.value = null
    void loadPaymentChannels(seq, amount)
  }, 300)
}

const formatMoney = (amount?: string, currency?: string) => {
  if (amount === null || amount === undefined || amount === '') return '-'
  if (currency === null || currency === undefined || currency === '') {
    return String(amount)
  }
  return `${amount} ${currency}`
}

const selectedChannelCurrency = computed(() => String(appStore.config?.currency || 'CNY'))
const selectedChannelFeeRateDisplay = computed(() => {
  const rate = rateToBasisPoints(selectedChannel.value?.fee_rate)
  if (rate === null) return '0.00%'
  return `${basisPointsToPercent(rate)}%`
})
const selectedChannelFixedFeeDisplay = computed(() => {
  return formatMoney(String(selectedChannel.value?.fixed_fee ?? '0.00'), selectedChannelCurrency.value)
})
const selectedChannelFeeAmountDisplay = computed(() => {
  const amountCents = amountToCents(rechargeForm.amount)
  if (amountCents === null || amountCents <= 0) return formatMoney('0.00', selectedChannelCurrency.value)
  const rate = rateToBasisPoints(selectedChannel.value?.fee_rate) || 0
  const fixedFeeCents = amountToCents(selectedChannel.value?.fixed_fee) || 0
  const variableFeeCents = calculateFeeCents(amountCents, rate) || 0
  return formatMoney(centsToAmount(variableFeeCents + fixedFeeCents), selectedChannelCurrency.value)
})

const balanceDisplay = computed(() => formatMoney(wallet.value?.balance, String(appStore.config?.currency || 'CNY')))

const loadWallet = async () => {
  const response = await walletAPI.account()
  wallet.value = response.data.data
}

const loadTransactions = async (page = 1) => {
  loading.value = true
  try {
    const response = await walletAPI.transactions({
      page,
      page_size: pagination.value.page_size,
    })
    transactions.value = response.data.data || []
    pagination.value = response.data.pagination || pagination.value
  } catch {
    transactions.value = []
  } finally {
    loading.value = false
  }
}

const handleRecharge = async () => {
  walletAlert.value = null
  const amount = rechargeForm.amount.trim()
  const amountCents = amountToCents(amount)
  if (!amount || amountCents === null || amountCents <= 0) {
    walletAlert.value = {
      level: 'warning',
      message: t('personalCenter.wallet.errors.invalidAmount'),
    }
    return
  }
  if (!Number.isFinite(rechargeForm.channelId) || rechargeForm.channelId <= 0) {
    walletAlert.value = {
      level: 'warning',
      message: t('personalCenter.wallet.errors.channelRequired'),
    }
    return
  }
  if (selectedChannelAmountHint.value) {
    walletAlert.value = {
      level: 'warning',
      message: selectedChannelAmountHint.value,
    }
    return
  }

  recharging.value = true
  try {
    const response = await walletAPI.recharge({
      amount,
      channel_id: rechargeForm.channelId,
      remark: rechargeForm.remark.trim() || undefined,
    })
    const payload = response.data.data || {}
    const rechargeNo = payload?.recharge?.recharge_no || payload?.recharge_no || ''
    rechargeForm.amount = ''
    rechargeForm.remark = ''
    if (rechargeNo) {
      router.push(`/recharge-orders/${encodeURIComponent(rechargeNo)}`)
    } else {
      walletAlert.value = {
        level: 'success',
        message: t('personalCenter.wallet.createPaymentSuccess'),
      }
    }
  } catch (err: any) {
    walletAlert.value = {
      level: 'error',
      message: err?.message || t('personalCenter.wallet.errors.rechargeFailed'),
    }
  } finally {
    recharging.value = false
  }
}

const changePage = (page: number) => {
  if (page < 1 || page > pagination.value.total_page) return
  loadTransactions(page)
}

const refreshCurrentPage = async () => {
  await Promise.all([
    loadWallet(),
    loadTransactions(pagination.value.page),
  ])
}

// 支付网关回调可能带 recharge_no 回到 /me/wallet，重定向到充值详情页
const redirectRechargeReturn = () => {
  const query = route.query as Record<string, unknown>
  const rechargeNo = String(query.recharge_no || '').trim()
  const orderNo = String(query.order_no || '').trim()
  const targetNo = rechargeNo || (/^WR/i.test(orderNo) ? orderNo : '')
  if (targetNo) {
    router.replace(`/recharge-orders/${encodeURIComponent(targetNo)}${window.location.search}`)
  }
}

const initialize = async () => {
  walletAlert.value = null
  try {
    if (!appStore.config) {
      await appStore.loadConfig()
    }
    await Promise.all([
      loadWallet(),
      loadTransactions(),
    ])
    redirectRechargeReturn()
  } catch (err: any) {
    walletAlert.value = {
      level: 'error',
      message: err?.message || t('personalCenter.wallet.errors.loadFailed'),
    }
  }
}

watch(() => rechargeForm.amount, () => {
  scheduleLoadPaymentChannels()
}, { immediate: true })

watch(
  channels,
  (list) => {
    if (list.length === 0) {
      rechargeForm.channelId = 0
      return
    }
    if (!list.some((item: any) => item.id === rechargeForm.channelId)) {
      const first = list[0]
      if (!first) {
        rechargeForm.channelId = 0
        return
      }
      rechargeForm.channelId = first.id
    }
  },
  { immediate: true }
)

onMounted(() => {
  void initialize()
})

onUnmounted(() => {
  channelFetchSeq.value += 1
  if (channelFetchTimer.value) {
    window.clearTimeout(channelFetchTimer.value)
    channelFetchTimer.value = null
  }
  channelLoading.value = false
})
</script>

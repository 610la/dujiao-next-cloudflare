import { userApi } from './client'
import type {
    WalletRechargePayload,
    CaptchaPayload,
} from './types'

export const walletAPI = {
    getPaymentChannels: (amount: string) => userApi.post('/wallet/payment-channels', { amount }),
    account: () => userApi.get('/wallet'),
    transactions: (params?: any) => userApi.get('/wallet/transactions', { params }),
    recharge: (data: WalletRechargePayload) => userApi.post('/wallet/recharge', data),
    rechargeOrders: (params?: any) => userApi.get('/wallet/recharges', { params }),
    rechargeStats: (params?: any) => userApi.get('/wallet/recharges/stats', { params }),
    rechargeDetail: (rechargeNo: string) =>
        userApi.get(`/wallet/recharges/${encodeURIComponent(rechargeNo)}`),
    captureRechargePayment: (paymentID: number) =>
        userApi.post(`/wallet/recharge/payments/${paymentID}/capture`),
}

export const giftCardAPI = {
    redeem: (data: { code: string; captcha_payload?: CaptchaPayload }) =>
        userApi.post('/gift-cards/redeem', data),
}

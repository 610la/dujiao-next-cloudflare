import { userApi } from './client'
import type { CreatePaymentPayload } from './types'

export const userOrderAPI = {
    preview: (data: any) => userApi.post('/orders/preview', data),
    getPaymentChannels: (data: any) => userApi.post('/order/payment-channels', data),
    create: (data: any) => userApi.post('/orders', data),
    createAndPay: (data: any) => userApi.post('/orders/create-and-pay', data, { timeoutMs: 30000 }),
    checkoutResult: (requestId: string) => userApi.get(`/orders/checkout-requests/${encodeURIComponent(requestId)}`),
    list: (params?: any) => userApi.get('/orders', { params }),
    stats: (params?: any) => userApi.get('/orders/stats', { params }),
    detail: (orderNo: string, options?: any) => userApi.get(`/orders/${encodeURIComponent(orderNo)}`, options),
    cancel: (orderNo: string) => userApi.post(`/orders/${encodeURIComponent(orderNo)}/cancel`),
    downloadFulfillment: (orderNo: string) => userApi.get(`/orders/${encodeURIComponent(orderNo)}/fulfillment/download`, { blob: true }),
}

export const guestOrderAPI = {
    preview: (data: any) => userApi.post('/guest/orders/preview', data),
    create: (data: any) => userApi.post('/guest/orders', data),
    createAndPay: (data: any) => userApi.post('/guest/orders/create-and-pay', data, { timeoutMs: 30000 }),
    checkoutResult: (requestId: string, params: any) => userApi.get(`/guest/orders/checkout-requests/${encodeURIComponent(requestId)}`, { params }),
    list: (params: any) => userApi.get('/guest/orders', { params }),
    detail: (orderNo: string, params: any, options?: any) => userApi.get(`/guest/orders/${encodeURIComponent(orderNo)}`, { params, ...(options || {}) }),
    downloadFulfillment: (orderNo: string, params: any) => userApi.get(`/guest/orders/${encodeURIComponent(orderNo)}/fulfillment/download`, { params, blob: true }),
    createPayment: (data: any) => userApi.post('/guest/payments', data),
    capturePayment: (id: number, data: any) => userApi.post(`/guest/payments/${id}/capture`, data),
    latestPayment: (params: any) => userApi.get('/guest/payments/latest', { params, silentBusinessError: true }),
}

export const paymentAPI = {
    create: (data: CreatePaymentPayload) => userApi.post('/payments', data),
    capture: (id: number) => userApi.post(`/payments/${id}/capture`),
    latest: (params: any) => userApi.get('/payments/latest', { params, silentBusinessError: true }),
}

import { api, userApi } from './client'
import type { TelegramAuthPayload, TelegramMiniAppAuthPayload } from './types'

export const userAuthAPI = {
    sendVerifyCode: (data: any) => userApi.post('/auth/send-verify-code', data),
    register: (data: any) => userApi.post('/auth/register', data),
    login: (data: any) => userApi.post('/auth/login', data),
    verify2FA: (data: { challenge_token: string; code?: string; recovery_code?: string }) =>
        userApi.post('/auth/login/verify-2fa', data),
    telegramLogin: (data: TelegramAuthPayload) => userApi.post('/auth/telegram/login', data),
    telegramMiniAppLogin: (data: TelegramMiniAppAuthPayload) =>
        userApi.post('/auth/telegram/miniapp/login', data),
    telegramOidcStart: () => userApi.get('/auth/telegram/oidc/start'),
    telegramOidcCallback: (data: { code: string; state: string }) =>
        userApi.post('/auth/telegram/oidc/callback', data),
    forgotPassword: (data: any) => userApi.post('/auth/forgot-password', data),
}

export const userTotpAPI = {
    status: () => userApi.get('/me/2fa/status'),
    setup: () => userApi.post('/me/2fa/setup', {}),
    enable: (data: { code: string }) => userApi.post('/me/2fa/enable', data),
    disable: (data: { code?: string; recovery_code?: string }) => userApi.post('/me/2fa/disable', data),
    regenerateRecoveryCodes: (data: { code: string }) =>
        userApi.post('/me/2fa/recovery-codes/regenerate', data),
}

export const captchaAPI = {
    image: () => api.get('/public/captcha/image'),
}

export const configAPI = {
    get: () => api.get('/public/config'),
}

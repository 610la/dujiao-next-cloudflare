import { userApi } from './client'
import type {
    UpdateUserProfilePayload,
    SendChangeEmailCodePayload,
    ChangeEmailPayload,
    ChangeUserPasswordPayload,
    TelegramAuthPayload,
    TelegramMiniAppAuthPayload,
} from './types'

export const userProfileAPI = {
    current: () => userApi.get('/me'),
    loginLogs: (params?: any) => userApi.get('/me/login-logs', { params }),
    updateProfile: (data: UpdateUserProfilePayload) => userApi.put('/me/profile', data),
    sendChangeEmailCode: (data: SendChangeEmailCodePayload) => userApi.post('/me/email/send-verify-code', data),
    changeEmail: (data: ChangeEmailPayload) => userApi.post('/me/email/change', data),
    changePassword: (data: ChangeUserPasswordPayload) => userApi.put('/me/password', data),
    getTelegramBinding: () => userApi.get('/me/telegram'),
    bindTelegram: (data: TelegramAuthPayload) => userApi.post('/me/telegram/bind', data),
    bindTelegramMiniApp: (data: TelegramMiniAppAuthPayload) =>
        userApi.post('/me/telegram/miniapp/bind', data),
    telegramOidcBindStart: () => userApi.get('/me/telegram/oidc/start'),
    telegramOidcBindCallback: (data: { code: string; state: string }) =>
        userApi.post('/me/telegram/oidc/callback', data),
    unbindTelegram: () => userApi.delete('/me/telegram/unbind'),
}

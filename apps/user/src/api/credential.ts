import { userApi } from './client'

export const apiCredentialAPI = {
    getMy: () => userApi.get('/api-credential'),
    apply: () => userApi.post('/api-credential/apply'),
    regenerate: () => userApi.post('/api-credential/regenerate'),
    updateStatus: (data: { is_active: boolean }) => userApi.put('/api-credential/status', data),
}

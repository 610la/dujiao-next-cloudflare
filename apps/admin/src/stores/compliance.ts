import { defineStore } from 'pinia'
import { adminAPI, type ComplianceStatus } from '@/api/admin'

interface State {
  acknowledged: boolean
  acknowledgedAt: string
  acknowledgedByUsername: string
  loaded: boolean
  loading: boolean
}

export const useComplianceStore = defineStore('compliance', {
  state: (): State => ({
    acknowledged: false,
    acknowledgedAt: '',
    acknowledgedByUsername: '',
    loaded: false,
    loading: false,
  }),
  actions: {
    async fetchStatus(force = false): Promise<void> {
      if (this.loaded && !force) return
      this.loading = true
      try {
        const res = await adminAPI.getComplianceStatus()
        const status: ComplianceStatus = res.data?.data ?? {}
        this.acknowledged = !!status.acknowledged
        this.acknowledgedAt = status.acknowledged_at ?? ''
        this.acknowledgedByUsername = status.acknowledged_by_username ?? ''
        this.loaded = true
      } finally {
        this.loading = false
      }
    },
    async acknowledge(segment1: string, segment2: string, segment3: string): Promise<void> {
      await adminAPI.acknowledgeCompliance({ segment1, segment2, segment3 })
      await this.fetchStatus(true)
    },
    reset(): void {
      this.acknowledged = false
      this.acknowledgedAt = ''
      this.acknowledgedByUsername = ''
      this.loaded = false
    },
  },
})

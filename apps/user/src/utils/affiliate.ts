import type { RouteLocationNormalizedLoaded, RouteLocationNormalized } from 'vue-router'
import { affiliateAPI } from '../api'
import { useAppStore } from '../stores/app'

const AFFILIATE_STORAGE_KEY = 'dj_affiliate_attribution'
const AFFILIATE_VISITOR_KEY = 'dj_affiliate_visitor_key'
const AFFILIATE_TTL_MS = 30 * 24 * 60 * 60 * 1000

type AffiliateAttribution = {
    code: string
    expires_at: number
}

const normalizeAffiliateCode = (raw: string) => {
    const value = String(raw || '').trim().toUpperCase()
    if (!/^[A-Z0-9]{4,32}$/.test(value)) {
        return ''
    }
    return value
}

const readAttribution = (): AffiliateAttribution | null => {
    if (typeof window === 'undefined') return null
    const raw = localStorage.getItem(AFFILIATE_STORAGE_KEY)
    if (!raw) return null
    try {
        const parsed = JSON.parse(raw) as Partial<AffiliateAttribution>
        const code = normalizeAffiliateCode(String(parsed.code || ''))
        const expiresAt = Number(parsed.expires_at || 0)
        const appStore = useAppStore()
        if (!code || !Number.isFinite(expiresAt) || expiresAt <= appStore.getServerTime()) {
            localStorage.removeItem(AFFILIATE_STORAGE_KEY)
            return null
        }
        return {
            code,
            expires_at: expiresAt,
        }
    } catch {
        localStorage.removeItem(AFFILIATE_STORAGE_KEY)
        return null
    }
}

const writeAttribution = (code: string) => {
    if (typeof window === 'undefined') return
    const payload: AffiliateAttribution = {
        code,
        expires_at: useAppStore().getServerTime() + AFFILIATE_TTL_MS,
    }
    localStorage.setItem(AFFILIATE_STORAGE_KEY, JSON.stringify(payload))
}

const ensureVisitorKey = () => {
    if (typeof window === 'undefined') return ''
    const existing = String(localStorage.getItem(AFFILIATE_VISITOR_KEY) || '').trim()
    if (existing) return existing
    const next = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 12)}`
    localStorage.setItem(AFFILIATE_VISITOR_KEY, next)
    return next
}

const resolveQueryCode = (route: RouteLocationNormalizedLoaded | RouteLocationNormalized) => {
    const raw = Array.isArray(route.query.aff) ? route.query.aff[0] : route.query.aff
    if (!raw) return ''
    return normalizeAffiliateCode(String(raw))
}

export const getAffiliateCode = () => {
    const attribution = readAttribution()
    return attribution?.code || ''
}

export const getAffiliateVisitorKey = () => {
    if (typeof window === 'undefined') return ''
    const existing = String(localStorage.getItem(AFFILIATE_VISITOR_KEY) || '').trim()
    if (existing) return existing
    return ensureVisitorKey()
}

export const clearAffiliateCode = () => {
    if (typeof window === 'undefined') return
    localStorage.removeItem(AFFILIATE_STORAGE_KEY)
}

export const captureAffiliateFromRoute = async (route: RouteLocationNormalizedLoaded | RouteLocationNormalized) => {
    const code = resolveQueryCode(route)
    if (!code) return

    writeAttribution(code)

    try {
        await affiliateAPI.trackClick({
            affiliate_code: code,
            visitor_key: ensureVisitorKey(),
            landing_path: route.fullPath || route.path || '/',
            referrer: typeof document !== 'undefined' ? document.referrer : '',
        })
    } catch {
    }
}

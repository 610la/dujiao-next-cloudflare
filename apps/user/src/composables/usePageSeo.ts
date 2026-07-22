import { computed, watch } from 'vue'
import { useHead } from '@unhead/vue'
import { useAppStore } from '../stores/app'
import { getImageUrl } from '../utils/image'

export interface PageSeoOptions {
  /** 页面专属标题；若与站点名相同，仅展示站点名 */
  title?: () => string | undefined | null
  /** 页面描述；缺省时回落到站点全局描述 */
  description?: () => string | undefined | null
  /** 分享图：可填绝对 URL、相对路径或上传图 key（自动走 getImageUrl） */
  image?: () => string | undefined | null
  /** 规范化路径（如 /products/foo），缺省时取当前 location.pathname */
  canonicalPath?: () => string | undefined | null
  /** og:type，默认 website */
  type?: () => string | undefined | null
  /** 标识页面不该被索引（私密页/动态查询页） */
  noindex?: () => boolean
}

const trimSlashEnd = (s: string) => s.replace(/\/+$/, '')

const resolveImage = (raw: string, baseUrl: string): string => {
  const trimmed = raw.trim()
  if (!trimmed) return ''
  if (/^https?:\/\//i.test(trimmed)) return trimmed
  // 优先走 getImageUrl 处理 uploads 路径，得到的可能是相对 /uploads/...
  const resolved = getImageUrl(trimmed) || trimmed
  if (/^https?:\/\//i.test(resolved)) return resolved
  if (baseUrl && resolved.startsWith('/')) return baseUrl + resolved
  return resolved
}

export function usePageSeo(options: PageSeoOptions = {}) {
  const appStore = useAppStore()

  const baseUrl = computed(() => {
    const fromConfig = trimSlashEnd(String(appStore.config?.brand?.site_url || '').trim())
    if (fromConfig) return fromConfig
    if (typeof window !== 'undefined') return trimSlashEnd(window.location.origin)
    return ''
  })

  const siteName = computed(() => {
    const lang = appStore.locale
    const seo = appStore.config?.seo
    const localized = seo?.title?.[lang]
    if (localized && String(localized).trim()) return String(localized).trim()
    return String(appStore.config?.brand?.site_name || '').trim()
  })

  const siteDescription = computed(() => {
    const lang = appStore.locale
    const seo = appStore.config?.seo
    const localized = seo?.description?.[lang]
    return localized ? String(localized).trim() : ''
  })

  const defaultImage = computed(() => {
    const seo = appStore.config?.seo as { default_og_image?: string } | undefined
    return seo?.default_og_image ? String(seo.default_og_image).trim() : ''
  })

  const pageTitle = computed(() => {
    const raw = options.title?.()
    return raw ? String(raw).trim() : ''
  })

  const fullTitle = computed(() => {
    if (pageTitle.value && siteName.value && pageTitle.value !== siteName.value) {
      return `${pageTitle.value} - ${siteName.value}`
    }
    return pageTitle.value || siteName.value || undefined
  })

  const fullDescription = computed(() => {
    const pageDesc = options.description?.()
    if (pageDesc && String(pageDesc).trim()) return String(pageDesc).trim()
    return siteDescription.value || undefined
  })

  const fullCanonical = computed(() => {
    const explicit = options.canonicalPath?.()
    let path = explicit && String(explicit).trim() ? String(explicit).trim() : ''
    if (!path && typeof window !== 'undefined') path = window.location.pathname
    if (!path) path = '/'
    if (!path.startsWith('/')) path = '/' + path
    if (!baseUrl.value) return path
    return baseUrl.value + path
  })

  const fullImage = computed(() => {
    const raw = options.image?.()
    if (raw && String(raw).trim()) {
      return resolveImage(String(raw), baseUrl.value) || undefined
    }
    if (defaultImage.value) {
      return resolveImage(defaultImage.value, baseUrl.value) || undefined
    }
    return undefined
  })

  useHead({
    title: () => fullTitle.value,
    link: () => {
      if (!fullCanonical.value) return []
      return [{ key: 'canonical', rel: 'canonical', href: fullCanonical.value }]
    },
    meta: () => {
      const tags: Array<{ name?: string; property?: string; content: string }> = []

      if (options.noindex?.()) {
        tags.push({ name: 'robots', content: 'noindex, nofollow' })
      }

      if (fullDescription.value) {
        tags.push({ name: 'description', content: fullDescription.value })
      }

      const ogType = (options.type?.() && String(options.type()).trim()) || 'website'
      tags.push({ property: 'og:type', content: ogType })
      if (fullTitle.value) tags.push({ property: 'og:title', content: fullTitle.value })
      if (fullDescription.value) tags.push({ property: 'og:description', content: fullDescription.value })
      if (fullCanonical.value) tags.push({ property: 'og:url', content: fullCanonical.value })
      if (fullImage.value) tags.push({ property: 'og:image', content: fullImage.value })
      if (siteName.value) tags.push({ property: 'og:site_name', content: siteName.value })

      tags.push({ name: 'twitter:card', content: 'summary_large_image' })
      if (fullTitle.value) tags.push({ name: 'twitter:title', content: fullTitle.value })
      if (fullDescription.value) tags.push({ name: 'twitter:description', content: fullDescription.value })
      if (fullImage.value) tags.push({ name: 'twitter:image', content: fullImage.value })

      return tags
    },
  })

  if (typeof document !== 'undefined') {
    watch(
      fullTitle,
      (title) => {
        const nextTitle = title ? String(title).trim() : ''
        if (!nextTitle) return
        const apply = () => {
          if (document.title !== nextTitle) document.title = nextTitle
        }
        apply()
        queueMicrotask(apply)
        window.setTimeout(apply, 0)
      },
      { immediate: true, flush: 'post' },
    )
  }
}

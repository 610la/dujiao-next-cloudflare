export type ResellerLocale = 'zh-CN' | 'zh-TW' | 'en-US'
export type LocalizedText = Record<ResellerLocale, string>

export const resellerLocales: ResellerLocale[] = ['zh-CN', 'zh-TW', 'en-US']

export const blankLocalizedText = (): LocalizedText => ({
    'zh-CN': '',
    'zh-TW': '',
    'en-US': '',
})

export const getLocalizedText = (
    value: Partial<LocalizedText> | Record<string, unknown> | undefined | null,
    locale: string,
) => {
    if (!value) return ''
    const candidates = [
        value[locale as keyof typeof value],
        value['zh-CN' as keyof typeof value],
        value['zh-TW' as keyof typeof value],
        value['en-US' as keyof typeof value],
        ...Object.values(value),
    ]
    for (const item of candidates) {
        if (typeof item === 'string' && item.trim()) return item.trim()
    }
    return ''
}

export const hasLocalizedText = (
    value?: Partial<LocalizedText> | Record<string, unknown> | null,
) => {
    if (!value) return false
    return Object.values(value).some((item) => typeof item === 'string' && item.trim() !== '')
}

export const normalizeLocalizedTextForForm = (
    value?: Partial<LocalizedText> | Record<string, unknown> | null,
): LocalizedText => ({
    'zh-CN': String(value?.['zh-CN'] || ''),
    'zh-TW': String(value?.['zh-TW'] || ''),
    'en-US': String(value?.['en-US'] || ''),
})

export const normalizeFooterLinksForForm = (
    links?: Array<{ name?: Partial<LocalizedText> | Record<string, unknown>; url?: string }> | null,
) =>
    Array.isArray(links)
        ? links.map((item) => ({
              name: normalizeLocalizedTextForForm(item.name),
              url: String(item.url || ''),
          }))
        : []

export const canEditResellerSiteConfig = (
    snapshot?: { opened?: boolean; can_edit?: boolean } | null,
) => snapshot?.opened === true && snapshot?.can_edit === true

export const isResellerSiteSeoConfigured = (
    seo?: {
        title?: Partial<LocalizedText> | Record<string, unknown> | null
        keywords?: Partial<LocalizedText> | Record<string, unknown> | null
        description?: Partial<LocalizedText> | Record<string, unknown> | null
        default_og_image?: string | null
    } | null,
) => {
    if (!seo) return false
    return (
        hasLocalizedText(seo.title) ||
        hasLocalizedText(seo.keywords) ||
        hasLocalizedText(seo.description) ||
        String(seo.default_og_image || '').trim() !== ''
    )
}

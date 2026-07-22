import { getImageUrl } from './image'

const SITE_ICON_LINK_ID = 'site-favicon'
const DEFAULT_SITE_ICON = '/dj.svg'

export function resolveSiteIconHref(value: unknown): string {
  const icon = String(value || '').trim()
  return icon ? getImageUrl(icon) : DEFAULT_SITE_ICON
}

export function applySiteIcon(value: unknown) {
  const link = document.getElementById(SITE_ICON_LINK_ID) as HTMLLinkElement | null
  if (link) {
    link.href = resolveSiteIconHref(value)
  }
}

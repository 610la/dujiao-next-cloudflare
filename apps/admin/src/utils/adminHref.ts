declare const __ADMIN_BASE__: string

export const adminHref = (path: string) => {
  const base = typeof document !== 'undefined'
    ? document.querySelector('base')?.getAttribute('href')
    : ''
  const normalizedBase = (base || __ADMIN_BASE__).replace(/\/+$/, '/')
  return `${normalizedBase}${path.replace(/^\/+/, '')}`
}

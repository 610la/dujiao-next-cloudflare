export function getImageUrl(path: string | undefined | null): string {
  if (!path) return ''

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path
  }

  const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || ''
  const normalizedPath = path.startsWith('/') ? path : `/${path}`

  return `${apiBaseUrl}${normalizedPath}`
}

export function getFirstImageUrl(images: any): string {
  if (!images) return ''

  let imageUrl = ''

  if (Array.isArray(images)) {
    imageUrl = images[0] || ''
  } else if (images.images && Array.isArray(images.images)) {
    imageUrl = images.images[0] || ''
  }

  return getImageUrl(imageUrl)
}

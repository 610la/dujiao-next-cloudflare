import { buildSkuDisplayTextFromSnapshot } from './sku'

type ResellerOrderItemLike = {
  sku_snapshot?: unknown
}

export const formatResellerOrderItemSkuText = (
  item: unknown,
  options?: { locale?: string; fallback?: string },
) => {
  const row = item && typeof item === 'object' ? item as ResellerOrderItemLike : null
  return buildSkuDisplayTextFromSnapshot(row?.sku_snapshot, {
    locale: options?.locale,
    fallback: options?.fallback || '',
  })
}

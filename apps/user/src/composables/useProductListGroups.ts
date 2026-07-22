import { computed, type ComputedRef, type Ref } from 'vue'
import { normalizeCategoryParentId, type PublicCategory } from '../utils/category'
import { useLocalized } from './useProduct'
import { useI18n } from 'vue-i18n'

export interface ProductGroup {
  categoryId: number | null
  categoryName: string
  categoryIcon: string | null
  products: any[]
}

export function useProductListGroups(
  products: Ref<any[]>,
  categoryMap: ComputedRef<Map<number, PublicCategory>>,
): ComputedRef<ProductGroup[]> {
  const { getLocalizedText } = useLocalized()
  const { t } = useI18n()

  return computed<ProductGroup[]>(() => {
    if (products.value.length === 0) return []

    const catMap = categoryMap.value
    const groupMap = new Map<number | null, ProductGroup>()
    const orderedKeys: (number | null)[] = []

    for (const product of products.value) {
      const directCatId: number | null = product.category?.id ?? null

      let groupCatId = directCatId
      let groupName = directCatId !== null ? getLocalizedText(product.category?.name) : t('products.allCategories')
      let groupIcon: string | null = product.category?.icon ?? null

      if (directCatId !== null) {
        const catEntry = catMap.get(directCatId)
        if (catEntry) {
          const parentId = normalizeCategoryParentId(catEntry.parent_id)
          if (parentId > 0) {
            const parentEntry = catMap.get(parentId)
            if (parentEntry) {
              groupCatId = parentEntry.id
              groupName = getLocalizedText(parentEntry.name)
              groupIcon = parentEntry.icon ?? null
            }
          }
        }
      }

      if (!groupMap.has(groupCatId)) {
        orderedKeys.push(groupCatId)
        groupMap.set(groupCatId, {
          categoryId: groupCatId,
          categoryName: groupName,
          categoryIcon: groupIcon,
          products: [],
        })
      }
      groupMap.get(groupCatId)!.products.push(product)
    }

    return orderedKeys.map((key) => groupMap.get(key)!)
  })
}

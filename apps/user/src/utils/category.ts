export interface PublicCategory {
  id: number
  slug?: string
  name?: unknown
  icon?: string | null
  parent_id?: number | null
}

export interface CategoryGroup extends PublicCategory {
  children: PublicCategory[]
}

const normalizeCategoryId = (value: unknown) => {
  const numberValue = Number(value)
  if (!Number.isFinite(numberValue) || numberValue <= 0) return 0
  return Math.floor(numberValue)
}

export const normalizeCategoryParentId = (value: unknown) => {
  return normalizeCategoryId(value)
}

export const createCategoryMap = (categories: PublicCategory[]) => {
  const categoryMap = new Map<number, PublicCategory>()

  categories.forEach((category) => {
    const categoryId = normalizeCategoryId(category.id)
    if (categoryId > 0) {
      categoryMap.set(categoryId, {
        ...category,
        id: categoryId,
        parent_id: normalizeCategoryParentId(category.parent_id),
      })
    }
  })

  return categoryMap
}

export const buildCategoryGroups = (categories: PublicCategory[]) => {
  const categoryMap = createCategoryMap(categories)
  const childrenByParent = new Map<number, PublicCategory[]>()
  const rootCategories: PublicCategory[] = []

  categories.forEach((rawCategory) => {
    const category = categoryMap.get(normalizeCategoryId(rawCategory.id))
    if (!category) return

    const parentId = normalizeCategoryParentId(category.parent_id)
    const parent = parentId > 0 ? categoryMap.get(parentId) : undefined

    if (parentId <= 0 || !parent || parent.id === category.id) {
      rootCategories.push(category)
      return
    }

    const siblings = childrenByParent.get(parent.id) || []
    siblings.push(category)
    childrenByParent.set(parent.id, siblings)
  })

  return rootCategories.map((category) => ({
    ...category,
    children: childrenByParent.get(category.id) || [],
  }))
}

export const buildCategoryPath = (
  category: PublicCategory | undefined,
  categoryMap: Map<number, PublicCategory>,
  getLabel: (value: unknown) => string,
) => {
  if (!category) return ''

  const selfLabel = getLabel(category.name)
  const parentId = normalizeCategoryParentId(category.parent_id)
  if (parentId <= 0) return selfLabel

  const parent = categoryMap.get(parentId)
  if (!parent || parent.id === category.id) return selfLabel

  const parentLabel = getLabel(parent.name)
  if (!parentLabel) return selfLabel
  if (!selfLabel) return parentLabel

  return `${parentLabel} / ${selfLabel}`
}

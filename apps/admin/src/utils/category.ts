import type { AdminCategory } from '@/api/types'

export interface AdminCategoryHierarchyItem {
  category: AdminCategory
  depth: number
  parent: AdminCategory | null
}

export const createAdminCategoryMap = (categories: AdminCategory[]) => {
  return new Map(categories.map((category) => [category.id, category]))
}

export const createAdminCategoryChildCountMap = (categories: AdminCategory[]) => {
  const childCountMap = new Map<number, number>()

  categories.forEach((category) => {
    if (category.parent_id > 0) {
      childCountMap.set(category.parent_id, (childCountMap.get(category.parent_id) || 0) + 1)
    }
  })

  return childCountMap
}

export const flattenAdminCategories = (categories: AdminCategory[]): AdminCategoryHierarchyItem[] => {
  const categoryMap = createAdminCategoryMap(categories)
  const orderMap = new Map(categories.map((category, index) => [category.id, index]))
  const childrenMap = new Map<number, AdminCategory[]>()

  for (const category of categories) {
    const parentID = category.parent_id > 0 && categoryMap.has(category.parent_id) ? category.parent_id : 0
    const list = childrenMap.get(parentID) || []
    list.push(category)
    childrenMap.set(parentID, list)
  }

  for (const list of childrenMap.values()) {
    list.sort((left, right) => (orderMap.get(left.id) || 0) - (orderMap.get(right.id) || 0))
  }

  const result: AdminCategoryHierarchyItem[] = []
  const visited = new Set<number>()

  const walk = (category: AdminCategory, depth: number, parent: AdminCategory | null) => {
    if (visited.has(category.id)) return
    visited.add(category.id)
    result.push({
      category,
      depth: Math.min(depth, 1),
      parent,
    })

    const children = childrenMap.get(category.id) || []
    for (const child of children) {
      walk(child, depth + 1, category)
    }
  }

  const roots = categories.filter((category) => category.parent_id === 0 || !categoryMap.has(category.parent_id))
  roots.sort((left, right) => (orderMap.get(left.id) || 0) - (orderMap.get(right.id) || 0))

  for (const root of roots) {
    walk(root, 0, null)
  }

  for (const category of categories) {
    if (!visited.has(category.id)) {
      walk(category, category.parent_id > 0 ? 1 : 0, categoryMap.get(category.parent_id) || null)
    }
  }

  return result
}

export const buildAdminCategoryPath = (
  category: AdminCategory | null | undefined,
  categoryMap: Map<number, AdminCategory>,
  getLabel: (category: AdminCategory) => string
) => {
  if (!category) return ''
  const current = getLabel(category)
  if (!category.parent_id) return current

  const parent = categoryMap.get(category.parent_id)
  if (!parent) return current

  return `${getLabel(parent)} / ${current}`
}

export const isAdminProductCategorySelectable = (
  category: AdminCategory,
  childCountMap: Map<number, number>
) => {
  return (childCountMap.get(category.id) || 0) === 0
}

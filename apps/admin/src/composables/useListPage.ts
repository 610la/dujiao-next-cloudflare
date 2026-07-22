import { ref, type Ref } from 'vue'
import { useDebounceFn } from '@vueuse/core'

export interface Pagination {
  page: number
  page_size: number
  total: number
  total_page: number
}

export interface UseListPageOptions<T> {
  /** API 请求函数，接收 page 参数，返回 { items, pagination } */
  fetchFn: (page: number) => Promise<{ items: T[]; pagination?: Pagination }>
  /** 每页条数，默认 20 */
  pageSize?: number
  /** 搜索防抖延迟(ms)，默认 300 */
  debounceMs?: number
}

export function useListPage<T = any>(options: UseListPageOptions<T>) {
  const { fetchFn, pageSize = 20, debounceMs = 300 } = options

  const loading = ref(false)
  const items = ref<T[]>([]) as Ref<T[]>
  const pagination = ref<Pagination>({
    page: 1,
    page_size: pageSize,
    total: 0,
    total_page: 1,
  })
  const jumpPage = ref('')

  const fetchData = async (page = 1) => {
    loading.value = true
    try {
      const result = await fetchFn(page)
      items.value = result.items
      if (result.pagination) {
        pagination.value = result.pagination
      }
    } catch {
      items.value = []
    } finally {
      loading.value = false
    }
  }

  const handleSearch = () => {
    fetchData(1)
  }

  const debouncedSearch = useDebounceFn(handleSearch, debounceMs)

  const refresh = () => {
    fetchData(pagination.value.page)
  }

  const changePage = (page: number) => {
    if (page < 1 || page > pagination.value.total_page) return
    fetchData(page)
  }

  const jumpToPage = () => {
    if (!jumpPage.value) return
    const raw = Number(jumpPage.value)
    if (Number.isNaN(raw)) return
    const target = Math.min(Math.max(Math.floor(raw), 1), pagination.value.total_page)
    if (target === pagination.value.page) return
    changePage(target)
  }

  return {
    loading,
    items,
    pagination,
    jumpPage,
    fetchData,
    handleSearch,
    debouncedSearch,
    refresh,
    changePage,
    jumpToPage,
  }
}

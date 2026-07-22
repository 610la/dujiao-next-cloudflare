import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '../stores/app'
import { postAPI } from '../api'
import { debounceAsync } from '../utils/debounce'
import { usePageSeo } from './usePageSeo'
import { formatSiteDate } from '../utils/time'

/**
 * 文章/公告列表共享逻辑（Blog/Notice，classic + vault 双模板共用）。
 * 完整保留原 views/Blog.vue 与 Notice.vue 的行为，仅抽离为 composable。
 * Blog 启用搜索；Notice 无搜索框（searchKeyword 恒为空，watch 永不触发，行为一致）。
 */
export function usePostList(
  type: 'blog' | 'notice',
  seo: { title: () => string; canonicalPath: string },
) {
  const router = useRouter()
  const appStore = useAppStore()

  usePageSeo({
    title: seo.title,
    canonicalPath: () => seo.canonicalPath,
  })

  const loading = ref(true)
  const posts = ref<any[]>([])
  const currentPage = ref(1)
  const pageSize = ref(12)
  const total = ref(0)
  const totalPages = ref(0)
  const searchKeyword = ref('')

  const getLocalizedText = (jsonData: any) => {
    if (!jsonData) return ''
    const locale = appStore.locale
    return jsonData[locale] || jsonData['zh-CN'] || jsonData['en-US'] || ''
  }

  const formatDate = (dateString: string) => {
    return formatSiteDate(dateString, appStore.locale, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })
  }

  const loadPosts = async () => {
    loading.value = true
    try {
      const params: Record<string, any> = {
        type,
        page: currentPage.value,
        page_size: pageSize.value,
      }
      const keyword = searchKeyword.value.trim()
      if (keyword) {
        params.search = keyword
      }
      const response = await postAPI.list(params)
      posts.value = response.data.data || []
      if (response.data.pagination) {
        total.value = response.data.pagination.total || 0
        totalPages.value = response.data.pagination.total_page || 0
      }
    } catch (error) {
      console.error('Failed to load posts:', error)
    } finally {
      loading.value = false
    }
  }

  const debouncedLoadPosts = debounceAsync(loadPosts, 300)

  const goToPost = (slug: string) => {
    router.push(`/blog/${slug}`)
  }

  const changePage = (page: number) => {
    if (page < 1 || page > totalPages.value) return
    currentPage.value = page
    debouncedLoadPosts()
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  watch(searchKeyword, () => {
    currentPage.value = 1
    debouncedLoadPosts()
  })

  onMounted(() => {
    loadPosts()
  })

  onUnmounted(() => {
    debouncedLoadPosts.cancel()
  })

  return {
    loading,
    posts,
    currentPage,
    totalPages,
    total,
    searchKeyword,
    getLocalizedText,
    formatDate,
    goToPost,
    changePage,
  }
}

<template>
  <div class="mx-auto w-full max-w-[1180px] px-6 pb-6">
    <nav class="flex items-center gap-1.5 py-5 pb-1 text-[13.5px] font-semibold text-muted-foreground">
      <RouterLink to="/" class="flex-none hover:text-primary">{{ t('nav.home') }}</RouterLink>
      <ChevronRight class="h-4 w-4 flex-none" />
      <span class="min-w-0 truncate text-foreground">{{ pageTitle }}</span>
    </nav>
    <h1 class="mb-3.5 break-words text-3xl font-extrabold">{{ pageTitle }}</h1>

    <div class="grid items-start gap-7 py-1.5 pb-9 lg:grid-cols-[248px_1fr]">
      <!-- 筛选侧栏：桌面竖排 + 移动端横向 chips -->
      <div class="grid min-w-0 gap-3 lg:sticky lg:top-[88px] lg:gap-5">
        <!-- 搜索框 -->
        <div class="relative">
          <Search class="pointer-events-none absolute left-3.5 top-1/2 h-[18px] w-[18px] -translate-y-1/2 text-muted-foreground" />
          <input
            v-model="searchQuery"
            class="h-11 w-full rounded-xl border border-border bg-card pl-10 pr-10 text-[15px] text-foreground transition-colors placeholder:text-muted-foreground hover:border-hairline-strong"
            :placeholder="t('products.searchBoxPlaceholder')"
            :aria-label="t('products.searchLabel')"
          />
          <button v-if="searchQuery" type="button" class="absolute right-2.5 top-1/2 grid h-6 w-6 -translate-y-1/2 place-items-center rounded-full text-muted-foreground transition-colors hover:bg-secondary hover:text-foreground" :aria-label="t('blog.searchClear')" @click="clearSearch"><X class="h-3.5 w-3.5" /></button>
        </div>

        <!-- 分类：使用 VaultCategorySidebar，移动端自动变横向 chips -->
        <VaultCategorySidebar
          :category-groups="categoryGroups"
          :selected-category="selectedCategory"
          :expanded-parent-ids="expandedParentIds"
          @select="selectCategory"
          @toggle="toggleParentCategory"
        />
      </div>

      <!-- 商品区 -->
      <section>
        <div v-if="loading" class="grid gap-4 grid-cols-[repeat(auto-fill,minmax(228px,1fr))]">
          <div v-for="i in 9" :key="i" class="h-[280px] rounded-lg border bg-card"></div>
        </div>

        <template v-else-if="products.length">
          <div class="grid gap-4 grid-cols-[repeat(auto-fill,minmax(228px,1fr))]">
            <VaultProductCard
              v-for="(product, idx) in products"
              :key="product.id"
              :product="product"
              :index="idx"
              @quick-buy="openQuickBuy"
            />
          </div>

          <nav v-if="totalPages > 1" class="mt-[30px] flex justify-center gap-2">
            <button class="grid h-[42px] min-w-[42px] place-items-center rounded-full border bg-card px-3 font-bold text-muted-foreground hover:border-primary hover:text-primary disabled:cursor-not-allowed disabled:opacity-40" :disabled="currentPage <= 1" @click="changePage(currentPage - 1)"><ChevronLeft class="h-[17px] w-[17px]" /></button>
            <button
              v-for="p in pageWindow"
              :key="p"
              class="grid h-[42px] min-w-[42px] place-items-center rounded-full border px-3 text-sm font-bold"
              :class="p === currentPage ? 'border-primary bg-primary text-white' : 'border-border bg-card text-muted-foreground hover:border-primary hover:text-primary'"
              @click="changePage(p)"
            >{{ p }}</button>
            <button class="grid h-[42px] min-w-[42px] place-items-center rounded-full border bg-card px-3 font-bold text-muted-foreground hover:border-primary hover:text-primary disabled:cursor-not-allowed disabled:opacity-40" :disabled="currentPage >= totalPages" @click="changePage(currentPage + 1)"><ChevronRight class="h-[17px] w-[17px]" /></button>
          </nav>
        </template>

        <div v-else class="flex flex-col items-center gap-3 rounded-lg border border-dashed py-14 text-center text-muted-foreground">
          <component :is="searchQuery || selectedCategory ? SearchX : PackageOpen" class="h-12 w-12 opacity-60" />
          <p>{{ (searchQuery || selectedCategory) ? t('products.emptyFiltered') : t('products.empty') }}</p>
          <Button v-if="searchQuery || selectedCategory" variant="outline" size="sm" class="mt-2 rounded-full" @click="resetFilters">{{ t('products.clearFilters') }}</Button>
        </div>
      </section>
    </div>

    <ProductQuickBuy
      v-if="quickBuyProduct"
      :product="quickBuyProduct"
      :visible="quickBuyVisible"
      @update:visible="quickBuyVisible = $event"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { ChevronLeft, ChevronRight, PackageOpen, Search, SearchX, X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useProductList } from '../../composables/useProductList'
import { usePageSeo } from '../../composables/usePageSeo'
import { useLocalized } from '../../composables/useProduct'
import type { PublicCategory } from '../../utils/category'
import VaultProductCard from './components/VaultProductCard.vue'
import VaultCategorySidebar from './components/VaultCategorySidebar.vue'
import ProductQuickBuy from '../../components/ProductQuickBuy.vue'

const { t } = useI18n()
const route = useRoute()
const { getLocalizedText } = useLocalized()

const quickBuyProduct = ref<any>(null)
const quickBuyVisible = ref(false)
const openQuickBuy = (product: any) => {
  quickBuyProduct.value = product
  quickBuyVisible.value = true
}

const {
  loading,
  products,
  selectedCategory,
  searchQuery,
  currentPage,
  totalPages,
  expandedParentIds,
  categoryGroups,
  categoryMap,
  selectCategory,
  toggleParentCategory,
  changePage,
  clearSearch,
  initialize,
  cleanup,
} = useProductList({ pageSize: 12, homeRouteName: 'products' })

const catName = (cat: PublicCategory) => getLocalizedText(cat.name) || cat.slug || ''

const selectedCategoryName = computed(() => {
  if (!selectedCategory.value) return ''
  const cat = categoryMap.value.get(selectedCategory.value)
  return cat ? catName(cat) : ''
})

const pageTitle = computed(() => {
  if (route.name === 'category-products') return selectedCategoryName.value || t('nav.products')
  return t('nav.products')
})

// 分页窗口：当前页前后各 2 页
const pageWindow = computed(() => {
  const total = totalPages.value
  const cur = currentPage.value
  const start = Math.max(1, cur - 2)
  const end = Math.min(total, start + 4)
  const realStart = Math.max(1, end - 4)
  const pages: number[] = []
  for (let p = realStart; p <= end; p++) pages.push(p)
  return pages
})

const resetFilters = () => {
  clearSearch()
  selectCategory(null)
}

usePageSeo({
  canonicalPath: () => route.path,
  title: () => pageTitle.value,
})

onMounted(() => { void initialize() })
onUnmounted(() => cleanup())
</script>

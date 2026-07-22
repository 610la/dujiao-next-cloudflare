<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdRenderResponse, AdRenderItemDTO } from '@/api/types'

const { t } = useI18n()

const props = defineProps<{
  slotCode: string
  layout: 'banner' | 'card' | 'notice' | 'compact'
}>()

const adData = ref<AdRenderResponse | null>(null)
const dismissed = ref<Set<number>>(new Set())
const loaded = ref(false)
const visible = ref(false)

// Carousel state (banner layout)
const currentPage = ref(0)
let carouselTimer: ReturnType<typeof setInterval> | null = null

// Compact layout expand state
const compactExpanded = ref(false)

const visibleItems = computed(() => adData.value?.items.filter(isVisible) ?? [])

// Banner carousel: 2 items per page on md+, 1 on mobile
const bannerNeedCarousel = computed(() => props.layout === 'banner' && visibleItems.value.length > 2)
const itemsPerPage = 2 // md+ shows 2, mobile shows 1 but we paginate by 2
const totalPages = computed(() => Math.ceil(visibleItems.value.length / itemsPerPage))
const currentPageItems = computed(() => {
  if (!bannerNeedCarousel.value) return visibleItems.value
  const start = currentPage.value * itemsPerPage
  return visibleItems.value.slice(start, start + itemsPerPage)
})

// Compact layout: show 6 by default
const compactVisibleItems = computed(() => {
  if (compactExpanded.value) return visibleItems.value
  return visibleItems.value.slice(0, 6)
})
const compactHasMore = computed(() => visibleItems.value.length > 6)

const startCarousel = () => {
  stopCarousel()
  if (bannerNeedCarousel.value) {
    carouselTimer = setInterval(() => {
      currentPage.value = (currentPage.value + 1) % totalPages.value
    }, 5000)
  }
}

const stopCarousel = () => {
  if (carouselTimer) {
    clearInterval(carouselTimer)
    carouselTimer = null
  }
}

const goToPage = (page: number) => {
  currentPage.value = page
  startCarousel()
}

const prevPage = () => {
  currentPage.value = (currentPage.value - 1 + totalPages.value) % totalPages.value
  startCarousel()
}

const nextPage = () => {
  currentPage.value = (currentPage.value + 1) % totalPages.value
  startCarousel()
}

const loadAd = async () => {
  try {
    const response = await adminAPI.renderAdSlot(props.slotCode, {
      tenant: 'admin',
      client: 'dashboard',
    })
    const data = response.data.data
    if (data && data.items && data.items.length > 0) {
      adData.value = data
      visible.value = true
      reportImpression(data)
    }
  } catch {
    // 静默失败，不影响主业务
  } finally {
    loaded.value = true
  }
}

const reportImpression = async (data: AdRenderResponse) => {
  try {
    await adminAPI.reportAdImpression({
      tenant: 'admin',
      client: 'dashboard',
      slot_code: props.slotCode,
      items: data.items.map((item) => ({
        ad_id: item.id,
        impression_token: item.impression_token,
      })),
    })
  } catch {
    // 静默
  }
}

const handleClick = (item: AdRenderItemDTO) => {
  if (!item.click_url || item.link_type === 'none') return
  window.open(item.click_url, item.open_in_new_tab ? '_blank' : '_self')
}

const handleDismiss = (item: AdRenderItemDTO) => {
  dismissed.value = new Set([...dismissed.value, item.id])
}

const isVisible = (item: AdRenderItemDTO) => {
  return !dismissed.value.has(item.id)
}

onMounted(() => {
  loadAd()
})

// Watch for carousel start after data loads
const tryStartCarousel = () => {
  if (bannerNeedCarousel.value) startCarousel()
}

// Use a watcher-like approach via computed side effect
onMounted(() => {
  const check = setInterval(() => {
    if (loaded.value) {
      tryStartCarousel()
      clearInterval(check)
    }
  }, 100)
})

onBeforeUnmount(() => {
  stopCarousel()
})
</script>

<template>
  <template v-if="visible && adData">
    <!-- Banner 布局 -->
    <template v-if="layout === 'banner'">
      <!-- 条数 ≤ 2：直接展示 -->
      <div
        v-if="!bannerNeedCarousel"
        :class="[
          'grid gap-3',
          visibleItems.length === 1 ? 'grid-cols-1' : 'grid-cols-1 md:grid-cols-2',
        ]"
      >
        <div
          v-for="item in visibleItems"
          :key="item.id"
          class="group relative cursor-pointer overflow-hidden rounded-xl border border-border bg-gradient-to-r from-primary/5 to-primary/10 transition-all hover:shadow-md"
          @click="handleClick(item)"
        >
          <div class="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:gap-4 sm:px-5">
            <img v-if="item.image" :src="item.image" :alt="item.title" class="h-12 w-12 shrink-0 rounded-lg object-cover" />
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <span class="line-clamp-1 text-sm font-semibold text-foreground">{{ item.title }}</span>
                <span v-if="item.badge" class="shrink-0 rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-medium text-primary">{{ item.badge }}</span>
              </div>
              <p v-if="item.subtitle" class="mt-0.5 line-clamp-1 text-xs text-muted-foreground">{{ item.subtitle }}</p>
            </div>
            <button
              v-if="item.cta_label && item.link_type !== 'none'"
              class="w-full shrink-0 rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground transition-colors hover:bg-primary/90 sm:w-auto"
              @click.stop="handleClick(item)"
            >
              {{ item.cta_label }}
            </button>
          </div>
          <button
            v-if="item.dismissible"
            class="absolute right-7 top-1.5 shrink-0 rounded p-0.5 text-muted-foreground/60 transition-colors hover:text-foreground"
            @click.stop="handleDismiss(item)"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
          <div class="absolute right-1.5 top-1.5 text-xs text-muted-foreground/40">{{ t('admin.dashboard.ad.label') }}</div>
        </div>
      </div>

      <!-- 条数 > 2：轮播模式 -->
      <div
        v-else
        class="relative"
        @mouseenter="stopCarousel"
        @mouseleave="startCarousel"
      >
        <div class="overflow-hidden">
          <div class="grid gap-3 grid-cols-1 md:grid-cols-2 transition-opacity duration-300">
            <div
              v-for="item in currentPageItems"
              :key="item.id"
              class="group relative cursor-pointer overflow-hidden rounded-xl border border-border bg-gradient-to-r from-primary/5 to-primary/10 transition-all hover:shadow-md"
              @click="handleClick(item)"
            >
              <div class="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:gap-4 sm:px-5">
                <img v-if="item.image" :src="item.image" :alt="item.title" class="h-12 w-12 shrink-0 rounded-lg object-cover" />
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="line-clamp-1 text-sm font-semibold text-foreground">{{ item.title }}</span>
                    <span v-if="item.badge" class="shrink-0 rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-medium text-primary">{{ item.badge }}</span>
                  </div>
                  <p v-if="item.subtitle" class="mt-0.5 line-clamp-1 text-xs text-muted-foreground">{{ item.subtitle }}</p>
                </div>
                <button
                  v-if="item.cta_label && item.link_type !== 'none'"
                  class="w-full shrink-0 rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground transition-colors hover:bg-primary/90 sm:w-auto"
                  @click.stop="handleClick(item)"
                >
                  {{ item.cta_label }}
                </button>
              </div>
              <button
                v-if="item.dismissible"
                class="absolute right-7 top-1.5 shrink-0 rounded p-0.5 text-muted-foreground/60 transition-colors hover:text-foreground"
                @click.stop="handleDismiss(item)"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
              <div class="absolute right-1.5 top-1.5 text-xs text-muted-foreground/40">{{ t('admin.dashboard.ad.label') }}</div>
            </div>
          </div>
        </div>

        <!-- 左右箭头 -->
        <button
          class="absolute left-2 top-1/2 z-10 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-full border border-border bg-background shadow-sm transition-colors hover:bg-muted sm:left-0 sm:-translate-x-1/2"
          @click="prevPage"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <button
          class="absolute right-2 top-1/2 z-10 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-full border border-border bg-background shadow-sm transition-colors hover:bg-muted sm:right-0 sm:translate-x-1/2"
          @click="nextPage"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
        </button>

        <!-- 圆点指示器 -->
        <div class="mt-2 flex items-center justify-center gap-1.5">
          <button
            v-for="page in totalPages"
            :key="page"
            class="h-1.5 rounded-full transition-all"
            :class="currentPage === page - 1 ? 'w-4 bg-primary' : 'w-1.5 bg-muted-foreground/30 hover:bg-muted-foreground/50'"
            @click="goToPage(page - 1)"
          />
        </div>
      </div>
    </template>

    <!-- Card 布局：直接输出多个卡片，融入父级 grid -->
    <template v-else-if="layout === 'card'">
      <div
        v-for="item in visibleItems"
        :key="item.id"
        class="group cursor-pointer rounded-xl border border-border bg-card p-4 shadow-sm transition-all hover:shadow-md"
        @click="handleClick(item)"
      >
        <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <img v-if="item.icon" :src="item.icon" :alt="item.title" class="h-5 w-5 shrink-0 rounded" />
              <span v-if="item.badge" class="rounded-full bg-primary/10 px-1.5 py-0.5 text-[10px] font-medium text-primary">{{ item.badge }}</span>
            </div>
            <div class="mt-2 line-clamp-1 text-sm font-semibold text-foreground">{{ item.title }}</div>
            <p v-if="item.subtitle" class="mt-1 line-clamp-2 text-xs text-muted-foreground">{{ item.subtitle }}</p>
          </div>
          <img v-if="item.image" :src="item.image" :alt="item.title" class="h-14 w-14 shrink-0 rounded-lg object-cover" />
        </div>
        <button
          v-if="item.cta_label && item.link_type !== 'none'"
          class="mt-3 w-full rounded-md bg-primary/10 px-3 py-1.5 text-xs font-medium text-primary transition-colors hover:bg-primary/20"
          @click.stop="handleClick(item)"
        >
          {{ item.cta_label }}
        </button>
        <div class="mt-1 text-right text-[10px] text-muted-foreground/40">{{ t('admin.dashboard.ad.label') }}</div>
      </div>
    </template>

    <!-- Notice 布局：堆叠通知条 -->
    <template v-else-if="layout === 'notice'">
      <div
        v-for="item in visibleItems"
        :key="item.id"
        class="relative flex flex-col items-start gap-3 rounded-lg border border-border bg-muted/30 px-4 py-3 sm:flex-row sm:items-center"
        :class="item.theme === 'highlight' ? 'border-primary/20 bg-primary/5' : ''"
      >
        <img v-if="item.icon" :src="item.icon" :alt="item.title" class="h-5 w-5 shrink-0 rounded" />
        <div class="min-w-0 flex-1">
          <span class="text-sm text-foreground">{{ item.title }}</span>
          <span v-if="item.subtitle" class="ml-2 text-xs text-muted-foreground">{{ item.subtitle }}</span>
        </div>
        <button
          v-if="item.cta_label && item.link_type !== 'none'"
          class="text-xs font-medium text-primary hover:underline sm:shrink-0"
          @click="handleClick(item)"
        >
          {{ item.cta_label }}
        </button>
        <button
          v-if="item.dismissible"
          class="shrink-0 rounded p-0.5 text-muted-foreground/60 transition-colors hover:text-foreground"
          @click="handleDismiss(item)"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
        <span class="text-[10px] text-muted-foreground/40">{{ t('admin.dashboard.ad.label') }}</span>
      </div>
    </template>

    <!-- Compact 布局：紧凑文字链网格 -->
    <template v-else-if="layout === 'compact'">
      <div class="rounded-xl border border-border bg-card">
        <div class="flex items-center justify-between px-4 py-2.5 border-b border-border">
          <span class="text-xs font-medium text-muted-foreground">{{ t('admin.dashboard.ad.sponsored') }}</span>
          <span class="text-[10px] text-muted-foreground/40">{{ t('admin.dashboard.ad.label') }}</span>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-x-4 gap-y-1 px-4 py-2.5">
          <div
            v-for="item in compactVisibleItems"
            :key="item.id"
            class="flex min-w-0 flex-wrap items-center gap-1.5 py-1"
          >
            <span class="truncate text-sm text-foreground">{{ item.title }}</span>
            <span v-if="item.badge" class="shrink-0 rounded-full bg-primary/10 px-1.5 py-0.5 text-[10px] font-medium text-primary">{{ item.badge }}</span>
            <span class="text-muted-foreground/30">·</span>
            <button
              v-if="item.cta_label && item.link_type !== 'none'"
              class="shrink-0 text-xs font-medium text-primary hover:underline"
              @click="handleClick(item)"
            >
              {{ item.cta_label }}
            </button>
          </div>
        </div>
        <div v-if="compactHasMore" class="border-t border-border px-4 py-2">
          <button
            class="text-xs font-medium text-primary hover:underline"
            @click="compactExpanded = !compactExpanded"
          >
            {{ compactExpanded ? t('admin.dashboard.ad.showLess') : t('admin.dashboard.ad.showAll', { count: visibleItems.length }) }}
          </button>
        </div>
      </div>
    </template>
  </template>
</template>

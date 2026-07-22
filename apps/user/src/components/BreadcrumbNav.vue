<template>
  <nav
    class="text-sm text-muted-foreground font-medium"
    :aria-label="t('breadcrumb.label')"
  >
    <!-- Desktop: full breadcrumb trail -->
    <ol class="hidden md:flex items-center space-x-2 flex-wrap">
      <li v-for="(item, idx) in items" :key="idx" class="flex items-center space-x-2">
        <router-link
          v-if="item.to && idx < items.length - 1"
          :to="item.to"
          class="text-muted-foreground transition-colors hover:text-foreground"
        >{{ item.label }}</router-link>
        <span
          v-else
          class="text-foreground truncate max-w-[240px]"
          :aria-current="idx === items.length - 1 ? 'page' : undefined"
        >{{ item.label }}</span>
        <span v-if="idx < items.length - 1" aria-hidden="true" class="text-muted-foreground/60">/</span>
      </li>
    </ol>

    <!-- Mobile: compact back-style -->
    <div class="md:hidden flex items-center gap-2">
      <button
        v-if="parent"
        type="button"
        class="inline-flex items-center gap-1.5 text-muted-foreground transition-colors hover:text-foreground active:opacity-70"
        :aria-label="t('breadcrumb.back', { name: parent.label })"
        @click="handleBack"
      >
        <ChevronLeft class="w-4 h-4 shrink-0" :stroke-width="2" aria-hidden="true" />
        <span class="truncate max-w-[40vw]">{{ parent.label }}</span>
      </button>
      <span v-if="parent && current" aria-hidden="true" class="text-muted-foreground/60">/</span>
      <span
        v-if="current"
        class="text-foreground truncate flex-1"
        aria-current="page"
      >{{ current.label }}</span>
    </div>
  </nav>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter, type RouteLocationRaw } from 'vue-router'
import { ChevronLeft } from 'lucide-vue-next'

interface BreadcrumbItem {
  label: string
  to?: RouteLocationRaw
}

const props = defineProps<{
  items: BreadcrumbItem[]
}>()

const { t } = useI18n()
const router = useRouter()

const parent = computed<BreadcrumbItem | null>(() =>
  props.items.length >= 2 ? props.items[props.items.length - 2] ?? null : null,
)

const current = computed<BreadcrumbItem | null>(() =>
  props.items.length > 0 ? props.items[props.items.length - 1] ?? null : null,
)

const handleBack = () => {
  if (parent.value?.to) {
    router.push(parent.value.to)
  } else {
    router.back()
  }
}
</script>

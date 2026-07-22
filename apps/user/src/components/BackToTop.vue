<template>
  <Transition
    enter-active-class="transition duration-300 ease-out"
    enter-from-class="opacity-0 scale-90"
    enter-to-class="opacity-100 scale-100"
    leave-active-class="transition duration-200 ease-in"
    leave-from-class="opacity-100 scale-100"
    leave-to-class="opacity-0 scale-90"
  >
    <Button
      v-if="visible"
      variant="secondary"
      size="icon"
      @click="scrollToTop"
      class="back-to-top fixed right-4 md:right-6 z-30 lg:z-40 h-11 w-11 rounded-full border shadow-lg transition-all hover:shadow-xl hover:-translate-y-0.5 [&_svg]:size-5"
      :aria-label="t('common.backToTop')"
    >
      <ChevronUp />
    </Button>
  </Transition>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronUp } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

const { t } = useI18n()
const visible = ref(false)

const onScroll = () => {
  visible.value = window.scrollY > 400
}

const scrollToTop = () => {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

onMounted(() => window.addEventListener('scroll', onScroll, { passive: true }))
onUnmounted(() => window.removeEventListener('scroll', onScroll))
</script>

<style scoped>
/* Mobile: sit above bottom nav (h-14 = 3.5rem) + safe area, with breathing room */
.back-to-top {
  bottom: calc(3.5rem + env(safe-area-inset-bottom, 0px) + 1rem);
}
@media (min-width: 1024px) {
  .back-to-top {
    bottom: 1.5rem;
  }
}
</style>

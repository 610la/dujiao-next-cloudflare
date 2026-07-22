<script setup lang="ts">
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { ShieldCheck } from 'lucide-vue-next'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { useComplianceStore } from '@/stores/compliance'
import { formatDate, formatDateOnly } from '@/utils/format'

const { t } = useI18n()
const compliance = useComplianceStore()
const open = ref(false)

const dateOnly = computed(() => {
  if (!compliance.acknowledgedAt) return ''
  return formatDateOnly(compliance.acknowledgedAt)
})

const fullDatetime = computed(() => {
  if (!compliance.acknowledgedAt) return '-'
  return formatDate(compliance.acknowledgedAt)
})

const tooltip = computed(() =>
  t('compliance.badge.by', {
    username: compliance.acknowledgedByUsername || '-',
    date: dateOnly.value,
  }),
)

const metadataText = computed(() =>
  t('compliance.review.metadata', {
    username: compliance.acknowledgedByUsername || '-',
    datetime: fullDatetime.value,
  }),
)

const sections = [
  { titleKey: 'compliance.dialog.section1Title', bodyKey: 'compliance.dialog.section1Body' },
  { titleKey: 'compliance.dialog.section2Title', bodyKey: 'compliance.dialog.section2Body' },
  { titleKey: 'compliance.dialog.section3Title', bodyKey: 'compliance.dialog.section3Body' },
  { titleKey: 'compliance.dialog.section4Title', bodyKey: 'compliance.dialog.section4Body' },
]

const ACKED_TEXT = '我已阅读并理解上述合规声明提醒，知悉相关法律风险，并确认自行承担部署、运营和收费行为产生的法律责任'
</script>

<template>
  <button
    v-if="compliance.acknowledged"
    type="button"
    :title="tooltip"
    class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-medium select-none cursor-pointer hover:bg-emerald-100 hover:border-emerald-300 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-400 focus-visible:ring-offset-1"
    @click="open = true"
  >
    <ShieldCheck class="w-3.5 h-3.5" />
    <span>{{ t('compliance.badge.acked') }}</span>
  </button>

  <Dialog v-model:open="open">
    <DialogContent class="w-[min(92vw,960px)] sm:max-w-none max-h-[90vh] overflow-y-auto">
      <DialogHeader>
        <DialogTitle class="flex items-center gap-2 text-base font-semibold">
          <ShieldCheck class="h-5 w-5 text-emerald-600 shrink-0" />
          {{ t('compliance.review.title') }}
        </DialogTitle>
        <DialogDescription class="text-sm text-muted-foreground">
          {{ metadataText }}
        </DialogDescription>
      </DialogHeader>

      <!-- Declaration body -->
      <div class="max-h-96 overflow-y-auto rounded-md border bg-muted/30 p-5 space-y-4 text-sm">
        <div v-for="section in sections" :key="section.titleKey">
          <p class="font-semibold text-foreground mb-1">{{ t(section.titleKey) }}</p>
          <p class="text-muted-foreground leading-relaxed">{{ t(section.bodyKey) }}</p>
        </div>
      </div>

      <!-- Acknowledged commitment text -->
      <div class="space-y-2">
        <p class="text-sm font-medium text-foreground">{{ t('compliance.review.ackedTextLabel') }}</p>
        <div class="rounded-md border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm leading-relaxed text-emerald-900">
          {{ ACKED_TEXT }}
        </div>
      </div>

      <DialogFooter>
        <Button variant="outline" @click="open = false">
          {{ t('compliance.review.close') }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>

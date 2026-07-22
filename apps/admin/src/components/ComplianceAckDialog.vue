<script setup lang="ts">
import { ref, watch, nextTick, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { ShieldCheck } from 'lucide-vue-next'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { useComplianceStore } from '@/stores/compliance'
import { notifyError, notifySuccess } from '@/utils/notify'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ 'update:open': [value: boolean] }>()

const { t } = useI18n()
const complianceStore = useComplianceStore()

// ---- Expected sub-segments (UI 拆 4 段；提交时段 3a+3b 合并为段 3) ----
// 后端 segment3 = "并确认自行承担部署运营和收费行为产生的法律责任"（9+14=23 字，不含 、）
const EXPECTED = [
  '我已阅读并理解上述合规声明提醒',
  '知悉相关法律风险',
  '并确认自行承担部署',
  '运营和收费行为产生的法律责任',
] as const

const MAXLENGTHS = [15, 8, 9, 14] as const

// ---- State ----
const segments = ref<[string, string, string, string]>(['', '', '', ''])
const isComposing = ref<[boolean, boolean, boolean, boolean]>([false, false, false, false])
const shakeIndex = ref<number | null>(null)
const inputRefs = ref<(HTMLInputElement | null)[]>([null, null, null, null])
const submitting = ref(false)

// ---- Dialog open guard ----
function onDialogOpenChange(val: boolean) {
  if (!val && !complianceStore.acknowledged) {
    // Block close — keep open
    nextTick(() => emit('update:open', true))
    return
  }
  emit('update:open', val)
}

// ---- Reset on open ----
watch(
  () => props.open,
  (newVal, oldVal) => {
    if (newVal && !oldVal) {
      segments.value = ['', '', '', '']
      isComposing.value = [false, false, false, false]
      shakeIndex.value = null
      nextTick(() => {
        inputRefs.value[0]?.focus()
      })
    }
  },
)

// ---- Input handlers ----
function blockPaste(e: ClipboardEvent) {
  e.preventDefault()
  notifyError(t('compliance.dialog.pasteBlocked'))
}

function blockDrop(e: DragEvent) {
  e.preventDefault()
  notifyError(t('compliance.dialog.pasteBlocked'))
}

function blockDragStart(e: DragEvent) {
  e.preventDefault()
}

function blockContextMenu(e: MouseEvent) {
  e.preventDefault()
}

function onBeforeInput(_idx: number, e: InputEvent) {
  if (e.inputType === 'insertFromPaste' || e.inputType === 'insertFromDrop') {
    e.preventDefault()
    notifyError(t('compliance.dialog.pasteBlocked'))
  }
}

function triggerShake(idx: number) {
  shakeIndex.value = null
  nextTick(() => {
    shakeIndex.value = idx
    setTimeout(() => {
      shakeIndex.value = null
    }, 600)
  })
}

function onInput(idx: number, e: Event) {
  const inputEl = e.target as HTMLInputElement
  const newVal = inputEl.value
  const prevVal = segments.value[idx] ?? ''

  if (!isComposing.value[idx]) {
    // If length jumped by more than 1 char, it's likely a paste that slipped through
    if (newVal.length - prevVal.length > 1) {
      inputEl.value = prevVal
      ;(segments.value as string[])[idx] = prevVal
      notifyError(t('compliance.dialog.pasteBlocked'))
      return
    }
  }

  ;(segments.value as string[])[idx] = newVal

  // Live validation (only if not composing and non-empty and not a prefix)
  if (!isComposing.value[idx] && newVal.length > 0) {
    const expected = EXPECTED[idx] ?? ''
    if (!expected.startsWith(newVal)) {
      triggerShake(idx)
    }
  }
}

function onCompositionStart(idx: number) {
  isComposing.value[idx] = true
}

function onCompositionEnd(idx: number, e: Event) {
  isComposing.value[idx] = false
  const inputEl = e.target as HTMLInputElement
  const newVal = inputEl.value
  const prevVal = segments.value[idx] ?? ''

  // After IME commit, check for large jumps
  if (newVal.length - prevVal.length > 1) {
    inputEl.value = prevVal
    ;(segments.value as string[])[idx] = prevVal
    notifyError(t('compliance.dialog.pasteBlocked'))
    return
  }

  ;(segments.value as string[])[idx] = newVal

  if (newVal.length > 0) {
    const expected = EXPECTED[idx] ?? ''
    if (!expected.startsWith(newVal)) {
      triggerShake(idx)
    }
  }
}

// ---- Validation state per segment ----
function segmentState(idx: number): 'neutral' | 'valid' | 'invalid' {
  const val = segments.value[idx]
  if (!val) return 'neutral'
  const expected = EXPECTED[idx] ?? ''
  if (val === expected) return 'valid'
  if (!expected.startsWith(val)) return 'invalid'
  return 'neutral'
}

function inputClass(idx: number): string {
  const state = segmentState(idx)
  const base =
    'flex-1 min-w-0 rounded-md border bg-transparent px-3 py-1.5 text-sm outline-none transition-colors focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:ring-0'
  if (state === 'valid') return `${base} border-emerald-500`
  if (state === 'invalid') return `${base} border-destructive`
  return `${base} border-input focus:border-foreground/40`
}

const allValid = computed(() =>
  segments.value[0] === EXPECTED[0] &&
  segments.value[1] === EXPECTED[1] &&
  segments.value[2] === EXPECTED[2] &&
  segments.value[3] === EXPECTED[3],
)

// ---- Section data ----
const sections = [
  { titleKey: 'compliance.dialog.section1Title', bodyKey: 'compliance.dialog.section1Body' },
  { titleKey: 'compliance.dialog.section2Title', bodyKey: 'compliance.dialog.section2Body' },
  { titleKey: 'compliance.dialog.section3Title', bodyKey: 'compliance.dialog.section3Body' },
  { titleKey: 'compliance.dialog.section4Title', bodyKey: 'compliance.dialog.section4Body' },
]

// ---- Submission ----
async function handleSubmit() {
  if (!allValid.value || submitting.value) return
  submitting.value = true
  try {
    // 后端 segment3 = UI 段 3a + 段 3b（中间的 、 由后端单独插入校验）
    const backendSegment3 = segments.value[2] + segments.value[3]
    await complianceStore.acknowledge(segments.value[0], segments.value[1], backendSegment3)
    notifySuccess(t('compliance.toast.success'))
    segments.value = ['', '', '', '']
    emit('update:open', false)
  } catch (err: unknown) {
    const msg = (err as Error)?.message ?? ''
    if (msg.includes('compliance_required_by_super_admin')) {
      notifyError(t('compliance.toast.superRequired'))
    } else if (msg.includes('text_mismatch') || msg.includes('compliance.error.text_mismatch')) {
      notifyError(t('compliance.toast.mismatch'))
    } else {
      notifyError(t('compliance.toast.failed'))
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <Dialog :open="props.open" @update:open="onDialogOpenChange">
    <DialogContent
      class="w-[min(92vw,960px)] sm:max-w-none max-h-[90vh] overflow-y-auto [&>button.absolute]:hidden"
      @escape-key-down.prevent
      @pointer-down-outside.prevent
      @interact-outside.prevent
    >
      <DialogHeader>
        <DialogTitle class="flex items-center gap-2 text-base font-semibold">
          <ShieldCheck class="h-5 w-5 text-amber-500 shrink-0" />
          {{ t('compliance.dialog.title') }}
        </DialogTitle>
        <DialogDescription class="text-sm text-muted-foreground">
          {{ t('compliance.dialog.intro') }}
        </DialogDescription>
      </DialogHeader>

      <!-- Declaration body -->
      <div class="max-h-96 overflow-y-auto rounded-md border bg-muted/30 p-5 space-y-4 text-sm">
        <div v-for="section in sections" :key="section.titleKey">
          <p class="font-semibold text-foreground mb-1">{{ t(section.titleKey) }}</p>
          <p class="text-muted-foreground leading-relaxed">{{ t(section.bodyKey) }}</p>
        </div>
      </div>

      <!-- Confirmation input area -->
      <div class="space-y-3">
        <p class="text-sm font-medium text-foreground">{{ t('compliance.dialog.confirmLabel') }}</p>

        <!-- Reference text the user must type out, non-selectable to prevent copy -->
        <div
          class="rounded-md border border-amber-200 bg-amber-50 px-4 py-3 text-sm leading-relaxed text-amber-900 select-none"
          @copy.prevent
          @cut.prevent
          @contextmenu.prevent
          @dragstart.prevent
        >
          我已阅读并理解上述合规声明提醒，知悉相关法律风险，并确认自行承担部署、运营和收费行为产生的法律责任
        </div>

        <!-- Three inputs inline with punctuation separators -->
        <div class="flex flex-wrap items-center gap-1 text-sm">
          <!-- Segment 0 -->
          <input
            :ref="(el) => { inputRefs[0] = el as HTMLInputElement | null }"
            v-model="segments[0]"
            :class="[inputClass(0), shakeIndex === 0 ? 'ck-shake' : '']"
            :maxlength="MAXLENGTHS[0]"
            autocomplete="off"
            spellcheck="false"
            autocorrect="off"
            :placeholder="'（' + MAXLENGTHS[0] + '字）'"
            @paste="blockPaste"
            @drop="blockDrop"
            @dragstart="blockDragStart"
            @contextmenu="blockContextMenu"
            @beforeinput="(e) => onBeforeInput(0, e)"
            @input="(e) => onInput(0, e)"
            @compositionstart="() => onCompositionStart(0)"
            @compositionend="(e) => onCompositionEnd(0, e)"
          />

          <span class="text-muted-foreground select-none shrink-0">，</span>

          <!-- Segment 1 -->
          <input
            :ref="(el) => { inputRefs[1] = el as HTMLInputElement | null }"
            v-model="segments[1]"
            :class="[inputClass(1), shakeIndex === 1 ? 'ck-shake' : '']"
            :maxlength="MAXLENGTHS[1]"
            autocomplete="off"
            spellcheck="false"
            autocorrect="off"
            :placeholder="'（' + MAXLENGTHS[1] + '字）'"
            @paste="blockPaste"
            @drop="blockDrop"
            @dragstart="blockDragStart"
            @contextmenu="blockContextMenu"
            @beforeinput="(e) => onBeforeInput(1, e)"
            @input="(e) => onInput(1, e)"
            @compositionstart="() => onCompositionStart(1)"
            @compositionend="(e) => onCompositionEnd(1, e)"
          />

          <span class="text-muted-foreground select-none shrink-0">，</span>

          <!-- Segment 2 (UI 拆 3a) -->
          <input
            :ref="(el) => { inputRefs[2] = el as HTMLInputElement | null }"
            v-model="segments[2]"
            :class="[inputClass(2), shakeIndex === 2 ? 'ck-shake' : '']"
            :maxlength="MAXLENGTHS[2]"
            autocomplete="off"
            spellcheck="false"
            autocorrect="off"
            :placeholder="'（' + MAXLENGTHS[2] + '字）'"
            @paste="blockPaste"
            @drop="blockDrop"
            @dragstart="blockDragStart"
            @contextmenu="blockContextMenu"
            @beforeinput="(e) => onBeforeInput(2, e)"
            @input="(e) => onInput(2, e)"
            @compositionstart="() => onCompositionStart(2)"
            @compositionend="(e) => onCompositionEnd(2, e)"
          />

          <span class="text-muted-foreground select-none shrink-0">、</span>

          <!-- Segment 3 (UI 拆 3b) -->
          <input
            :ref="(el) => { inputRefs[3] = el as HTMLInputElement | null }"
            v-model="segments[3]"
            :class="[inputClass(3), shakeIndex === 3 ? 'ck-shake' : '']"
            :maxlength="MAXLENGTHS[3]"
            autocomplete="off"
            spellcheck="false"
            autocorrect="off"
            :placeholder="'（' + MAXLENGTHS[3] + '字）'"
            @paste="blockPaste"
            @drop="blockDrop"
            @dragstart="blockDragStart"
            @contextmenu="blockContextMenu"
            @beforeinput="(e) => onBeforeInput(3, e)"
            @input="(e) => onInput(3, e)"
            @compositionstart="() => onCompositionStart(3)"
            @compositionend="(e) => onCompositionEnd(3, e)"
          />
        </div>

        <!-- Punctuation hint -->
        <p class="text-xs text-muted-foreground">
          {{ t('compliance.dialog.punctuationHint') }}
        </p>
      </div>

      <DialogFooter class="gap-2">
        <Button
          variant="outline"
          :disabled="submitting"
          @click="emit('update:open', false)"
        >
          {{ t('compliance.dialog.cancel') }}
        </Button>
        <Button
          :disabled="!allValid || submitting"
          @click="handleSubmit"
        >
          {{ t('compliance.dialog.submit') }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>

<style scoped>
@keyframes ck-shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-3px); }
  75% { transform: translateX(3px); }
}

.ck-shake {
  animation: ck-shake 0.25s ease-in-out 2;
}
</style>

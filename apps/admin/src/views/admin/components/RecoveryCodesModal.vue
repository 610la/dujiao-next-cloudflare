<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { notifySuccess } from '@/utils/notify'

const props = defineProps<{ open: boolean; codes: string[] }>()
const emit = defineEmits<{ (e: 'update:open', value: boolean): void }>()

const { t } = useI18n()
const acknowledged = ref(false)

const close = () => {
  if (!acknowledged.value) return
  emit('update:open', false)
  acknowledged.value = false
}

const copyAll = async () => {
  await navigator.clipboard.writeText(props.codes.join('\n'))
  notifySuccess(t('admin.twofa.recovery.copied'))
}

const downloadTxt = () => {
  const blob = new Blob([props.codes.join('\n') + '\n'], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'dujiao-2fa-recovery-codes.txt'
  a.click()
  URL.revokeObjectURL(url)
}

watch(
  () => props.open,
  (val) => {
    if (val) acknowledged.value = false
  },
)
</script>

<template>
  <Dialog :open="open" @update:open="(v) => { if (acknowledged) emit('update:open', v) }">
    <DialogScrollContent
      class="w-[calc(100vw-1rem)] max-w-md p-4 sm:p-6"
      @interact-outside="(e: Event) => e.preventDefault()"
    >
      <DialogHeader>
        <DialogTitle class="text-destructive">{{ t('admin.twofa.recovery.title') }}</DialogTitle>
      </DialogHeader>

      <p class="text-sm text-muted-foreground">{{ t('admin.twofa.recovery.warning') }}</p>

      <div class="grid grid-cols-2 gap-2 font-mono text-sm bg-muted rounded p-3 mt-2">
        <div v-for="c in codes" :key="c" class="px-2 py-1">{{ c }}</div>
      </div>

      <div class="flex gap-2 mt-3">
        <Button variant="outline" class="flex-1" @click="copyAll">{{ t('admin.twofa.recovery.copyAll') }}</Button>
        <Button variant="outline" class="flex-1" @click="downloadTxt">{{ t('admin.twofa.recovery.download') }}</Button>
      </div>

      <label class="flex items-center gap-2 text-sm mt-4 cursor-pointer">
        <Checkbox :model-value="acknowledged" @update:model-value="(v) => acknowledged = !!v" />
        <span>{{ t('admin.twofa.recovery.acknowledge') }}</span>
      </label>

      <div class="flex justify-end mt-4">
        <Button :disabled="!acknowledged" @click="close">
          {{ t('admin.twofa.recovery.confirmClose') }}
        </Button>
      </div>
    </DialogScrollContent>
  </Dialog>
</template>

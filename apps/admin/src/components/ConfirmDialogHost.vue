<script setup lang="ts">
import { computed } from 'vue'
import { storeToRefs } from 'pinia'
import { useConfirmStore, type ConfirmDialogDescriptionSegment } from '@/stores/confirm'
import { Button } from '@/components/ui/button'
import { Dialog, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { DialogContent, DialogOverlay, DialogPortal } from 'reka-ui'

const confirmStore = useConfirmStore()
const { open, options } = storeToRefs(confirmStore)

const confirmVariant = computed(() => (options.value.variant === 'destructive' ? 'destructive' : 'default'))
const descriptionSegments = computed<ConfirmDialogDescriptionSegment[]>(() => {
  const description = options.value.description
  if (Array.isArray(description)) return description
  return [{ text: description }]
})

const segmentClass = (segment: ConfirmDialogDescriptionSegment) => {
  if (segment.tone === 'danger') return 'text-destructive'
  if (segment.tone === 'muted') return 'text-muted-foreground'
  return 'text-foreground'
}
</script>

<template>
  <Dialog :open="open" @update:open="confirmStore.setOpen">
    <DialogPortal>
      <DialogOverlay
        class="fixed inset-0 z-[190] bg-black/80 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0"
      />
      <DialogContent
        class="fixed left-1/2 top-1/2 z-[191] grid w-full max-w-lg -translate-x-1/2 -translate-y-1/2 gap-4 border bg-background p-6 shadow-lg duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 sm:rounded-lg sm:max-w-md"
      >
        <DialogHeader>
          <DialogTitle>{{ options.title }}</DialogTitle>
          <DialogDescription>
            <span
              v-for="(segment, index) in descriptionSegments"
              :key="index"
              :class="[segmentClass(segment), segment.strong ? 'font-semibold' : 'font-normal']"
            >
              {{ segment.text }}
            </span>
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" @click="confirmStore.cancel">{{ options.cancelText }}</Button>
          <Button :variant="confirmVariant" @click="confirmStore.confirm">{{ options.confirmText }}</Button>
        </DialogFooter>
      </DialogContent>
    </DialogPortal>
  </Dialog>
</template>

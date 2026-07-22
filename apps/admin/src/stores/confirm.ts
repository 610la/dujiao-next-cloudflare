import { ref } from 'vue'
import { defineStore } from 'pinia'

export type ConfirmDialogVariant = 'default' | 'destructive'
export type ConfirmDialogDescriptionTone = 'default' | 'danger' | 'muted'

export interface ConfirmDialogDescriptionSegment {
  text: string
  tone?: ConfirmDialogDescriptionTone
  strong?: boolean
}

export interface ConfirmDialogOptions {
  title: string
  description: string | ConfirmDialogDescriptionSegment[]
  confirmText: string
  cancelText: string
  variant: ConfirmDialogVariant
}

const defaultOptions: ConfirmDialogOptions = {
  title: '',
  description: '',
  confirmText: '',
  cancelText: '',
  variant: 'default',
}

export const useConfirmStore = defineStore('admin-confirm', () => {
  const open = ref(false)
  const options = ref<ConfirmDialogOptions>({ ...defaultOptions })
  let resolver: ((value: boolean) => void) | null = null

  const reset = () => {
    options.value = { ...defaultOptions }
  }

  const finalize = (value: boolean) => {
    const currentResolver = resolver
    resolver = null
    open.value = false
    reset()
    if (currentResolver) {
      currentResolver(value)
    }
  }

  const ask = (nextOptions: ConfirmDialogOptions) => {
    if (resolver) {
      finalize(false)
    }

    options.value = {
      ...nextOptions,
    }
    open.value = true

    return new Promise<boolean>((resolve) => {
      resolver = resolve
    })
  }

  const confirm = () => {
    finalize(true)
  }

  const cancel = () => {
    finalize(false)
  }

  const setOpen = (value: boolean) => {
    if (!value && open.value) {
      cancel()
      return
    }
    open.value = value
  }

  return {
    open,
    options,
    ask,
    confirm,
    cancel,
    setOpen,
  }
})

import { ref, readonly } from 'vue'

export interface ConfirmDialogOptions {
  title: string
  message: string
  confirmText?: string
  cancelText?: string
  variant?: 'danger' | 'default'
}

const visible = ref(false)
const options = ref<ConfirmDialogOptions>({
  title: '',
  message: '',
})

let resolvePromise: ((value: boolean) => void) | null = null

export function useConfirmDialog() {
  const confirm = (opts: ConfirmDialogOptions): Promise<boolean> => {
    options.value = opts
    visible.value = true
    return new Promise<boolean>((resolve) => {
      resolvePromise = resolve
    })
  }

  const handleConfirm = () => {
    visible.value = false
    resolvePromise?.(true)
    resolvePromise = null
  }

  const handleCancel = () => {
    visible.value = false
    resolvePromise?.(false)
    resolvePromise = null
  }

  return {
    visible: readonly(visible),
    options: readonly(options),
    confirm,
    handleConfirm,
    handleCancel,
  }
}

import { ref, readonly } from 'vue'

export interface ToastAction {
  label: string
  onClick: () => void
}

export interface ToastItem {
  id: number
  message: string
  type: 'success' | 'error' | 'info'
  action?: ToastAction
}

const toasts = ref<ToastItem[]>([])
let nextId = 0

const removeToast = (id: number) => {
  toasts.value = toasts.value.filter(t => t.id !== id)
}

const addToast = (message: string, type: ToastItem['type'], options?: { duration?: number; action?: ToastAction }) => {
  const id = ++nextId
  const duration = options?.duration ?? 3000
  toasts.value.push({ id, message, type, action: options?.action })
  const timer = setTimeout(() => removeToast(id), duration)
  return { id, cancel: () => { clearTimeout(timer); removeToast(id) } }
}

export const toast = {
  success: (message: string, options?: { duration?: number; action?: ToastAction }) => addToast(message, 'success', options),
  error: (message: string, options?: { duration?: number; action?: ToastAction }) => addToast(message, 'error', options),
  info: (message: string, options?: { duration?: number; action?: ToastAction }) => addToast(message, 'info', options),
}

export function useToast() {
  return {
    toasts: readonly(toasts),
    removeToast,
    toast,
  }
}

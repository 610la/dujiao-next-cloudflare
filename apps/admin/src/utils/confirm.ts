import i18n from '@/i18n'
import {
  useConfirmStore,
  type ConfirmDialogDescriptionSegment,
  type ConfirmDialogOptions,
  type ConfirmDialogVariant,
} from '@/stores/confirm'

export interface ConfirmActionOptions {
  title?: string
  description: string | ConfirmDialogDescriptionSegment[]
  confirmText?: string
  cancelText?: string
  variant?: ConfirmDialogVariant
}

const t = (key: string, params?: Record<string, unknown>) =>
  (params ? i18n.global.t(key, params) : i18n.global.t(key)) as string

export const confirmAction = (payload: string | ConfirmActionOptions) => {
  const store = useConfirmStore()
  const options: ConfirmActionOptions = typeof payload === 'string' ? { description: payload } : payload

  const confirmOptions: ConfirmDialogOptions = {
    title: options.title || t('admin.common.confirm'),
    description: options.description,
    confirmText: options.confirmText || t('admin.common.confirm'),
    cancelText: options.cancelText || t('admin.common.cancel'),
    variant: options.variant || 'default',
  }

  return store.ask(confirmOptions)
}

import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { notifySuccess } from '@/utils/notify'

export interface ListFetchOptions {
  preserveRows?: boolean
}

export const useListRefresh = () => {
  const refreshing = ref(false)
  const { t } = useI18n()

  const refreshList = async (loader: () => Promise<void>) => {
    if (refreshing.value) return
    refreshing.value = true
    try {
      await loader()
      notifySuccess(t('admin.common.refreshSuccess'))
    } finally {
      refreshing.value = false
    }
  }

  return {
    refreshing,
    refreshList,
  }
}

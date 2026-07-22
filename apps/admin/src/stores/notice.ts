import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

export type NoticeType = 'error' | 'success' | 'info'

export interface NoticeItem {
  id: number
  message: string
  type: NoticeType
}

const simplifyNoticeMessage = (input: string) => {
  let value = String(input || '').trim()
  if (!value) {
    return ''
  }
  value = value.replace(
    /^(操作失败|請求失敗|请求失败|提交失败|保存失败|删除失败|更新失败|创建失败|上傳失敗|上传失败|operation failed|request failed)\s*[:：\-]\s*/i,
    ''
  )
  return value
    .toLowerCase()
    .replace(/[\s`~!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?，。！？；：、“”‘’（）【】《》·…—-]/g, '')
}

export const useNoticeStore = defineStore('admin-notice', () => {
  const items = ref<NoticeItem[]>([])
  const timerMap = new Map<number, number>()
  let sequence = 0

  const remove = (id: number) => {
    const timeoutId = timerMap.get(id)
    if (typeof timeoutId === 'number') {
      window.clearTimeout(timeoutId)
      timerMap.delete(id)
    }
    items.value = items.value.filter((item) => item.id !== id)
  }

  const hasSimilarVisibleNotice = (kind: NoticeType, message: string) => {
    const current = simplifyNoticeMessage(message)
    if (!current) {
      return false
    }
    return items.value.some((item) => {
      if (item.type !== kind) {
        return false
      }
      const existing = simplifyNoticeMessage(item.message)
      if (!existing) {
        return false
      }
      return existing === current || existing.includes(current) || current.includes(existing)
    })
  }

  const show = (msg: string, kind: NoticeType = 'error', duration = 6000) => {
    const message = msg?.trim()
    if (!message) return
    if (hasSimilarVisibleNotice(kind, message)) return

    const id = ++sequence
    items.value.push({
      id,
      message,
      type: kind,
    })

    if (duration > 0) {
      const timeoutId = window.setTimeout(() => {
        remove(id)
      }, duration)
      timerMap.set(id, timeoutId)
    }

    if (items.value.length > 5) {
      const overflow = items.value.slice(0, items.value.length - 5)
      overflow.forEach((item) => remove(item.id))
    }

    return id
  }

  const clear = () => {
    const first = items.value[0]
    if (first) {
      remove(first.id)
    }
  }

  const clearAll = () => {
    items.value.forEach((item) => {
      const timeoutId = timerMap.get(item.id)
      if (typeof timeoutId === 'number') {
        window.clearTimeout(timeoutId)
      }
    })
    timerMap.clear()
    items.value = []
  }

  const message = computed(() => items.value[0]?.message || '')
  const type = computed<NoticeType>(() => items.value[0]?.type || 'info')
  const visible = computed(() => items.value.length > 0)

  return {
    items,
    message,
    type,
    visible,
    show,
    remove,
    clear,
    clearAll,
  }
})

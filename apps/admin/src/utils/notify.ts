import i18n from '@/i18n'
import { useNoticeStore, type NoticeType } from '@/stores/notice'

const t = (key: string, params?: Record<string, unknown>) =>
  (params ? i18n.global.t(key, params) : i18n.global.t(key)) as string

const dedupeWindowMs = 1500
let lastMessage = ''
let lastNormalized = ''
let lastType: NoticeType | '' = ''
let lastAt = 0

const simplifyMessage = (input: string) => {
  let value = input.trim()
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

const shouldSkip = (type: NoticeType, content: string) => {
  const normalized = content.trim()
  if (!normalized) {
    return false
  }
  const normalizedCore = simplifyMessage(normalized)
  const now = Date.now()
  const withinWindow = now - lastAt <= dedupeWindowMs
  const sameType = lastType === type
  const duplicatedExact = sameType && lastMessage === normalized && withinWindow
  const duplicatedNormalized = sameType && normalizedCore !== '' && lastNormalized === normalizedCore && withinWindow
  const duplicatedSimilar =
    sameType &&
    normalizedCore !== '' &&
    lastNormalized !== '' &&
    withinWindow &&
    (normalizedCore.includes(lastNormalized) || lastNormalized.includes(normalizedCore))

  const duplicated = duplicatedExact || duplicatedNormalized || duplicatedSimilar

  lastType = type
  lastMessage = normalized
  lastNormalized = normalizedCore
  lastAt = now
  return duplicated
}

const pushNotice = (message: string | undefined, type: NoticeType, fallbackKey = 'common.api.requestFailed') => {
  try {
    const store = useNoticeStore()
    const fallback = t(fallbackKey)
    const content = message && message.trim() ? message : fallback
    if (shouldSkip(type, content)) {
      return
    }
    store.show(content, type)
  } catch {
  }
}

export const notifyError = (message?: string) => {
  pushNotice(message, 'error')
}

export const notifySuccess = (message?: string) => {
  pushNotice(message, 'success', 'admin.common.operationSuccess')
}

export const notifyInfo = (message?: string) => {
  pushNotice(message, 'info', 'admin.common.notice')
}

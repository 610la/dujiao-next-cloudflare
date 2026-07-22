const DISMISS_KEY = 'announcement_dismiss'
const SESSION_KEY = 'announcement_closed'

interface DismissRecord {
  version: string
  mode: 'today' | 'forever'
  date?: string
}

export interface HomeAnnouncement {
  type: string
  title: Record<string, string>
  content: Record<string, string>
  version: string
}

// 浏览器本地日期 YYYY-MM-DD
const todayStr = (): string => {
  const d = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

const readDismiss = (): DismissRecord | null => {
  try {
    const raw = localStorage.getItem(DISMISS_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw)
    if (parsed && typeof parsed.version === 'string') return parsed as DismissRecord
  } catch {
    // 解析失败视为无记录
  }
  return null
}

export function useAnnouncement() {
  // 判断公告是否应展示：version 变化会令所有历史关闭记录失效
  const shouldShow = (announcement: HomeAnnouncement | null | undefined): boolean => {
    if (!announcement || !announcement.version) return false
    const dismiss = readDismiss()
    if (dismiss && dismiss.version === announcement.version) {
      if (dismiss.mode === 'forever') return false
      if (dismiss.mode === 'today' && dismiss.date === todayStr()) return false
    }
    try {
      if (sessionStorage.getItem(SESSION_KEY) === announcement.version) return false
    } catch {
      // sessionStorage 不可用时忽略
    }
    return true
  }

  // 不再提示（这条公告永久不弹）
  const dismissForever = (version: string) => {
    try {
      localStorage.setItem(DISMISS_KEY, JSON.stringify({ version, mode: 'forever' }))
    } catch {
      // 忽略写入失败
    }
  }

  // 今日不再提示
  const dismissToday = (version: string) => {
    try {
      localStorage.setItem(DISMISS_KEY, JSON.stringify({ version, mode: 'today', date: todayStr() }))
    } catch {
      // 忽略写入失败
    }
  }

  // 仅本次会话关闭
  const closeForSession = (version: string) => {
    try {
      sessionStorage.setItem(SESSION_KEY, version)
    } catch {
      // 忽略写入失败
    }
  }

  return { shouldShow, dismissForever, dismissToday, closeForSession }
}

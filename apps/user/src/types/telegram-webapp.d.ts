export interface TelegramWebAppThemeParams {
  bg_color?: string
  secondary_bg_color?: string
  text_color?: string
  hint_color?: string
  link_color?: string
  button_color?: string
  button_text_color?: string
  header_bg_color?: string
  accent_text_color?: string
  section_bg_color?: string
  section_header_text_color?: string
  subtitle_text_color?: string
  destructive_text_color?: string
}

export interface TelegramWebAppBackButton {
  isVisible?: boolean
  show: () => void
  hide: () => void
  onClick: (callback: () => void) => void
  offClick: (callback: () => void) => void
}

export interface TelegramWebAppLinkOptions {
  try_instant_view?: boolean
}

export interface TelegramWebApp {
  initData: string
  initDataUnsafe?: Record<string, unknown>
  version?: string
  platform?: string
  colorScheme?: 'light' | 'dark'
  themeParams?: TelegramWebAppThemeParams
  viewportHeight?: number
  viewportStableHeight?: number
  isExpanded?: boolean
  ready: () => void
  expand?: () => void
  openLink?: (url: string, options?: TelegramWebAppLinkOptions) => void
  onEvent?: (eventType: string, callback: () => void) => void
  offEvent?: (eventType: string, callback: () => void) => void
  BackButton?: TelegramWebAppBackButton
}

declare global {
  interface Window {
    Telegram?: {
      WebApp?: TelegramWebApp
    }
  }
}

export {}

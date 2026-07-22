export type PageAlertLevel = 'success' | 'error' | 'warning'

export interface PageAlert {
  level: PageAlertLevel
  message: string
}

// shadcn <Alert> 适配:variant 只有 default/destructive,success/warning 用 tone class 补色
export const pageAlertVariant = (level: PageAlertLevel): 'default' | 'destructive' =>
  level === 'error' ? 'destructive' : 'default'

export const pageAlertToneClass = (level: PageAlertLevel): string => {
  if (level === 'success') return 'border-success/40 text-success'
  if (level === 'warning') return 'border-warning/40 text-warning'
  return ''
}

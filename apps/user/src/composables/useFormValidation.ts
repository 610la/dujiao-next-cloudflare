import { reactive, computed } from 'vue'
import { useI18n } from 'vue-i18n'

type ValidationRule = (value: string) => string | null

export function useFormValidation<T extends Record<string, string>>(fields: (keyof T)[]) {
  const { t } = useI18n()
  const errors = reactive<Record<string, string>>({})
  const touched = reactive<Record<string, boolean>>({})

  const rules: Record<string, ValidationRule[]> = {}

  const addRule = (field: keyof T, rule: ValidationRule) => {
    const key = field as string
    if (!rules[key]) rules[key] = []
    rules[key].push(rule)
  }

  const validateField = (field: keyof T, value: string): string | null => {
    const key = field as string
    const fieldRules = rules[key] || []
    for (const rule of fieldRules) {
      const error = rule(value)
      if (error) {
        errors[key] = error
        return error
      }
    }
    errors[key] = ''
    return null
  }

  const touchField = (field: keyof T, value: string) => {
    const key = field as string
    touched[key] = true
    validateField(field, value)
  }

  const validateAll = (values: Record<string, string>): boolean => {
    let valid = true
    for (const field of fields) {
      const key = field as string
      touched[key] = true
      const error = validateField(field, values[key] || '')
      if (error) valid = false
    }
    return valid
  }

  const getError = (field: keyof T): string => {
    const key = field as string
    return touched[key] ? (errors[key] || '') : ''
  }

  const hasError = (field: keyof T): boolean => {
    return getError(field) !== ''
  }

  const isValid = computed(() => {
    return fields.every(f => !errors[f as string])
  })

  const clearErrors = () => {
    for (const key of Object.keys(errors)) {
      errors[key] = ''
    }
    for (const key of Object.keys(touched)) {
      touched[key] = false
    }
  }

  // Common validation rules
  const requiredRule = (): ValidationRule => (value: string) => {
    return value.trim() ? null : t('formValidation.required')
  }

  const emailRule = (): ValidationRule => (value: string) => {
    if (!value.trim()) return null
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(value) ? null : t('formValidation.emailInvalid')
  }

  const minLengthRule = (min: number): ValidationRule => (value: string) => {
    if (!value) return null
    return value.length >= min ? null : t('formValidation.passwordTooShort', { min })
  }

  return {
    errors,
    touched,
    addRule,
    validateField,
    touchField,
    validateAll,
    getError,
    hasError,
    isValid,
    clearErrors,
    requiredRule,
    emailRule,
    minLengthRule,
  }
}

export function getPasswordStrength(password: string): 'weak' | 'medium' | 'strong' {
  if (!password || password.length < 6) return 'weak'
  let score = 0
  if (password.length >= 8) score++
  if (password.length >= 12) score++
  if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++
  if (/\d/.test(password)) score++
  if (/[^a-zA-Z0-9]/.test(password)) score++
  if (score <= 2) return 'weak'
  if (score <= 3) return 'medium'
  return 'strong'
}

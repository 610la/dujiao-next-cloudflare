import { reactive, computed } from 'vue'

export type ValidationRule = (value: unknown) => string | true

/** Built-in rule factories */
export const rules = {
  required: (msg = 'This field is required'): ValidationRule =>
    (v) => {
      if (v === null || v === undefined || v === '') return msg
      if (Array.isArray(v) && v.length === 0) return msg
      return true
    },

  minLength: (min: number, msg?: string): ValidationRule =>
    (v) => {
      if (typeof v === 'string' && v.length < min)
        return msg || `Minimum ${min} characters`
      return true
    },

  maxLength: (max: number, msg?: string): ValidationRule =>
    (v) => {
      if (typeof v === 'string' && v.length > max)
        return msg || `Maximum ${max} characters`
      return true
    },

  min: (min: number, msg?: string): ValidationRule =>
    (v) => {
      const n = Number(v)
      if (!Number.isNaN(n) && n < min) return msg || `Minimum value is ${min}`
      return true
    },

  max: (max: number, msg?: string): ValidationRule =>
    (v) => {
      const n = Number(v)
      if (!Number.isNaN(n) && n > max) return msg || `Maximum value is ${max}`
      return true
    },

  email: (msg = 'Invalid email'): ValidationRule =>
    (v) => {
      if (typeof v === 'string' && v && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v))
        return msg
      return true
    },

  url: (msg = 'Invalid URL'): ValidationRule =>
    (v) => {
      if (typeof v !== 'string' || !v) return true
      try {
        new URL(v)
        return true
      } catch {
        return msg
      }
    },

  numeric: (msg = 'Must be a number'): ValidationRule =>
    (v) => {
      if (v === '' || v === null || v === undefined) return true
      if (Number.isNaN(Number(v))) return msg
      return true
    },
}

export interface FieldSchema {
  [field: string]: ValidationRule[]
}

export function useFormValidation<T extends Record<string, unknown>>(
  schema: FieldSchema
) {
  const errors = reactive<Record<string, string>>({})

  const validateField = (field: string, value: unknown): boolean => {
    const fieldRules = schema[field]
    if (!fieldRules) return true
    for (const rule of fieldRules) {
      const result = rule(value)
      if (result !== true) {
        errors[field] = result
        return false
      }
    }
    errors[field] = ''
    return false
  }

  const validate = (data: T): boolean => {
    let valid = true
    for (const field of Object.keys(schema)) {
      const value = data[field]
      const fieldRules = schema[field]
      if (!fieldRules) continue
      let fieldValid = true
      for (const rule of fieldRules) {
        const result = rule(value)
        if (result !== true) {
          errors[field] = result
          fieldValid = false
          valid = false
          break
        }
      }
      if (fieldValid) {
        errors[field] = ''
      }
    }
    return valid
  }

  const clearErrors = () => {
    for (const key of Object.keys(errors)) {
      errors[key] = ''
    }
  }

  const hasErrors = computed(() =>
    Object.values(errors).some((e) => e !== '' && e !== undefined)
  )

  return {
    errors,
    validate,
    validateField,
    clearErrors,
    hasErrors,
  }
}

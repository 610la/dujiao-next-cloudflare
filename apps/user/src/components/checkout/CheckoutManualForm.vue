<template>
  <div
    v-if="manualFormProducts.length"
    class="rounded-2xl border bg-card text-card-foreground p-6"
  >
    <h2 class="mb-2 text-lg font-bold text-foreground">{{ t('checkout.manualFormTitle') }}</h2>
    <p class="mb-4 text-xs text-muted-foreground">{{ t('checkout.manualFormTip') }}</p>
    <div class="space-y-5">
      <div
        v-for="manualItem in manualFormProducts"
        :key="manualItem.itemKey"
        class="rounded-xl border bg-secondary p-4"
      >
        <h3 class="mb-3 text-sm font-semibold text-foreground">{{ manualItemTitle(manualItem) }}</h3>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div v-for="field in manualItem.fields" :key="`${manualItem.itemKey}-${field.key}`" class="space-y-1.5">
            <label class="text-xs font-semibold text-muted-foreground">
              {{ getManualFieldLabel(field) }}
              <span v-if="field.required" class="ml-1 text-destructive">*</span>
            </label>

            <Textarea
              v-if="field.type === 'textarea'"
              :model-value="getFieldValue(manualItem.itemKey, field.key)"
              @update:model-value="updateFieldValue(manualItem.itemKey, field.key, $event)"
              rows="3"
              :placeholder="getManualFieldPlaceholder(field)"
            />

            <select
              v-else-if="field.type === 'select'"
              :value="getFieldValue(manualItem.itemKey, field.key)"
              @change="updateFieldValue(manualItem.itemKey, field.key, ($event.target as HTMLSelectElement).value)"
              :class="selectClass"
            >
              <option value="">{{ t('checkout.manualFormSelectPlaceholder') }}</option>
              <option v-for="option in field.options" :key="option" :value="option">{{ option }}</option>
            </select>

            <div v-else-if="field.type === 'china_region'" class="grid grid-cols-1 gap-2 sm:grid-cols-3">
              <select
                :value="getChinaRegionParts(manualItem.itemKey, field.key).provinceCode"
                @change="updateChinaRegion(manualItem.itemKey, field.key, 'province', ($event.target as HTMLSelectElement).value)"
                :class="selectClass"
              >
                <option value="">{{ t('checkout.manualFormSelectPlaceholder') }}省份</option>
                <option v-for="option in provinceOptions" :key="option.code" :value="option.code">{{ option.label }}</option>
              </select>
              <select
                :value="getChinaRegionParts(manualItem.itemKey, field.key).cityCode"
                @change="updateChinaRegion(manualItem.itemKey, field.key, 'city', ($event.target as HTMLSelectElement).value)"
                :class="selectClass"
                :disabled="!getChinaRegionParts(manualItem.itemKey, field.key).provinceCode"
              >
                <option value="">{{ t('checkout.manualFormSelectPlaceholder') }}城市</option>
                <option
                  v-for="option in getRegionOptions(getChinaRegionParts(manualItem.itemKey, field.key).provinceCode)"
                  :key="option.code"
                  :value="option.code"
                >
                  {{ option.label }}
                </option>
              </select>
              <select
                :value="getChinaRegionParts(manualItem.itemKey, field.key).districtCode"
                @change="updateChinaRegion(manualItem.itemKey, field.key, 'district', ($event.target as HTMLSelectElement).value)"
                :class="selectClass"
                :disabled="!getChinaRegionParts(manualItem.itemKey, field.key).cityCode"
              >
                <option value="">{{ t('checkout.manualFormSelectPlaceholder') }}区县</option>
                <option
                  v-for="option in getRegionOptions(getChinaRegionParts(manualItem.itemKey, field.key).cityCode)"
                  :key="option.code"
                  :value="option.code"
                >
                  {{ option.label }}
                </option>
              </select>
            </div>

            <div v-else-if="field.type === 'radio'" class="space-y-2 rounded-xl border bg-secondary p-3">
              <label v-for="option in field.options" :key="option" class="flex items-center gap-2 text-sm text-muted-foreground">
                <input
                  :checked="getFieldValue(manualItem.itemKey, field.key) === option"
                  @change="updateFieldValue(manualItem.itemKey, field.key, option)"
                  type="radio"
                  :name="`manual-radio-${manualItem.itemKey}-${field.key}`"
                  :value="option"
                  class="h-4 w-4 accent-primary"
                />
                <span>{{ option }}</span>
              </label>
            </div>

            <div v-else-if="field.type === 'checkbox'" class="space-y-2 rounded-xl border bg-secondary p-3">
              <label v-for="option in field.options" :key="option" class="flex items-center gap-2 text-sm text-muted-foreground">
                <input
                  :checked="isCheckboxChecked(manualItem.itemKey, field.key, option)"
                  @change="toggleCheckboxValue(manualItem.itemKey, field.key, option, ($event.target as HTMLInputElement).checked)"
                  type="checkbox"
                  :value="option"
                  class="h-4 w-4 accent-primary"
                />
                <span>{{ option }}</span>
              </label>
            </div>

            <Input
              v-else
              :model-value="getFieldValue(manualItem.itemKey, field.key)"
              @update:model-value="updateFieldValue(manualItem.itemKey, field.key, $event)"
              :type="field.type === 'number' ? 'number' : field.type === 'email' ? 'email' : field.type === 'phone' ? 'tel' : 'text'"
              :placeholder="getManualFieldPlaceholder(field)"
            />

            <p
              v-if="submitAttempted && manualFieldError(manualItem.itemKey, field.key)"
              class="text-xs text-destructive"
            >
              {{ manualFieldError(manualItem.itemKey, field.key) }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import areaData from 'area-data'
import { useLocalized } from '../../composables/useProduct'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'

const selectClass =
  'theme-native-select h-9 w-full rounded-md border border-input px-3 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-60'

interface ManualFormField {
  key: string
  type: string
  required: boolean
  label?: Record<string, string>
  placeholder?: Record<string, string>
  regex?: string
  min?: number
  max?: number
  max_len?: number
  options: string[]
}

interface ManualFormProduct {
  itemKey: string
  productId: number
  title: any
  fields: ManualFormField[]
  skuCount: number
}

const props = defineProps<{
  manualFormProducts: ManualFormProduct[]
  modelValue: Record<string, Record<string, any>>
  submitAttempted: boolean
  getManualFieldLabel: (field: ManualFormField) => string
  getManualFieldPlaceholder: (field: ManualFormField) => string
  manualFieldError: (itemKey: string, fieldKey: string) => string
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: Record<string, Record<string, any>>): void
}>()

const { t } = useI18n()
const { getLocalizedText } = useLocalized()
const pcaa = ((areaData as any)?.pcaa || {}) as Record<string, Record<string, string>>

type ChinaRegionLevel = 'province' | 'city' | 'district'

const getRegionOptions = (parentCode: string) => {
  const rows = pcaa[String(parentCode || '')] || {}
  return Object.entries(rows).map(([code, label]) => ({ code, label }))
}

const provinceOptions = getRegionOptions('86')

const encodeChinaRegion = (provinceCode = '', cityCode = '', districtCode = '') => {
  const province = pcaa['86']?.[provinceCode] || ''
  const city = pcaa[provinceCode]?.[cityCode] || ''
  const district = pcaa[cityCode]?.[districtCode] || ''
  const text = [province, city, district].filter(Boolean).join(' / ')
  return [provinceCode, cityCode, districtCode, text].join('|')
}

const parseChinaRegion = (value: unknown) => {
  const raw = String(value ?? '').trim()
  if (!raw) {
    return { provinceCode: '', cityCode: '', districtCode: '', text: '' }
  }
  const [provinceCode = '', cityCode = '', districtCode = '', ...textParts] = raw.split('|')
  return {
    provinceCode,
    cityCode,
    districtCode,
    text: textParts.join('|').trim(),
  }
}

const manualItemTitle = (manualItem: ManualFormProduct) => {
  const productTitle = getLocalizedText(manualItem.title)
  if (manualItem.skuCount <= 1) return productTitle
  return `${productTitle} (${t('checkout.manualFormAppliesToSkuCount', { count: manualItem.skuCount })})`
}

const getFieldValue = (itemKey: string, fieldKey: string) => {
  return props.modelValue[itemKey]?.[fieldKey] ?? ''
}

const getChinaRegionParts = (itemKey: string, fieldKey: string) => {
  return parseChinaRegion(getFieldValue(itemKey, fieldKey))
}

const updateFieldValue = (itemKey: string, fieldKey: string, value: any) => {
  const updated = { ...props.modelValue }
  if (!updated[itemKey]) {
    updated[itemKey] = {}
  }
  updated[itemKey] = { ...updated[itemKey], [fieldKey]: value }
  emit('update:modelValue', updated)
}

const updateChinaRegion = (itemKey: string, fieldKey: string, level: ChinaRegionLevel, code: string) => {
  const current = getChinaRegionParts(itemKey, fieldKey)
  if (level === 'province') {
    updateFieldValue(itemKey, fieldKey, encodeChinaRegion(code, '', ''))
    return
  }
  if (level === 'city') {
    updateFieldValue(itemKey, fieldKey, encodeChinaRegion(current.provinceCode, code, ''))
    return
  }
  updateFieldValue(itemKey, fieldKey, encodeChinaRegion(current.provinceCode, current.cityCode, code))
}

const isCheckboxChecked = (itemKey: string, fieldKey: string, option: string) => {
  const value = props.modelValue[itemKey]?.[fieldKey]
  return Array.isArray(value) && value.includes(option)
}

const toggleCheckboxValue = (itemKey: string, fieldKey: string, option: string, checked: boolean) => {
  const current = props.modelValue[itemKey]?.[fieldKey]
  const list = Array.isArray(current) ? [...current] : []
  if (checked) {
    if (!list.includes(option)) list.push(option)
  } else {
    const idx = list.indexOf(option)
    if (idx !== -1) list.splice(idx, 1)
  }
  updateFieldValue(itemKey, fieldKey, list)
}
</script>

<style>
.theme-native-select {
  color: var(--ui-text-primary);
  background-color: var(--ui-bg-elevated);
  color-scheme: light;
}

.theme-native-select option {
  color: #1d1d1f;
  background-color: #ffffff;
}

.theme-native-select option:checked {
  color: #ffffff;
  background-color: #0071e3;
}

.theme-native-select:disabled {
  color: var(--ui-text-muted);
  background-color: var(--ui-bg-muted);
}

.dark .theme-native-select {
  color-scheme: dark;
  color: var(--ui-text-primary);
  background-color: var(--ui-bg-elevated);
}

.dark .theme-native-select option {
  color: var(--ui-text-primary);
  background-color: var(--ui-bg-elevated);
}

.dark .theme-native-select option:checked {
  color: var(--ui-text-on-accent);
  background-color: var(--ui-accent);
}
</style>

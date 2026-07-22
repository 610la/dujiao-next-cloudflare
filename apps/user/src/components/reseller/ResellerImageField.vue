<template>
  <div>
    <span v-if="label" class="mb-2 block text-sm font-medium text-muted-foreground">{{ label }}</span>
    <div class="flex items-start gap-3">
      <button
        type="button"
        class="group relative flex shrink-0 items-center justify-center overflow-hidden rounded-xl border border-dashed border-input bg-muted/40 transition-colors hover:border-primary/60 hover:bg-muted disabled:cursor-not-allowed"
        :class="wide ? 'h-20 w-32' : 'h-20 w-20'"
        :disabled="uploading"
        :aria-label="modelValue ? replaceLabel : uploadLabel"
        @click="triggerUpload"
      >
        <img v-if="modelValue && !broken" :src="preview" alt="" class="h-full w-full object-contain" @error="broken = true" />
        <Loader2 v-else-if="uploading" class="h-5 w-5 animate-spin text-muted-foreground" />
        <ImageOff v-else-if="modelValue && broken" class="h-5 w-5 text-destructive/60" />
        <span v-else class="flex flex-col items-center gap-1 text-muted-foreground">
          <ImagePlus class="h-5 w-5" />
          <span class="text-[10px] leading-none">{{ uploadLabel }}</span>
        </span>
      </button>

      <div class="min-w-0 flex-1 space-y-1.5">
        <div class="flex flex-wrap items-center gap-2">
          <Button type="button" variant="outline" size="sm" :disabled="uploading" @click="triggerUpload">
            <Loader2 v-if="uploading" class="mr-1.5 h-3.5 w-3.5 animate-spin" />
            <Upload v-else class="mr-1.5 h-3.5 w-3.5" />
            {{ modelValue ? replaceLabel : uploadLabel }}
          </Button>
          <Button
            v-if="modelValue"
            type="button"
            variant="ghost"
            size="sm"
            class="text-destructive hover:bg-destructive/10 hover:text-destructive"
            :disabled="uploading"
            @click="emit('update:modelValue', '')"
          >
            <Trash2 class="mr-1.5 h-3.5 w-3.5" />
            {{ removeLabel }}
          </Button>
        </div>
        <p v-if="error" class="text-xs text-destructive">{{ error }}</p>
        <p v-else-if="hint" class="text-xs text-muted-foreground">{{ hint }}</p>
      </div>
    </div>

    <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onFileChange" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { ImageOff, ImagePlus, Loader2, Trash2, Upload } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { resellerAPI } from '../../api'
import { getImageUrl } from '../../utils/image'

const props = defineProps<{
  modelValue: string
  label?: string
  hint?: string
  wide?: boolean
}>()
const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()

const { t } = useI18n()
const fileInput = ref<HTMLInputElement | null>(null)
const uploading = ref(false)
const error = ref('')
const broken = ref(false)

const preview = computed(() => (props.modelValue ? getImageUrl(props.modelValue) : ''))
const uploadLabel = computed(() => t('personalCenter.reseller.siteConfig.upload'))
const replaceLabel = computed(() => t('personalCenter.reseller.siteConfig.replace'))
const removeLabel = computed(() => t('personalCenter.reseller.siteConfig.actions.remove'))

watch(
  () => props.modelValue,
  () => {
    broken.value = false
  },
)

const triggerUpload = () => fileInput.value?.click()

const onFileChange = async (e: Event) => {
  const input = e.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  uploading.value = true
  error.value = ''
  try {
    const res = await resellerAPI.uploadImage(file)
    const url = res.data?.data?.url
    if (url) {
      broken.value = false
      emit('update:modelValue', url)
    }
  } catch (err: any) {
    error.value = err?.message || t('personalCenter.reseller.siteConfig.uploadFailed')
  } finally {
    uploading.value = false
  }
}
</script>

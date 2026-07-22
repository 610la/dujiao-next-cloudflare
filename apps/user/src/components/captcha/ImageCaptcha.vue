<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { captchaAPI, type CaptchaPayload } from '../../api'

const { t } = useI18n()

const props = withDefaults(defineProps<{
  modelValue?: CaptchaPayload
  disabled?: boolean
}>(), {
  modelValue: () => ({}),
  disabled: false,
})

const emit = defineEmits<{
  (event: 'update:modelValue', value: CaptchaPayload): void
  (event: 'config-stale'): void
}>()

const loading = ref(false)
const imageBase64 = ref('')
const captchaID = ref(props.modelValue?.captcha_id || '')
const captchaCode = ref(props.modelValue?.captcha_code || '')

const syncModel = () => {
  emit('update:modelValue', {
    captcha_id: captchaID.value,
    captcha_code: captchaCode.value,
  })
}

const refresh = async (clearCode = true) => {
  loading.value = true
  try {
    const res = await captchaAPI.image()
    const data = res.data?.data as { captcha_id?: string; image_base64?: string } | undefined
    captchaID.value = String(data?.captcha_id || '')
    imageBase64.value = String(data?.image_base64 || '')
    if (clearCode) {
      captchaCode.value = ''
    }
    syncModel()
  } catch {
    captchaID.value = ''
    imageBase64.value = ''
    captchaCode.value = ''
    syncModel()
    emit('config-stale')
  } finally {
    loading.value = false
  }
}

const clear = () => {
  captchaCode.value = ''
  syncModel()
}

watch(captchaCode, () => {
  syncModel()
})

onMounted(() => {
  refresh()
})

defineExpose({
  refresh,
  clear,
})
</script>

<template>
  <div class="space-y-2">
    <div class="flex items-center gap-3">
      <img
        v-if="imageBase64"
        :src="imageBase64"
        alt="captcha"
        class="h-10 rounded-md border bg-muted dark:border-white/10 dark:bg-white/5"
      />
      <button
        type="button"
        class="text-xs text-muted-foreground underline underline-offset-2 hover:text-foreground"
        :disabled="disabled || loading"
        @click="refresh()"
      >
        {{ loading ? t('auth.common.captchaRefreshing') : t('auth.common.captchaRefresh') }}
      </button>
    </div>
    <input
      v-model="captchaCode"
      type="text"
      class="h-10 w-full rounded-xl border bg-background px-3 text-sm text-foreground dark:border-white/10 dark:bg-black/20"
      :placeholder="t('auth.common.captchaCodePlaceholder')"
      :disabled="disabled"
      autocomplete="off"
    />
  </div>
</template>

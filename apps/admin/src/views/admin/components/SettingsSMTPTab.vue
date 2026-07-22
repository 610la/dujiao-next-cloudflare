<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { notifyError, notifySuccess } from '@/utils/notify'

const { t } = useI18n()

interface SMTPData {
  enabled: boolean
  transport: 'cloudflare' | 'resend'
  host: string
  port: number
  username: string
  password: string
  has_password: boolean
  from: string
  from_name: string
  use_tls: boolean
  use_ssl: boolean
  order_notification_enabled: boolean
  cloudflare: {
    account_id: string
    zone_id: string
    api_token: string
    has_api_token: boolean
  }
  resend: {
    api_key: string
    has_api_key: boolean
  }
  verify_code: {
    expire_minutes: number
    send_interval_seconds: number
    max_attempts: number
    length: number
  }
}

const props = defineProps<{
  data: SMTPData
}>()

const emit = defineEmits<{
  saved: []
}>()

const submitting = ref(false)
const smtpTesting = ref(false)
const cloudflareChecking = ref(false)
const cloudflareOnboarding = ref(false)
const cloudflareStatus = ref<Record<string, unknown> | null>(null)
const cloudflareStatusMessage = ref('')
const cloudflareDomain = computed(() => {
  const fromDomain = String(form.from || '').split('@')[1] || ''
  return String(cloudflareStatus.value?.domain || fromDomain || 'example.com')
})
const cloudflareZoneLabel = computed(() => {
  const zone = (cloudflareStatus.value?.zone || {}) as Record<string, unknown>
  return String(zone.id || form.cloudflare.zone_id || '-')
})
const cloudflareEnabled = computed(() => cloudflareStatus.value?.enabled === true)
const cloudflareStatusLabel = computed(() => {
  if (!cloudflareStatus.value && !cloudflareStatusMessage.value) return '未检查'
  return cloudflareEnabled.value ? '已启用' : '未启用'
})

const form = reactive({
  enabled: false,
  transport: 'cloudflare' as 'cloudflare' | 'resend',
  host: '',
  port: 587,
  username: '',
  password: '',
  has_password: false,
  from: '',
  from_name: '',
  use_tls: true,
  use_ssl: false,
  order_notification_enabled: true,
  cloudflare: {
    account_id: '',
    zone_id: '',
    api_token: '',
    has_api_token: false,
  },
  resend: {
    api_key: '',
    has_api_key: false,
  },
  verify_code: {
    expire_minutes: 10,
    send_interval_seconds: 60,
    max_attempts: 5,
    length: 6,
  },
  test_email: '',
})

const syncFromProps = () => {
  form.enabled = props.data.enabled
  form.transport = props.data.transport === 'resend' ? 'resend' : 'cloudflare'
  form.host = props.data.host
  form.port = props.data.port
  form.username = props.data.username
  form.password = props.data.password
  form.has_password = props.data.has_password
  form.from = props.data.from
  form.from_name = props.data.from_name
  form.use_tls = props.data.use_tls
  form.use_ssl = props.data.use_ssl
  form.order_notification_enabled = props.data.order_notification_enabled ?? true
  form.cloudflare.account_id = props.data.cloudflare?.account_id || ''
  form.cloudflare.zone_id = props.data.cloudflare?.zone_id || ''
  form.cloudflare.api_token = ''
  form.cloudflare.has_api_token = !!props.data.cloudflare?.has_api_token
  form.resend.api_key = ''
  form.resend.has_api_key = !!props.data.resend?.has_api_key
  form.verify_code.expire_minutes = props.data.verify_code.expire_minutes
  form.verify_code.send_interval_seconds = props.data.verify_code.send_interval_seconds
  form.verify_code.max_attempts = props.data.verify_code.max_attempts
  form.verify_code.length = props.data.verify_code.length
}

syncFromProps()

watch(() => props.data, () => {
  syncFromProps()
}, { deep: true })

const notifyErrorIfNeeded = (err: unknown, fallback: string) => {
  const known = err as Error & { __notified?: boolean }
  if (known?.__notified) return
  notifyError(known?.message || fallback)
}

const save = async () => {
  submitting.value = true
  try {
    const payload = {
      enabled: form.enabled,
      transport: form.transport,
      host: form.host,
      port: Number(form.port),
      username: form.username,
      password: form.password,
      from: form.from,
      from_name: form.from_name,
      use_tls: form.use_tls,
      use_ssl: form.use_ssl,
      order_notification_enabled: form.order_notification_enabled,
      cloudflare: {
        account_id: form.cloudflare.account_id,
        zone_id: form.cloudflare.zone_id,
        api_token: form.cloudflare.api_token,
      },
      resend: {
        api_key: form.resend.api_key,
      },
      verify_code: {
        expire_minutes: Number(form.verify_code.expire_minutes),
        send_interval_seconds: Number(form.verify_code.send_interval_seconds),
        max_attempts: Number(form.verify_code.max_attempts),
        length: Number(form.verify_code.length),
      },
    }
    const res = await adminAPI.updateSMTPSettings(payload)
    const data = res.data?.data as Record<string, unknown> | undefined
    form.password = ''
    form.has_password = !!data?.has_password || form.has_password
    const cloudflare = data?.cloudflare as Record<string, unknown> | undefined
    const resend = data?.resend as Record<string, unknown> | undefined
    form.cloudflare.api_token = ''
    form.cloudflare.has_api_token = !!cloudflare?.has_api_token || form.cloudflare.has_api_token
    form.resend.api_key = ''
    form.resend.has_api_key = !!resend?.has_api_key || form.resend.has_api_key
    notifySuccess(t('admin.settings.alerts.saveSuccess'))
    emit('saved')
  } catch (err) {
    notifyErrorIfNeeded(err, t('admin.settings.alerts.saveFailed'))
  } finally {
    submitting.value = false
  }
}

const testSMTPSettings = async () => {
  if (!form.test_email || form.test_email.trim() === '') {
    notifyError(t('admin.settings.smtp.testEmailRequired'))
    return
  }
  smtpTesting.value = true
  try {
    await adminAPI.testSMTPSettings({ to_email: form.test_email.trim() })
    notifySuccess(t('admin.settings.smtp.testSuccess'))
  } catch (err) {
    notifyErrorIfNeeded(err, t('admin.settings.smtp.testFailed'))
  } finally {
    smtpTesting.value = false
  }
}

const setCloudflareError = (err: unknown, fallback: string) => {
  const known = err as Error & { __notified?: boolean }
  cloudflareStatusMessage.value = known?.message || fallback
  notifyErrorIfNeeded(err, fallback)
}

const checkCloudflareEmailStatus = async () => {
  cloudflareChecking.value = true
  try {
    const res = await adminAPI.getCloudflareEmailStatus()
    cloudflareStatus.value = res.data?.data as Record<string, unknown>
    cloudflareStatusMessage.value = ''
    notifySuccess('Cloudflare 发信状态已刷新')
  } catch (err) {
    setCloudflareError(err, 'Cloudflare 发信状态检查失败')
  } finally {
    cloudflareChecking.value = false
  }
}

const onboardCloudflareEmailSending = async () => {
  cloudflareOnboarding.value = true
  try {
    const res = await adminAPI.onboardCloudflareEmailSending()
    cloudflareStatus.value = res.data?.data as Record<string, unknown>
    cloudflareStatusMessage.value = ''
    notifySuccess('Cloudflare 发信域名已提交')
  } catch (err) {
    setCloudflareError(err, 'Cloudflare 发信域名启用失败')
  } finally {
    cloudflareOnboarding.value = false
  }
}

defineExpose({ save, submitting, smtpTesting })
</script>

<template>
  <div class="space-y-6">
    <div class="rounded-xl border border-border bg-card">
      <div class="border-b border-border bg-muted/40 px-6 py-4">
        <h2 class="text-lg font-semibold">{{ t('admin.settings.smtp.title') }}</h2>
        <p class="mt-1 text-xs text-muted-foreground">{{ t('admin.settings.smtp.subtitle') }}</p>
      </div>

      <div class="space-y-6 p-6">
        <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
          <div class="flex items-center gap-3 rounded-lg border border-border bg-muted/20 px-4 py-3">
            <Switch id="smtp-enabled" v-model="form.enabled" />
            <Label for="smtp-enabled" class="text-sm font-medium">{{ t('admin.settings.smtp.enabled') }}</Label>
          </div>
          <div class="flex items-center gap-3 rounded-lg border border-border bg-muted/20 px-4 py-3">
            <Switch id="smtp-tls" v-model="form.use_tls" />
            <Label for="smtp-tls" class="text-sm font-medium">{{ t('admin.settings.smtp.useTLS') }}</Label>
            <Switch id="smtp-ssl" v-model="form.use_ssl" class="ml-4" />
            <Label for="smtp-ssl" class="text-sm font-medium">{{ t('admin.settings.smtp.useSSL') }}</Label>
          </div>
        </div>

        <div class="rounded-xl border border-border">
          <div class="border-b border-border bg-muted/30 px-4 py-3">
            <h3 class="text-sm font-semibold">邮件服务</h3>
            <p class="mt-1 text-xs text-muted-foreground">Cloudflare Worker 通过邮件 API 发信；请先配置并验证自己的发信域名。</p>
          </div>
          <div class="grid grid-cols-1 gap-4 p-4 md:grid-cols-2">
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">服务类型</label>
              <Select v-model="form.transport">
                <SelectTrigger>
                  <SelectValue placeholder="选择邮件服务" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="cloudflare">Cloudflare Email Service</SelectItem>
                  <SelectItem value="resend">Resend API</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.from') }}</label>
              <Input v-model="form.from" placeholder="no-reply@example.com" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.fromName') }}</label>
              <Input v-model="form.from_name" :placeholder="t('admin.settings.smtp.fromNamePlaceholder')" />
            </div>
            <template v-if="form.transport === 'cloudflare'">
              <div class="space-y-2">
                <label class="text-xs font-medium text-muted-foreground">Cloudflare Account ID</label>
                <Input v-model="form.cloudflare.account_id" placeholder="Cloudflare 账户 ID" />
              </div>
              <div class="space-y-2">
                <label class="text-xs font-medium text-muted-foreground">Cloudflare Zone ID</label>
                <Input v-model="form.cloudflare.zone_id" placeholder="留空则根据发件邮箱域名自动查询" />
              </div>
              <div class="space-y-2 md:col-span-2">
                <label class="text-xs font-medium text-muted-foreground">Cloudflare API Token</label>
                <Input v-model="form.cloudflare.api_token" type="password" placeholder="留空表示保持不变" />
                <p class="text-xs text-muted-foreground">
                  {{ form.cloudflare.has_api_token ? '当前已保存 API Token，留空将保持不变' : '需要 Email Service 发信权限的 API Token' }}
                </p>
              </div>
              <div class="space-y-3 rounded-lg border border-border bg-muted/20 p-4 md:col-span-2">
                <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                  <div>
                    <div class="flex items-center gap-2">
                      <span class="text-sm font-semibold">Cloudflare 发信域名</span>
                      <span
                        class="rounded-full px-2 py-0.5 text-xs"
                        :class="cloudflareEnabled ? 'bg-emerald-500/15 text-emerald-400' : 'bg-amber-500/15 text-amber-300'"
                      >
                        {{ cloudflareStatusLabel }}
                      </span>
                    </div>
                    <p class="mt-1 text-xs text-muted-foreground">
                      域名：{{ cloudflareDomain }} · Zone：{{ cloudflareZoneLabel }}
                    </p>
                  </div>
                  <div class="flex flex-wrap gap-2">
                    <Button variant="secondary" size="sm" :disabled="cloudflareChecking" @click="checkCloudflareEmailStatus">
                      {{ cloudflareChecking ? '检查中' : '检查状态' }}
                    </Button>
                    <Button size="sm" :disabled="cloudflareOnboarding" @click="onboardCloudflareEmailSending">
                      {{ cloudflareOnboarding ? '提交中' : '启用域名' }}
                    </Button>
                  </div>
                </div>
                <p v-if="cloudflareStatusMessage" class="text-xs text-destructive">
                  {{ cloudflareStatusMessage }}
                </p>
              </div>
            </template>
            <template v-else>
              <div class="space-y-2 md:col-span-2">
                <label class="text-xs font-medium text-muted-foreground">Resend API Key</label>
                <Input v-model="form.resend.api_key" type="password" placeholder="留空表示保持不变" />
                <p class="text-xs text-muted-foreground">
                  {{ form.resend.has_api_key ? '当前已保存 Resend API Key，留空将保持不变' : '需要先在 Resend 验证你的发信域名' }}
                </p>
              </div>
            </template>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
          <div class="flex items-center gap-3 rounded-lg border border-border bg-muted/20 px-4 py-3">
            <Switch id="smtp-order-notification" v-model="form.order_notification_enabled" :disabled="!form.enabled" />
            <div>
              <Label for="smtp-order-notification" class="text-sm font-medium">{{ t('admin.settings.smtp.orderNotificationEnabled') }}</Label>
              <p class="text-xs text-muted-foreground">{{ t('admin.settings.smtp.orderNotificationHint') }}</p>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.host') }}</label>
            <Input v-model="form.host" :placeholder="t('admin.settings.smtp.hostPlaceholder')" />
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.port') }}</label>
            <Input v-model.number="form.port" type="number" :placeholder="t('admin.settings.smtp.portPlaceholder')" />
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.username') }}</label>
            <Input v-model="form.username" :placeholder="t('admin.settings.smtp.usernamePlaceholder')" />
          </div>
          <div class="space-y-2">
            <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.password') }}</label>
            <Input v-model="form.password" type="password" :placeholder="t('admin.settings.smtp.passwordPlaceholder')" />
            <p class="text-xs text-muted-foreground">
              {{ form.has_password ? t('admin.settings.smtp.passwordHintKeep') : t('admin.settings.smtp.passwordHintEmpty') }}
            </p>
          </div>
        </div>

        <div class="rounded-xl border border-border">
          <div class="border-b border-border bg-muted/30 px-4 py-3">
            <h3 class="text-sm font-semibold">{{ t('admin.settings.smtp.verifyCode.title') }}</h3>
          </div>
          <div class="grid grid-cols-1 gap-4 p-4 md:grid-cols-4">
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.verifyCode.expireMinutes') }}</label>
              <Input v-model.number="form.verify_code.expire_minutes" type="number" min="1" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.verifyCode.sendIntervalSeconds') }}</label>
              <Input v-model.number="form.verify_code.send_interval_seconds" type="number" min="1" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.verifyCode.maxAttempts') }}</label>
              <Input v-model.number="form.verify_code.max_attempts" type="number" min="1" />
            </div>
            <div class="space-y-2">
              <label class="text-xs font-medium text-muted-foreground">{{ t('admin.settings.smtp.verifyCode.length') }}</label>
              <Input v-model.number="form.verify_code.length" type="number" min="4" max="10" />
            </div>
          </div>
        </div>

        <div class="rounded-xl border border-border bg-muted/20 p-4">
          <h3 class="text-sm font-semibold">{{ t('admin.settings.smtp.testTitle') }}</h3>
          <p class="mt-1 text-xs text-muted-foreground">{{ t('admin.settings.smtp.testSubtitle') }}</p>
          <div class="mt-3 flex flex-col gap-3 md:flex-row">
            <Input v-model="form.test_email" :placeholder="t('admin.settings.smtp.testEmailPlaceholder')" />
            <Button variant="secondary" :disabled="smtpTesting" @click="testSMTPSettings">
              {{ smtpTesting ? t('admin.settings.smtp.testing') : t('admin.settings.smtp.testButton') }}
            </Button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

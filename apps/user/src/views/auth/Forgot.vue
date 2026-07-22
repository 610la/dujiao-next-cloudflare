<template>
  <div class="relative flex min-h-screen items-center justify-center bg-background text-foreground theme-auth-page px-4 py-16 sm:px-6">
    <div class="relative z-10 w-full max-w-lg">
      <div class="mb-4 flex items-center justify-between px-1">
        <Button as-child variant="ghost" size="sm" class="rounded-full gap-1 text-muted-foreground">
          <router-link to="/">
            <ArrowLeft class="h-4 w-4" />
            {{ t('auth.login.backHome') }}
          </router-link>
        </Button>
        <Badge variant="neutral" size="sm" class="rounded-full">
          {{ t('auth.forgot.title') }}
        </Badge>
      </div>

      <Card class="rounded-3xl p-7 shadow-lg backdrop-blur-sm sm:p-9">
        <div class="mb-8 text-center">
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-primary">{{ brandSiteName }}</p>
          <h1 class="mt-3 text-3xl font-black text-foreground">{{ t('auth.forgot.title') }}</h1>
          <p class="mt-2 text-sm text-muted-foreground">{{ t('auth.forgot.subtitle') }}</p>
        </div>

        <Alert v-if="!emailVerificationEnabled" variant="destructive" class="text-center">
          <AlertDescription class="block">
            <p class="text-sm font-medium">{{ t('auth.forgot.disabled') }}</p>
            <router-link to="/auth/login" class="mt-3 inline-block text-muted-foreground transition-colors hover:text-foreground text-sm">
              {{ t('auth.forgot.backLogin') }}
            </router-link>
          </AlertDescription>
        </Alert>

        <form v-else class="space-y-6" @submit.prevent="handleReset">
          <div>
            <label class="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
              <Mail class="h-3.5 w-3.5 opacity-60" />
              {{ t('auth.forgot.emailLabel') }}
            </label>
            <Input
              v-model="email"
              type="email"
              required
              class="h-11"
              :placeholder="t('auth.forgot.emailPlaceholder')"
            />
          </div>

          <div v-if="sendCodeCaptchaEnabled">
            <label class="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
              <ShieldCheck class="h-3.5 w-3.5 opacity-60" />
              {{ t('auth.common.captchaLabel') }}
            </label>
            <ImageCaptcha
              v-if="captchaProvider === 'image'"
              ref="imageCaptchaRef"
              v-model="captchaPayload"
              :disabled="sending || countdown > 0"
              @config-stale="handleCaptchaConfigStale"
            />
            <TurnstileCaptcha
              v-else-if="captchaProvider === 'turnstile'"
              ref="turnstileRef"
              v-model="turnstileToken"
              :site-key="turnstileSiteKey"
            />
          </div>

          <div>
            <label class="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
              <ShieldCheck class="h-3.5 w-3.5 opacity-60" />
              {{ t('auth.forgot.codeLabel') }}
            </label>
            <div class="flex flex-col gap-2 sm:flex-row">
              <Input
                v-model="code"
                type="text"
                required
                class="h-11 min-w-0 flex-1"
                :placeholder="t('auth.forgot.codePlaceholder')"
              />
              <Button
                type="button"
                variant="secondary"
                class="h-11 whitespace-nowrap"
                @click="handleSendCode"
                :disabled="sending || countdown > 0"
              >
                {{ countdown > 0 ? t('auth.common.countdown', { seconds: countdown }) : t('auth.common.sendCode') }}
              </Button>
            </div>
          </div>

          <div>
            <label class="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
              <KeyRound class="h-3.5 w-3.5 opacity-60" />
              {{ t('auth.forgot.newPasswordLabel') }}
            </label>
            <Input
              v-model="newPassword"
              type="password"
              required
              class="h-11"
              :placeholder="t('auth.forgot.newPasswordPlaceholder')"
            />
          </div>

          <Alert v-if="error" variant="destructive" class="text-center">
            <AlertDescription>{{ error }}</AlertDescription>
          </Alert>

          <Button type="submit" :disabled="userAuthStore.loading" class="h-11 w-full font-bold">
            <RotateCw v-if="!userAuthStore.loading" class="h-4 w-4" />
            {{ userAuthStore.loading ? t('auth.forgot.submitting') : t('auth.forgot.submit') }}
          </Button>
        </form>
      </Card>

      <div class="mt-4 text-center">
        <router-link
          to="/auth/login"
          class="text-muted-foreground transition-colors hover:text-foreground text-sm"
        >
          {{ t('auth.forgot.backLogin') }}
        </router-link>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import ImageCaptcha from '../../components/captcha/ImageCaptcha.vue'
import TurnstileCaptcha from '../../components/captcha/TurnstileCaptcha.vue'
import { ArrowLeft, Mail, ShieldCheck, KeyRound, RotateCw } from 'lucide-vue-next'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { useForgot } from '../../composables/useForgot'

const { t } = useI18n()

const {
  userAuthStore, brandSiteName, emailVerificationEnabled,
  email, code, newPassword, error, sending, countdown,
  captchaPayload, turnstileToken, imageCaptchaRef, turnstileRef,
  captchaProvider, sendCodeCaptchaEnabled, turnstileSiteKey,
  handleCaptchaConfigStale, handleSendCode, handleReset,
} = useForgot()

// imageCaptchaRef / turnstileRef 仅通过字符串模板 ref 绑定，显式标记避免 noUnusedLocals 误报。
void imageCaptchaRef
void turnstileRef
</script>

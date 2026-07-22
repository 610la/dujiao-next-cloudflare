<script setup lang="ts">
import { onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useTelegramBotSettings } from '@/composables/useTelegramBotSettings'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { ArrowDown, ArrowUp, Loader2, Plus, Save, Trash2 } from 'lucide-vue-next'

const { t } = useI18n()
const {
  addHelpItem,
  currentLang,
  fetchConfig,
  form,
  languages,
  loading,
  moveHelpItem,
  removeHelpItem,
  saveConfig,
  saving,
} = useTelegramBotSettings()

onMounted(() => {
  fetchConfig()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
      <div>
        <h2 class="text-2xl font-bold tracking-tight">{{ t('telegramBot.settings.helpTitle') }}</h2>
        <p class="text-muted-foreground">{{ t('telegramBot.settings.helpDesc') }}</p>
      </div>
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div class="flex max-w-full overflow-x-auto rounded-lg border border-border bg-card p-1">
          <button
            v-for="lang in languages"
            :key="lang.code"
            class="shrink-0 rounded-md px-3 py-1.5 text-xs font-medium transition-colors"
            :class="currentLang === lang.code ? 'bg-secondary text-foreground' : 'text-muted-foreground hover:text-foreground'"
            @click="currentLang = lang.code"
          >
            {{ lang.name }}
          </button>
        </div>
        <Button class="w-full sm:w-auto" :disabled="saving || loading" @click="saveConfig">
          <Loader2 v-if="saving" class="mr-2 h-4 w-4 animate-spin" />
          <Save v-else class="mr-2 h-4 w-4" />
          {{ t('telegramBot.settings.save') }}
        </Button>
      </div>
    </div>

    <Card>
      <CardHeader>
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <CardTitle>{{ t('telegramBot.settings.helpTitle') }}</CardTitle>
            <CardDescription>{{ t('telegramBot.settings.helpDesc') }}</CardDescription>
          </div>
          <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
            <span class="rounded bg-muted px-2 py-1 text-xs text-muted-foreground">{{ currentLang }}</span>
            <Button type="button" size="sm" variant="outline" class="w-full sm:w-auto" @click="addHelpItem">
              <Plus class="mr-1 h-4 w-4" />
              {{ t('telegramBot.settings.helpAdd') }}
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent class="space-y-4">
        <div class="flex flex-col gap-3 rounded-lg border border-border bg-muted/10 px-4 py-3 sm:flex-row sm:items-center">
          <Switch id="help-enabled" v-model="form.help.enabled" />
          <Label for="help-enabled">{{ t('telegramBot.settings.helpEnabled') }}</Label>
        </div>
        <div class="space-y-2">
          <Label>{{ t('telegramBot.settings.helpCenterTitle') }}</Label>
          <Input v-model="form.help.title[currentLang]" :placeholder="t('telegramBot.settings.helpCenterTitlePlaceholder')" />
        </div>
        <div class="space-y-2">
          <Label>{{ t('telegramBot.settings.helpIntro') }}</Label>
          <Textarea v-model="form.help.intro[currentLang]" :placeholder="t('telegramBot.settings.helpIntroPlaceholder')" rows="2" />
        </div>
        <div class="space-y-2">
          <Label>{{ t('telegramBot.settings.helpCenterHint') }}</Label>
          <Textarea v-model="form.help.center_hint[currentLang]" :placeholder="t('telegramBot.settings.helpCenterHintPlaceholder')" rows="2" />
        </div>
        <div class="space-y-2">
          <Label>{{ t('telegramBot.settings.helpSupportHint') }}</Label>
          <Textarea v-model="form.help.support_hint[currentLang]" :placeholder="t('telegramBot.settings.helpSupportHintPlaceholder')" rows="2" />
        </div>
        <div v-if="form.help.items.length === 0" class="rounded-lg border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
          {{ t('telegramBot.settings.helpEmpty') }}
        </div>
        <div
          v-for="(item, index) in form.help.items"
          :key="`help-${index}`"
          class="space-y-3 rounded-lg border border-border p-4"
        >
          <div class="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
            <Switch :id="`help-enabled-${index}`" v-model="item.enabled" />
            <Input
              v-model="item.key"
              :placeholder="t('telegramBot.settings.helpKeyPlaceholder')"
              class="w-full min-w-[120px] flex-1"
            />
            <Button
              type="button"
              size="icon"
              variant="ghost"
              :disabled="index === 0"
              @click="moveHelpItem(index, 'up')"
            >
              <ArrowUp class="h-4 w-4" />
            </Button>
            <Button
              type="button"
              size="icon"
              variant="ghost"
              :disabled="index === form.help.items.length - 1"
              @click="moveHelpItem(index, 'down')"
            >
              <ArrowDown class="h-4 w-4" />
            </Button>
            <Button type="button" size="icon" variant="ghost" @click="removeHelpItem(index)">
              <Trash2 class="h-4 w-4 text-destructive" />
            </Button>
          </div>
          <div class="space-y-1">
            <Label>{{ t('telegramBot.settings.helpSummary') }}</Label>
            <Input v-model="item.summary[currentLang]" :placeholder="t('telegramBot.settings.helpSummaryPlaceholder')" />
          </div>
          <div class="space-y-1">
            <Label>{{ t('telegramBot.settings.helpItemTitle') }}</Label>
            <Input v-model="item.title[currentLang]" :placeholder="t('telegramBot.settings.helpItemTitlePlaceholder')" />
          </div>
          <div class="space-y-1">
            <Label>{{ t('telegramBot.settings.helpContent') }}</Label>
            <Textarea v-model="item.content[currentLang]" :placeholder="t('telegramBot.settings.helpContentPlaceholder')" rows="4" />
          </div>
          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            <div class="space-y-1">
              <Label>{{ t('telegramBot.settings.helpOrder') }}</Label>
              <Input v-model.number="item.order" type="number" />
            </div>
            <div class="flex items-center gap-2 pt-6">
              <Switch :id="`help-support-link-${index}`" v-model="item.show_support_link" />
              <Label :for="`help-support-link-${index}`">{{ t('telegramBot.settings.helpShowSupportLink') }}</Label>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>

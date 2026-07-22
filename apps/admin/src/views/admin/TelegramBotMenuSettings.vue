<script setup lang="ts">
import { onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useTelegramBotSettings } from '@/composables/useTelegramBotSettings'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { ArrowDown, ArrowUp, Loader2, Plus, Save, Trash2 } from 'lucide-vue-next'

const { t } = useI18n()
const {
  addMenuItem,
  currentLang,
  fetchConfig,
  form,
  getMenuActionValueHint,
  getMenuActionValuePlaceholder,
  languages,
  loading,
  menuActionTypes,
  moveMenuItem,
  removeMenuItem,
  saveConfig,
  saving,
} = useTelegramBotSettings()

onMounted(() => {
  fetchConfig()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2 class="text-2xl font-bold tracking-tight">{{ t('telegramBot.settings.menuTitle') }}</h2>
        <p class="text-muted-foreground">{{ t('telegramBot.settings.menuDesc') }}</p>
      </div>
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div class="overflow-x-auto">
          <div class="flex w-max rounded-lg border border-border bg-card p-1">
            <button
              v-for="lang in languages"
              :key="lang.code"
              class="shrink-0 whitespace-nowrap rounded-md px-3 py-1.5 text-xs font-medium transition-colors"
              :class="currentLang === lang.code ? 'bg-secondary text-foreground' : 'text-muted-foreground hover:text-foreground'"
              @click="currentLang = lang.code"
            >
              {{ lang.name }}
            </button>
          </div>
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
            <CardTitle>{{ t('telegramBot.settings.menuTitle') }}</CardTitle>
            <CardDescription>{{ t('telegramBot.settings.menuDesc') }}</CardDescription>
          </div>
          <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
            <span class="w-fit rounded bg-muted px-2 py-1 text-xs text-muted-foreground">{{ currentLang }}</span>
            <Button class="w-full sm:w-auto" type="button" size="sm" variant="outline" @click="addMenuItem">
              <Plus class="mr-1 h-4 w-4" />
              {{ t('telegramBot.settings.menuAdd') }}
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent class="space-y-3">
        <div v-if="form.menu.items.length === 0" class="rounded-lg border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
          {{ t('telegramBot.settings.menuEmpty') }}
        </div>
        <div
          v-for="(item, index) in form.menu.items"
          :key="index"
          class="space-y-3 rounded-lg border border-border p-4"
        >
          <div class="space-y-3">
            <div class="flex items-center gap-2">
              <Switch :id="`menu-enabled-${index}`" v-model="item.enabled" />
              <Input
                v-model="item.key"
                :placeholder="t('telegramBot.settings.menuKeyPlaceholder')"
                class="min-w-0 w-full flex-1"
              />
            </div>
            <div class="flex flex-wrap gap-2">
              <Button
                class="flex-1 sm:flex-none"
                type="button"
                size="sm"
                variant="ghost"
                :disabled="index === 0"
                @click="moveMenuItem(index, 'up')"
              >
                <ArrowUp class="mr-1 h-4 w-4" />
                {{ t('telegramBot.settings.menuMoveUp') }}
              </Button>
              <Button
                class="flex-1 sm:flex-none"
                type="button"
                size="sm"
                variant="ghost"
                :disabled="index === form.menu.items.length - 1"
                @click="moveMenuItem(index, 'down')"
              >
                <ArrowDown class="mr-1 h-4 w-4" />
                {{ t('telegramBot.settings.menuMoveDown') }}
              </Button>
              <Button class="w-full sm:w-auto" type="button" size="sm" variant="ghost" @click="removeMenuItem(index)">
                <Trash2 class="mr-1 h-4 w-4 text-destructive" />
                {{ t('admin.common.delete') }}
              </Button>
            </div>
          </div>
          <div class="space-y-1">
            <Label>{{ t('telegramBot.settings.menuLabel') }}</Label>
            <Input v-model="item.label[currentLang]" :placeholder="t('telegramBot.settings.menuLabelPlaceholder')" />
          </div>
          <div class="grid grid-cols-1 gap-3 md:grid-cols-3">
            <div class="space-y-1">
              <Label>{{ t('telegramBot.settings.menuActionType') }}</Label>
              <Select v-model="item.action.type">
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem v-for="actionType in menuActionTypes" :key="actionType" :value="actionType">
                    {{ t(`telegramBot.settings.menuActionType_${actionType}`) }}
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div class="space-y-1">
              <Label>{{ t('telegramBot.settings.menuActionValue') }}</Label>
              <Input v-model="item.action.value" :placeholder="getMenuActionValuePlaceholder(item.action.type)" />
              <p class="text-xs text-muted-foreground">
                {{ getMenuActionValueHint(item.action.type) }}
              </p>
            </div>
            <div class="space-y-1">
              <Label>{{ t('telegramBot.settings.menuOrder') }}</Label>
              <Input v-model.number="item.order" type="number" />
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>

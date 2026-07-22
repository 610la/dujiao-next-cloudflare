<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { notifySuccess, notifyError } from '@/utils/notify'
import { Plus, Copy, Loader2, RotateCcw, Trash2, Pencil } from 'lucide-vue-next'

const { t } = useI18n()

interface ChannelClient {
  id: number
  name: string
  channel_type: string
  channel_key: string
  channel_secret: string
  bot_token: string
  bot_token_set: boolean
  callback_url?: string
  status: number
  description: string
  last_used_at: string | null
  created_at: string
}

const loading = ref(false)
const clients = ref<ChannelClient[]>([])
const showCreateDialog = ref(false)
const creating = ref(false)

// Edit dialog
const showEditDialog = ref(false)
const editing = ref(false)
const editingClient = ref<ChannelClient | null>(null)
const editForm = ref({
  name: '',
  description: '',
  bot_token: '',
  callback_url: '',
})

// Confirm dialogs
const confirmAction = ref<'reset' | 'delete' | null>(null)
const confirmTargetClient = ref<ChannelClient | null>(null)
const confirmLoading = ref(false)

const createForm = ref({
  name: '',
  channel_type: 'telegram_bot',
  description: '',
  bot_token: '',
  callback_url: '',
})

const fetchClients = async () => {
  loading.value = true
  try {
    const res = await adminAPI.getChannelClients()
    const data = res.data?.data
    clients.value = Array.isArray(data) ? data : []
  } catch {
    clients.value = []
  } finally {
    loading.value = false
  }
}

const handleCreate = async () => {
  creating.value = true
  try {
    await adminAPI.createChannelClient(createForm.value)
    notifySuccess(t('telegramBot.channelClients.createSuccess'))
    showCreateDialog.value = false
    createForm.value = { name: '', channel_type: 'telegram_bot', description: '', bot_token: '', callback_url: '' }
    fetchClients()
  } catch {
    notifyError(t('telegramBot.channelClients.createFailed'))
  } finally {
    creating.value = false
  }
}

const openEditDialog = (client: ChannelClient) => {
  editingClient.value = client
  editForm.value = {
    name: client.name,
    description: client.description || '',
    bot_token: '',
    callback_url: client.callback_url || '',
  }
  showEditDialog.value = true
}

const handleEdit = async () => {
  if (!editingClient.value) return
  editing.value = true
  try {
    const data: { name?: string; description?: string; bot_token?: string; callback_url?: string } = {
      name: editForm.value.name,
      description: editForm.value.description,
      callback_url: editForm.value.callback_url,
    }
    // 只有用户输入了 bot_token 才发送（空表示不修改）
    if (editForm.value.bot_token !== '') {
      data.bot_token = editForm.value.bot_token
    }
    await adminAPI.updateChannelClient(editingClient.value.id, data)
    notifySuccess(t('telegramBot.channelClients.editSuccess'))
    showEditDialog.value = false
    fetchClients()
  } catch {
    notifyError(t('telegramBot.channelClients.editFailed'))
  } finally {
    editing.value = false
  }
}

const handleToggleStatus = async (client: ChannelClient) => {
  const newStatus = client.status === 1 ? 0 : 1
  try {
    await adminAPI.updateChannelClientStatus(client.id, { status: newStatus })
    notifySuccess(t('telegramBot.channelClients.statusUpdated'))
    fetchClients()
  } catch {
    notifyError(t('telegramBot.channelClients.statusUpdateFailed'))
  }
}

const openConfirm = (action: 'reset' | 'delete', client: ChannelClient) => {
  confirmAction.value = action
  confirmTargetClient.value = client
}

const closeConfirm = () => {
  confirmAction.value = null
  confirmTargetClient.value = null
}

const handleConfirmAction = async () => {
  if (!confirmTargetClient.value) return
  confirmLoading.value = true
  try {
    if (confirmAction.value === 'reset') {
      await adminAPI.resetChannelClientSecret(confirmTargetClient.value.id)
      notifySuccess(t('telegramBot.channelClients.resetSecretSuccess'))
    } else if (confirmAction.value === 'delete') {
      await adminAPI.deleteChannelClient(confirmTargetClient.value.id)
      notifySuccess(t('telegramBot.channelClients.deleteSuccess'))
    }
    closeConfirm()
    fetchClients()
  } catch {
    if (confirmAction.value === 'reset') {
      notifyError(t('telegramBot.channelClients.resetSecretFailed'))
    } else {
      notifyError(t('telegramBot.channelClients.deleteFailed'))
    }
  } finally {
    confirmLoading.value = false
  }
}

const copyToClipboard = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text)
    notifySuccess(t('telegramBot.channelClients.copied'))
  } catch {
    // fallback
  }
}

onMounted(() => {
  fetchClients()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2 class="text-2xl font-bold tracking-tight">{{ t('telegramBot.channelClients.title') }}</h2>
        <p class="text-muted-foreground">{{ t('telegramBot.channelClients.subtitle') }}</p>
      </div>
      <Button size="sm" class="w-full sm:w-auto" @click="showCreateDialog = true">
        <Plus class="h-4 w-4 mr-2" />
        {{ t('telegramBot.channelClients.create') }}
      </Button>
    </div>

    <Card>
      <CardContent class="overflow-x-auto p-0">
        <Table class="min-w-[1020px]">
          <TableHeader>
            <TableRow>
              <TableHead>ID</TableHead>
              <TableHead class="min-w-[160px]">{{ t('telegramBot.channelClients.name') }}</TableHead>
              <TableHead class="min-w-[160px]">{{ t('telegramBot.channelClients.channelKey') }}</TableHead>
              <TableHead class="min-w-[160px]">{{ t('telegramBot.channelClients.channelSecret') }}</TableHead>
              <TableHead class="min-w-[100px]">{{ t('telegramBot.channelClients.botToken') }}</TableHead>
              <TableHead class="min-w-[180px]">{{ t('telegramBot.channelClients.callbackUrl') }}</TableHead>
              <TableHead class="min-w-[90px]">{{ t('telegramBot.channelClients.statusLabel') }}</TableHead>
              <TableHead class="min-w-[160px]">{{ t('telegramBot.channelClients.actions') }}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-if="loading">
              <TableCell :colspan="8" class="text-center py-8 text-muted-foreground">
                <Loader2 class="h-5 w-5 animate-spin mx-auto" />
              </TableCell>
            </TableRow>
            <TableRow v-else-if="clients.length === 0">
              <TableCell :colspan="8" class="text-center py-8 text-muted-foreground">
                {{ t('telegramBot.channelClients.empty') }}
              </TableCell>
            </TableRow>
            <TableRow v-for="client in clients" :key="client.id">
              <TableCell>{{ client.id }}</TableCell>
              <TableCell class="min-w-[160px]">
                <div>
                  <div class="break-words font-medium">{{ client.name }}</div>
                  <div v-if="client.description" class="break-words text-xs text-muted-foreground">{{ client.description }}</div>
                </div>
              </TableCell>
              <TableCell class="min-w-[160px]">
                <div class="flex items-center gap-1">
                  <code class="block max-w-[180px] break-all rounded bg-muted px-1.5 py-0.5 text-xs">{{ client.channel_key }}</code>
                  <Button variant="ghost" size="sm" class="h-6 w-6 p-0 shrink-0" @click="copyToClipboard(client.channel_key)">
                    <Copy class="h-3 w-3" />
                  </Button>
                </div>
              </TableCell>
              <TableCell class="min-w-[160px]">
                <div class="flex items-center gap-1">
                  <code class="block max-w-[180px] break-all rounded bg-muted px-1.5 py-0.5 text-xs">{{ client.channel_secret }}</code>
                  <Button variant="ghost" size="sm" class="h-6 w-6 p-0 shrink-0" @click="copyToClipboard(client.channel_secret)">
                    <Copy class="h-3 w-3" />
                  </Button>
                </div>
              </TableCell>
              <TableCell class="min-w-[100px]">
                <Badge v-if="client.bot_token_set" variant="default">
                  {{ t('telegramBot.channelClients.botTokenSet') }}
                </Badge>
                <span v-else class="text-xs text-muted-foreground">{{ t('telegramBot.channelClients.botTokenNotSet') }}</span>
              </TableCell>
              <TableCell class="min-w-[180px]">
                <div v-if="client.callback_url" class="flex items-center gap-1">
                  <code class="block max-w-[220px] break-all rounded bg-muted px-1.5 py-0.5 text-xs">{{ client.callback_url }}</code>
                  <Button variant="ghost" size="sm" class="h-6 w-6 p-0 shrink-0" @click="copyToClipboard(client.callback_url)">
                    <Copy class="h-3 w-3" />
                  </Button>
                </div>
                <span v-else class="text-xs text-muted-foreground">{{ t('telegramBot.channelClients.callbackUrlNotSet') }}</span>
              </TableCell>
              <TableCell class="min-w-[90px]">
                <Badge :variant="client.status === 1 ? 'default' : 'secondary'">
                  {{ client.status === 1 ? t('telegramBot.channelClients.active') : t('telegramBot.channelClients.disabled') }}
                </Badge>
              </TableCell>
              <TableCell class="min-w-[160px]">
                <div class="flex flex-wrap items-center gap-1">
                  <Button variant="outline" size="sm" @click="openEditDialog(client)" :title="t('telegramBot.channelClients.edit')">
                    <Pencil class="h-3.5 w-3.5" />
                  </Button>
                  <Button variant="outline" size="sm" @click="handleToggleStatus(client)">
                    {{ client.status === 1 ? t('telegramBot.channelClients.disable') : t('telegramBot.channelClients.enable') }}
                  </Button>
                  <Button variant="outline" size="sm" @click="openConfirm('reset', client)" :title="t('telegramBot.channelClients.resetSecret')">
                    <RotateCcw class="h-3.5 w-3.5" />
                  </Button>
                  <Button variant="outline" size="sm" class="text-destructive hover:text-destructive" @click="openConfirm('delete', client)" :title="t('telegramBot.channelClients.delete')">
                    <Trash2 class="h-3.5 w-3.5" />
                  </Button>
                </div>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>

    <!-- Create Dialog -->
    <Dialog v-model:open="showCreateDialog">
      <DialogContent class="w-[calc(100vw-1rem)] max-w-lg p-4 sm:p-6">
        <DialogHeader>
          <DialogTitle>{{ t('telegramBot.channelClients.createTitle') }}</DialogTitle>
          <DialogDescription>{{ t('telegramBot.channelClients.createDesc') }}</DialogDescription>
        </DialogHeader>
        <div class="space-y-4">
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.name') }}</Label>
            <Input v-model="createForm.name" :placeholder="t('telegramBot.channelClients.namePlaceholder')" />
          </div>
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.botToken') }}</Label>
            <Input v-model="createForm.bot_token" :placeholder="t('telegramBot.channelClients.botTokenPlaceholder')" />
            <p class="text-xs text-muted-foreground">{{ t('telegramBot.channelClients.botTokenHint') }}</p>
          </div>
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.callbackUrl') }}</Label>
            <Input v-model="createForm.callback_url" :placeholder="t('telegramBot.channelClients.callbackUrlPlaceholder')" />
            <p class="text-xs text-muted-foreground">{{ t('telegramBot.channelClients.callbackUrlHint') }}</p>
          </div>
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.description') }}</Label>
            <Textarea v-model="createForm.description" :placeholder="t('telegramBot.channelClients.descriptionPlaceholder')" rows="2" />
          </div>
        </div>
        <DialogFooter class="flex-col-reverse sm:flex-row">
          <Button class="w-full sm:w-auto" variant="outline" @click="showCreateDialog = false">{{ t('telegramBot.channelClients.cancel') }}</Button>
          <Button class="w-full sm:w-auto" :disabled="creating || !createForm.name" @click="handleCreate">
            <Loader2 v-if="creating" class="h-4 w-4 mr-2 animate-spin" />
            {{ t('telegramBot.channelClients.create') }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Edit Dialog -->
    <Dialog v-model:open="showEditDialog">
      <DialogContent class="w-[calc(100vw-1rem)] max-w-lg p-4 sm:p-6">
        <DialogHeader>
          <DialogTitle>{{ t('telegramBot.channelClients.editTitle') }}</DialogTitle>
          <DialogDescription>{{ t('telegramBot.channelClients.editDesc') }}</DialogDescription>
        </DialogHeader>
        <div class="space-y-4">
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.name') }}</Label>
            <Input v-model="editForm.name" :placeholder="t('telegramBot.channelClients.namePlaceholder')" />
          </div>
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.botToken') }}</Label>
            <Input v-model="editForm.bot_token" :placeholder="t('telegramBot.channelClients.botTokenEditPlaceholder')" />
            <p class="text-xs text-muted-foreground">
              <template v-if="editingClient?.bot_token_set">
                {{ t('telegramBot.channelClients.botTokenCurrentSet') }}
              </template>
              <template v-else>
                {{ t('telegramBot.channelClients.botTokenCurrentNotSet') }}
              </template>
            </p>
          </div>
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.callbackUrl') }}</Label>
            <Input v-model="editForm.callback_url" :placeholder="t('telegramBot.channelClients.callbackUrlPlaceholder')" />
            <p class="text-xs text-muted-foreground">{{ t('telegramBot.channelClients.callbackUrlHint') }}</p>
          </div>
          <div class="space-y-2">
            <Label>{{ t('telegramBot.channelClients.description') }}</Label>
            <Textarea v-model="editForm.description" :placeholder="t('telegramBot.channelClients.descriptionPlaceholder')" rows="2" />
          </div>
        </div>
        <DialogFooter class="flex-col-reverse sm:flex-row">
          <Button class="w-full sm:w-auto" variant="outline" @click="showEditDialog = false">{{ t('telegramBot.channelClients.cancel') }}</Button>
          <Button class="w-full sm:w-auto" :disabled="editing || !editForm.name" @click="handleEdit">
            <Loader2 v-if="editing" class="h-4 w-4 mr-2 animate-spin" />
            {{ t('telegramBot.channelClients.save') }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Confirm Dialog (Reset Secret / Delete) -->
    <Dialog :open="!!confirmAction" @update:open="(v: boolean) => { if (!v) closeConfirm() }">
      <DialogContent class="w-[calc(100vw-1rem)] max-w-md p-4 sm:p-6">
        <DialogHeader>
          <DialogTitle>
            {{ confirmAction === 'reset' ? t('telegramBot.channelClients.resetSecretTitle') : t('telegramBot.channelClients.deleteTitle') }}
          </DialogTitle>
          <DialogDescription>
            {{ confirmAction === 'reset' ? t('telegramBot.channelClients.resetSecretDesc') : t('telegramBot.channelClients.deleteDesc') }}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter class="flex-col-reverse sm:flex-row">
          <Button class="w-full sm:w-auto" variant="outline" @click="closeConfirm">{{ t('telegramBot.channelClients.cancel') }}</Button>
          <Button class="w-full sm:w-auto" :variant="confirmAction === 'delete' ? 'destructive' : 'default'" :disabled="confirmLoading" @click="handleConfirmAction">
            <Loader2 v-if="confirmLoading" class="h-4 w-4 mr-2 animate-spin" />
            {{ t('telegramBot.channelClients.confirm') }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>

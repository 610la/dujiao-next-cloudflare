<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { adminAPI } from '@/api/admin'
import type { AdminOrder } from '@/api/types'
import IdCell from '@/components/IdCell.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogScrollContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Card, CardContent } from '@/components/ui/card'
import { Textarea } from '@/components/ui/textarea'

const props = defineProps<{
  modelValue: boolean
  order: AdminOrder | null
  siteCurrency: string
  parentId?: number | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'success', parentId?: number | null): void
}>()

const { t } = useI18n()

const detailLoading = ref(false)
const detailError = ref('')
const selectedOrder = ref<AdminOrder | null>(null)
const fulfillmentSubmitting = ref(false)
const fulfillmentError = ref('')
const fulfillmentSuccess = ref('')
const fulfillmentForm = reactive({
  note: '',
  entries: [] as Array<{ key: string; value: string }>,
})

const createEmptyDeliveryEntry = () => ({ key: '', value: '' })

const addDeliveryEntry = () => {
  fulfillmentForm.entries.push(createEmptyDeliveryEntry())
}

const removeDeliveryEntry = (index: number) => {
  fulfillmentForm.entries.splice(index, 1)
}

const buildDeliveryDataPayload = () => {
  const note = String(fulfillmentForm.note || '').trim()
  const entries = fulfillmentForm.entries
    .map((item) => ({
      key: String(item.key || '').trim(),
      value: String(item.value || '').trim(),
    }))
    .filter((item) => item.key || item.value)

  const payload: Record<string, unknown> = {}
  if (note) {
    payload.note = note
  }
  if (entries.length) {
    payload.entries = entries
  }
  return payload
}

const hasFulfillmentSubmitData = () => {
  const data = buildDeliveryDataPayload()
  return Object.keys(data).length > 0
}

const resetFulfillmentForm = () => {
  fulfillmentForm.note = ''
  fulfillmentForm.entries = [createEmptyDeliveryEntry()]
  fulfillmentError.value = ''
  fulfillmentSuccess.value = ''
}

const fetchOrderDetail = async (orderId: number) => {
  detailLoading.value = true
  detailError.value = ''
  selectedOrder.value = null
  try {
    const response = await adminAPI.getOrder(orderId)
    selectedOrder.value = response.data.data
  } catch (err: any) {
    detailError.value = err?.message || t('admin.orders.detailFetchFailed')
  } finally {
    detailLoading.value = false
  }
}

const submitFulfillment = async () => {
  if (!selectedOrder.value) return
  fulfillmentError.value = ''
  fulfillmentSuccess.value = ''
  if (!hasFulfillmentSubmitData()) {
    fulfillmentError.value = t('admin.orders.fulfillmentSubmitRequired')
    return
  }
  fulfillmentSubmitting.value = true
  try {
    await adminAPI.createFulfillment({
      order_id: Number(selectedOrder.value.id),
      delivery_data: buildDeliveryDataPayload(),
    })
    fulfillmentSuccess.value = t('admin.orders.fulfillmentSuccess')
    emit('success', props.parentId)
  } catch (err: any) {
    fulfillmentError.value = err?.message || t('admin.orders.fulfillmentFailed')
  } finally {
    fulfillmentSubmitting.value = false
  }
}

const handleClose = () => {
  emit('update:modelValue', false)
  selectedOrder.value = null
  detailError.value = ''
  resetFulfillmentForm()
}

// Watch for the order prop to trigger detail fetch
watch(
  () => props.order,
  (newOrder) => {
    if (newOrder && props.modelValue) {
      resetFulfillmentForm()
      fetchOrderDetail(newOrder.id)
    }
  }
)

watch(
  () => props.modelValue,
  (open) => {
    if (open && props.order) {
      resetFulfillmentForm()
      fetchOrderDetail(props.order.id)
    }
    if (!open) {
      handleClose()
    }
  }
)
</script>

<template>
  <Dialog :open="modelValue" @update:open="(value) => { if (!value) handleClose() }">
    <DialogScrollContent class="w-[calc(100vw-1rem)] max-w-2xl p-4 sm:p-6">
      <DialogHeader>
        <DialogTitle>{{ t('admin.orders.fulfillmentModalTitle') }}</DialogTitle>
      </DialogHeader>
      <div class="space-y-4">
        <div v-if="detailLoading" class="h-24 rounded-lg border border-border bg-muted/40 animate-pulse"></div>
        <div v-else-if="detailError" class="rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
          {{ detailError }}
        </div>
        <div v-else-if="selectedOrder" class="space-y-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Card class="rounded-lg border-border bg-background shadow-none">
              <CardContent class="p-3">
                <div class="text-xs text-muted-foreground">{{ t('admin.orders.table.id') }}</div>
                <div class="text-foreground font-mono mt-1">
                  <IdCell :value="selectedOrder.id" />
                </div>
              </CardContent>
            </Card>
            <Card class="rounded-lg border-border bg-background shadow-none">
              <CardContent class="p-3">
                <div class="text-xs text-muted-foreground">{{ t('admin.orders.detailOrderNo') }}</div>
                <div class="text-foreground mt-1 font-mono">{{ selectedOrder.order_no }}</div>
              </CardContent>
            </Card>
          </div>

          <form class="space-y-4" @submit.prevent="submitFulfillment">
            <div>
              <label class="block text-xs font-medium text-muted-foreground mb-1.5">{{ t('admin.orders.fulfillmentNote') }}</label>
              <Textarea
                v-model="fulfillmentForm.note"
                rows="3"
                :placeholder="t('admin.orders.fulfillmentNotePlaceholder')"
              />
            </div>

            <div class="rounded-lg border border-border bg-muted/20 p-3 space-y-3">
              <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div class="text-xs font-medium text-muted-foreground">{{ t('admin.orders.fulfillmentDeliveryData') }}</div>
                <Button class="w-full sm:w-auto" type="button" size="sm" variant="outline" @click="addDeliveryEntry">
                  {{ t('admin.orders.fulfillmentAddDeliveryField') }}
                </Button>
              </div>
              <div class="space-y-2">
                <div v-for="(entry, entryIndex) in fulfillmentForm.entries" :key="entryIndex" class="grid grid-cols-1 md:grid-cols-[1fr_1fr_auto] gap-2">
                  <Input v-model="entry.key" :placeholder="t('admin.orders.fulfillmentDeliveryKeyPlaceholder')" />
                  <Input v-model="entry.value" :placeholder="t('admin.orders.fulfillmentDeliveryValuePlaceholder')" />
                  <Button class="w-full md:w-auto" type="button" size="sm" variant="destructive" @click="removeDeliveryEntry(entryIndex)">
                    {{ t('admin.common.delete') }}
                  </Button>
                </div>
              </div>
            </div>

            <div v-if="fulfillmentError" class="rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
              {{ fulfillmentError }}
            </div>
            <div v-if="fulfillmentSuccess" class="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
              {{ fulfillmentSuccess }}
            </div>

            <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <Button class="w-full sm:w-auto" type="button" variant="outline" size="sm" @click="resetFulfillmentForm">
                {{ t('admin.common.reset') }}
              </Button>
              <Button class="w-full sm:w-auto" type="submit" size="sm" :disabled="fulfillmentSubmitting">
                {{ fulfillmentSubmitting ? t('admin.orders.fulfillmentSubmitting') : t('admin.orders.fulfillmentSubmit') }}
              </Button>
            </div>
          </form>
        </div>
      </div>
    </DialogScrollContent>
  </Dialog>
</template>

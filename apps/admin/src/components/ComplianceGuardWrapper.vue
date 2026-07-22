<script setup lang="ts">
import { ref, watch, onMounted } from 'vue'
import { useComplianceStore } from '@/stores/compliance'
import { useAdminAuthStore } from '@/stores/auth'
import ComplianceAckDialog from './ComplianceAckDialog.vue'
import ComplianceAckedBadge from './ComplianceAckedBadge.vue'

const compliance = useComplianceStore()
const auth = useAdminAuthStore()
const dialogOpen = ref(false)

async function ensureLoaded() {
  if (!compliance.loaded) {
    try {
      await compliance.fetchStatus()
    } catch {
      /* 守卫已处理 status_code !== 0 的常规错误，这里静默 */
    }
  }
}

function syncDialog() {
  if (!compliance.loaded) return
  if (!compliance.acknowledged && auth.isSuper) {
    dialogOpen.value = true
  } else {
    dialogOpen.value = false
  }
}

onMounted(async () => {
  await ensureLoaded()
  syncDialog()
})

watch(
  () => [compliance.loaded, compliance.acknowledged, auth.isSuper] as const,
  syncDialog,
)
</script>

<template>
  <div class="space-y-3">
    <div v-if="compliance.acknowledged" class="flex justify-end">
      <ComplianceAckedBadge />
    </div>
    <slot />
    <ComplianceAckDialog v-model:open="dialogOpen" />
  </div>
</template>

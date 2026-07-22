import { computed, ref } from 'vue'
import { resellerAPI, type ResellerManagementSnapshotData } from '../../api'
import { getResellerConsoleState } from '../../utils/resellerConsole'

export const useResellerProfile = () => {
  const loading = ref(false)
  const snapshot = ref<ResellerManagementSnapshotData | null>(null)
  const error = ref<unknown>(null)
  const state = computed(() => getResellerConsoleState(snapshot.value))

  const load = async () => {
    loading.value = true
    error.value = null
    try {
      const response = await resellerAPI.managementProfile()
      snapshot.value = response.data.data || null
    } catch (err) {
      error.value = err
      snapshot.value = null
    } finally {
      loading.value = false
    }
  }

  return { loading, snapshot, error, state, load }
}

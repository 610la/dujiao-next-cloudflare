<template>
  <div class="overflow-hidden rounded-xl border bg-card shadow-sm">
    <Table>
      <slot />
    </Table>
  </div>
</template>

<script setup lang="ts">
import { Table } from '@/components/ui/table'
</script>

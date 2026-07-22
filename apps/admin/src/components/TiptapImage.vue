<script setup lang="ts">
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'

const props = defineProps(nodeViewProps)

const onMouseDown = (event: MouseEvent) => {
  const startX = event.pageX
  const startWidth = (event.target as HTMLElement).parentElement?.offsetWidth || 0

  const onMouseMove = (moveEvent: MouseEvent) => {
    const currentX = moveEvent.pageX
    const diffX = currentX - startX
    const newWidth = Math.max(100, startWidth + diffX)

    props.updateAttributes({
      width: `${newWidth}px`,
    })
  }

  const onMouseUp = () => {
    document.removeEventListener('mousemove', onMouseMove)
    document.removeEventListener('mouseup', onMouseUp)
  }

  document.addEventListener('mousemove', onMouseMove)
  document.addEventListener('mouseup', onMouseUp)
}
</script>

<template>
  <node-view-wrapper class="tiptap-image-wrapper" :class="{ 'is-selected': selected }">
    <div class="image-container" :style="{ width: node.attrs.width || '100%' }">
      <img :src="node.attrs.src" :alt="node.attrs.alt" :title="node.attrs.title" class="rounded-lg" />
      <div class="resize-handle" @mousedown.prevent="onMouseDown"></div>
    </div>
  </node-view-wrapper>
</template>

<style scoped>
.tiptap-image-wrapper {
  display: flex;
  justify-content: center;
}

.image-container {
  position: relative;
  max-width: 100%;
  display: inline-block;
  line-height: 0;
}

.image-container img {
  width: 100%;
  height: auto;
  display: block;
}

.tiptap-image-wrapper.is-selected .image-container {
  outline: 2px solid hsl(var(--primary));
  outline-offset: 2px;
}

.resize-handle {
  position: absolute;
  right: -6px;
  bottom: -6px;
  width: 12px;
  height: 12px;
  background-color: hsl(var(--primary));
  border: 2px solid white;
  border-radius: 50%;
  cursor: nwse-resize;
  opacity: 0;
  transition: opacity 0.2s;
}

.image-container:hover .resize-handle,
.tiptap-image-wrapper.is-selected .resize-handle {
  opacity: 1;
}
</style>

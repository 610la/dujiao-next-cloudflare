<script setup lang="ts">
import { ref, watch, onBeforeUnmount } from 'vue'
import { useEditor, EditorContent, VueNodeViewRenderer } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'
import TextAlign from '@tiptap/extension-text-align'
import Color from '@tiptap/extension-color'
import { TextStyle } from '@tiptap/extension-text-style'
import { Table } from '@tiptap/extension-table'
import { TableCell } from '@tiptap/extension-table-cell'
import { TableHeader } from '@tiptap/extension-table-header'
import { TableRow } from '@tiptap/extension-table-row'
import MediaPicker from '@/components/admin/MediaPicker.vue'
import { getImageUrl } from '@/utils/image'
import { processHtmlForDisplay, processHtmlForStorage } from '@/utils/content'
import { useI18n } from 'vue-i18n'
import TiptapImage from './TiptapImage.vue'

const props = defineProps<{
  modelValue: string
  placeholder?: string
  uploadUrl?: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const mediaPickerRef = ref<InstanceType<typeof MediaPicker> | null>(null)
const mediaPickerValue = ref<string[]>([])

const openMediaPicker = () => {
  mediaPickerRef.value?.openPicker()
}

const handleMediaSelected = (value: string | string[]) => {
  const paths = Array.isArray(value) ? value : [value]
  if (paths.length && editor.value) {
    let chain = editor.value.chain().focus()
    for (const path of paths) {
      if (path) {
        chain = chain.setImage({ src: getImageUrl(path) })
      }
    }
    chain.run()
  }
  mediaPickerValue.value = []
}
const { t } = useI18n()
const showColorPicker = ref(false)
const currentColor = ref('#0f766e')

const presetColors = [
  '#ffffff',
  '#000000',
  '#ef4444',
  '#f97316',
  '#f59e0b',
  '#eab308',
  '#84cc16',
  '#22c55e',
  '#10b981',
  '#14b8a6',
  '#06b6d4',
  '#0ea5e9',
  '#3b82f6',
  '#6366f1',
  '#8b5cf6',
  '#a855f7',
  '#d946ef',
  '#ec4899',
]

const editor = useEditor({
  content: processHtmlForDisplay(props.modelValue),
  enableInputRules: false,
  enablePasteRules: false,
  extensions: [
    StarterKit,
    TextStyle,
    Color,
    Image.extend({
      addAttributes() {
        return {
          ...this.parent?.(),
          width: {
            default: null,
          },
        }
      },
      addNodeView() {
        return VueNodeViewRenderer(TiptapImage)
      },
    }).configure({
      HTMLAttributes: {
        class: 'max-w-full h-auto rounded-lg',
      },
      inline: true,
      allowBase64: false,
    }),
    Link.configure({
      openOnClick: false,
      HTMLAttributes: {
        class: 'text-primary underline',
      },
    }),
    Placeholder.configure({
      placeholder: props.placeholder || t('admin.richEditor.placeholder'),
    }),
    TextAlign.configure({
      types: ['heading', 'paragraph', 'image'],
    }),
    Table.configure({
      resizable: true,
    }),
    TableRow,
    TableHeader,
    TableCell,
  ],
  editorProps: {
    attributes: {
      class: 'prose max-w-none focus:outline-none min-h-[200px] px-4 py-3 text-foreground',
    },
  },
  onUpdate: ({ editor }) => {
    emit('update:modelValue', processHtmlForStorage(editor.getHTML()))
  },
})

const isSourceMode = ref(false)
const sourceContent = ref('')

watch(
  () => props.modelValue,
  (value) => {
    if (isSourceMode.value) {
      if (sourceContent.value !== value) {
        sourceContent.value = value
      }
    } else {
      const displayValue = processHtmlForDisplay(value)
      const isSame = editor.value?.getHTML() === displayValue

      if (!isSame && editor.value) {
        editor.value.commands.setContent(displayValue)
      }
    }
  }
)

const toggleSourceMode = () => {
  if (isSourceMode.value) {
    if (editor.value) {
      const displayValue = processHtmlForDisplay(sourceContent.value)
      editor.value.commands.setContent(displayValue)
      emit('update:modelValue', sourceContent.value)
    }
  } else {
    sourceContent.value = props.modelValue
  }
  isSourceMode.value = !isSourceMode.value
}

const handleSourceInput = (event: Event) => {
  const target = event.target as HTMLTextAreaElement
  emit('update:modelValue', target.value)
}

const addLink = () => {
  const url = window.prompt(t('admin.richEditor.enterLinkUrl'))
  if (url && editor.value) {
    editor.value.chain().focus().setLink({ href: url }).run()
  }
}

const setColor = (color: string) => {
  if (editor.value) {
    editor.value.chain().focus().setColor(color).run()
    showColorPicker.value = false
  }
}

const handleClickOutside = (event: MouseEvent) => {
  const target = event.target as HTMLElement
  if (!target.closest('.color-picker-container')) {
    showColorPicker.value = false
  }
}

watch(
  () => showColorPicker.value,
  (value) => {
    if (value) {
      document.addEventListener('click', handleClickOutside)
    } else {
      document.removeEventListener('click', handleClickOutside)
    }
  }
)

onBeforeUnmount(() => {
  editor.value?.destroy()
})
</script>

<template>
  <div class="rich-editor">
    <div v-if="editor" class="editor-toolbar" :class="{ 'is-source-mode': isSourceMode }">
      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.bold')" :class="{ 'is-active': editor.isActive('bold') }" @click="editor.chain().focus().toggleBold().run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M11 5H7a1 1 0 000 2h4a1 1 0 100-2zM7 11h6a1 1 0 100-2H7a1 1 0 100 2zM13 15H7a1 1 0 100 2h6a1 1 0 100-2z" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.italic')" :class="{ 'is-active': editor.isActive('italic') }" @click="editor.chain().focus().toggleItalic().run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M10 3a1 1 0 011 1v5h3a1 1 0 110 2h-3v5a1 1 0 11-2 0v-5H6a1 1 0 110-2h3V4a1 1 0 011-1z" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.strikethrough')" :class="{ 'is-active': editor.isActive('strike') }" @click="editor.chain().focus().toggleStrike().run()">
        <span class="font-bold line-through">S</span>
      </button>

      <div class="toolbar-divider"></div>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.heading1')" :class="{ 'is-active': editor.isActive('heading', { level: 1 }) }" @click="editor.chain().focus().toggleHeading({ level: 1 }).run()">
        H1
      </button>
      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.heading2')" :class="{ 'is-active': editor.isActive('heading', { level: 2 }) }" @click="editor.chain().focus().toggleHeading({ level: 2 }).run()">
        H2
      </button>
      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.heading3')" :class="{ 'is-active': editor.isActive('heading', { level: 3 }) }" @click="editor.chain().focus().toggleHeading({ level: 3 }).run()">
        H3
      </button>
      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.heading4')" :class="{ 'is-active': editor.isActive('heading', { level: 4 }) }" @click="editor.chain().focus().toggleHeading({ level: 4 }).run()">
        H4
      </button>

      <div class="toolbar-divider"></div>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.bulletList')" :class="{ 'is-active': editor.isActive('bulletList') }" @click="editor.chain().focus().toggleBulletList().run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.orderedList')" :class="{ 'is-active': editor.isActive('orderedList') }" @click="editor.chain().focus().toggleOrderedList().run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 8a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.blockquote')" :class="{ 'is-active': editor.isActive('blockquote') }" @click="editor.chain().focus().toggleBlockquote().run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6 10a2 2 0 11-4 0 2 2 0 014 0zM12 10a2 2 0 11-4 0 2 2 0 014 0zM16 12a2 2 0 100-4 2 2 0 000 4z" />
        </svg>
      </button>

      <div class="toolbar-divider"></div>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.insertLink')" :class="{ 'is-active': editor.isActive('link') }" @click="addLink">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 4 4 0 005.656 0l3-3a4 4 0 00-5.656-5.656l-1.5 1.5a1 1 0 101.414 1.414l1.5-1.5zm-5 5a2 2 0 012.828 0 1 1 0 101.414-1.414 4 4 0 00-5.656 0l-3 3a4 4 0 105.656 5.656l1.5-1.5a1 1 0 10-1.414-1.414l-1.5 1.5a2 2 0 11-2.828-2.828l3-3z" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.uploadImage')" @click="openMediaPicker">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" clip-rule="evenodd" />
        </svg>
      </button>
      <MediaPicker ref="mediaPickerRef" :model-value="mediaPickerValue" :multiple="true" scene="editor" dialog-only @update:model-value="handleMediaSelected" />

      <div class="relative color-picker-container">
        <button type="button" class="toolbar-btn" :title="t('admin.richEditor.textColor')" @click="showColorPicker = !showColorPicker">
          <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
            <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
          </svg>
        </button>

        <div v-if="showColorPicker" class="absolute top-full mt-2 left-0 rounded-lg border border-border bg-background p-3 shadow-lg z-50">
          <div class="grid grid-cols-6 gap-2 mb-2">
            <button v-for="color in presetColors" :key="color" type="button" class="h-6 w-6 rounded border border-border hover:scale-110 transition-transform" :style="{ backgroundColor: color }" :title="color" @click="setColor(color)"></button>
          </div>
          <div class="flex items-center space-x-2 pt-2 border-t border-border">
            <input v-model="currentColor" type="color" class="w-8 h-8 rounded cursor-pointer" @input="setColor(currentColor)" />
            <input v-model="currentColor" type="text" class="flex-1 rounded border border-border bg-background px-2 py-1 text-xs" @change="setColor(currentColor)" />
          </div>
        </div>
      </div>

      <div class="toolbar-divider"></div>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.alignLeft')" :class="{ 'is-active': editor.isActive({ textAlign: 'left' }) }" @click="editor.chain().focus().setTextAlign('left').run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h6a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h6a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.alignCenter')" :class="{ 'is-active': editor.isActive({ textAlign: 'center' }) }" @click="editor.chain().focus().setTextAlign('center').run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3 4a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H7a1 1 0 01-1-1zm3 4a1 1 0 011-1h6a1 1 0 110 2h-6a1 1 0 01-1-1z" clip-rule="evenodd" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.alignRight')" :class="{ 'is-active': editor.isActive({ textAlign: 'right' }) }" @click="editor.chain().focus().setTextAlign('right').run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm6 4a1 1 0 011-1h6a1 1 0 110 2h-6a1 1 0 01-1-1zm-6 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm6 4a1 1 0 011-1h6a1 1 0 110 2h-6a1 1 0 01-1-1z" clip-rule="evenodd" />
        </svg>
      </button>

      <div class="toolbar-divider"></div>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.insertTable')" @click="editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M5 4a3 3 0 00-3 3v6a3 3 0 003 3h10a3 3 0 003-3V7a3 3 0 00-3-3H5zm-1 9v-1h5v2H5a1 1 0 01-1-1zm7 1h4a1 1 0 001-1v-1h-5v2zm0-4h5V8h-5v2zM9 8H4v2h5V8z" clip-rule="evenodd" />
        </svg>
      </button>

      <template v-if="editor.isActive('table')">
        <button type="button" class="toolbar-btn" :title="t('admin.richEditor.addColumn')" @click="editor.chain().focus().addColumnAfter().run()">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn" :title="t('admin.richEditor.deleteColumn')" @click="editor.chain().focus().deleteColumn().run()">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn" :title="t('admin.richEditor.addRow')" @click="editor.chain().focus().addRowAfter().run()">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn" :title="t('admin.richEditor.deleteRow')" @click="editor.chain().focus().deleteRow().run()">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn" :title="t('admin.richEditor.mergeCells')" @click="editor.chain().focus().mergeCells().run()">
          <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
            <path d="M4 4h12v12H4z" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn text-destructive" :title="t('admin.richEditor.deleteTable')" @click="editor.chain().focus().deleteTable().run()">
          <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
        </button>
      </template>

      <div class="toolbar-divider"></div>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.undo')" :disabled="!editor.can().undo()" @click="editor.chain().focus().undo().run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M7.707 3.293a1 1 0 010 1.414L5.414 7H11a7 7 0 017 7v2a1 1 0 11-2 0v-2a5 5 0 00-5-5H5.414l2.293 2.293a1 1 0 11-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
        </svg>
      </button>

      <button type="button" class="toolbar-btn" :title="t('admin.richEditor.redo')" :disabled="!editor.can().redo()" @click="editor.chain().focus().redo().run()">
        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M12.293 3.293a1 1 0 011.414 0l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414-1.414L14.586 9H9a5 5 0 00-5 5v2a1 1 0 11-2 0v-2a7 7 0 017-7h5.586l-2.293-2.293a1 1 0 010-1.414z" clip-rule="evenodd" />
        </svg>
      </button>

      <div class="toolbar-divider"></div>

      <button type="button" class="toolbar-btn code-mode-btn" :title="t('admin.richEditor.sourceMode')" :class="{ 'is-active': isSourceMode }" @click="toggleSourceMode">
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
        </svg>
      </button>
    </div>

    <textarea
      v-if="isSourceMode"
      v-model="sourceContent"
      class="w-full min-h-[300px] p-4 font-mono text-sm bg-muted/10 text-foreground resize-y focus:outline-none"
      @input="handleSourceInput"
    ></textarea>
    <editor-content v-show="!isSourceMode" :editor="editor" class="editor-content" />
  </div>
</template>

<style scoped>
@reference "../style.css";

.rich-editor {
  @apply border border-border rounded-xl bg-background;
}

.editor-toolbar {
  @apply flex flex-nowrap items-center gap-1 overflow-x-auto overflow-y-visible p-1.5 border-b border-border bg-muted/40 sm:flex-wrap sm:overflow-visible sm:p-2;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: thin;
}

.toolbar-btn {
  @apply shrink-0 rounded-lg p-1.5 text-muted-foreground transition-all hover:bg-muted hover:text-foreground disabled:cursor-not-allowed disabled:opacity-30 sm:p-2;
}

.toolbar-btn.is-active {
  @apply bg-muted text-foreground;
}

.toolbar-divider {
  @apply mx-1 h-6 w-px shrink-0 bg-border;
}

.editor-toolbar.is-source-mode .toolbar-btn:not(.code-mode-btn) {
  opacity: 0.3;
  pointer-events: none;
}

.editor-toolbar.is-source-mode .toolbar-divider {
  opacity: 0.3;
}

:deep(.editor-content) {
  @apply text-foreground overflow-hidden;
}

:deep(.ProseMirror) {
  outline: none;
}

:deep(.ProseMirror p.is-editor-empty:first-child::before) {
  @apply text-muted-foreground float-left h-0 pointer-events-none;
  content: attr(data-placeholder);
}

:deep(.ProseMirror h1) {
  @apply text-2xl font-bold mb-4 mt-6;
}

:deep(.ProseMirror h2) {
  @apply text-xl font-bold mb-3 mt-5;
}

:deep(.ProseMirror h3) {
  @apply text-lg font-bold mb-2 mt-4;
}

:deep(.ProseMirror ul),
:deep(.ProseMirror ol) {
  padding-left: 1.5rem;
  margin-top: 1rem;
  margin-bottom: 1rem;
}

:deep(.ProseMirror ul) {
  list-style-type: disc;
}

:deep(.ProseMirror ol) {
  list-style-type: decimal;
}

:deep(.ProseMirror li) {
  margin-bottom: 0.25rem;
}

:deep(.ProseMirror blockquote) {
  @apply border-l-4 border-border pl-4 italic text-muted-foreground my-4;
}

:deep(.ProseMirror code) {
  background-color: rgba(0, 0, 0, 0.08);
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  font-size: 0.875rem;
  font-family: monospace;
  color: hsl(var(--primary));
}

:deep(.ProseMirror pre) {
  background-color: rgba(0, 0, 0, 0.06);
  padding: 1rem;
  border-radius: 0.5rem;
  margin-top: 1rem;
  margin-bottom: 1rem;
  overflow-x: auto;
}

:deep(.ProseMirror pre code) {
  background-color: transparent;
  padding: 0;
}

:deep(.ProseMirror img) {
  max-width: 100%;
  height: auto;
  border-radius: 0.5rem;
}

:deep(.ProseMirror p:has(+ .tiptap-image-wrapper)) {
  margin-bottom: 1rem;
}

:deep(.ProseMirror .tiptap-image-wrapper + p:not(:empty)) {
  margin-top: 1rem;
}

:deep(.ProseMirror a) {
  color: hsl(var(--primary));
  text-decoration: underline;
}

:deep(.ProseMirror a:hover) {
  opacity: 0.8;
}

:deep(.ProseMirror strong),
:deep(.ProseMirror b) {
  font-weight: 700;
}

:deep(.ProseMirror em),
:deep(.ProseMirror i) {
  font-style: italic;
  font-synthesis: style;
  font-synthesis-style: auto;
}

:deep(.ProseMirror u) {
  text-decoration-line: underline;
  text-underline-offset: 0.16em;
}

:deep(.ProseMirror s),
:deep(.ProseMirror del) {
  text-decoration-line: line-through;
}

:deep(.ProseMirror p) {
  margin-bottom: 0.5rem;
}

:deep(.ProseMirror table) {
  @apply border-collapse w-full my-4 overflow-hidden;
  table-layout: fixed;
}

:deep(.ProseMirror td),
:deep(.ProseMirror th) {
  @apply min-w-[1em] border border-border p-2 align-top relative bg-muted/30;
}

:deep(.ProseMirror th) {
  @apply font-bold text-left bg-muted/50;
}

:deep(.ProseMirror .selectedCell:after) {
  z-index: 2;
  position: absolute;
  content: "";
  left: 0;
  right: 0;
  top: 0;
  bottom: 0;
  background: rgba(15, 118, 110, 0.2);
  pointer-events: none;
}

:deep(.ProseMirror .column-resize-handle) {
  position: absolute;
  right: -2px;
  top: 0;
  bottom: -2px;
  width: 4px;
  background-color: hsl(var(--primary));
  pointer-events: none;
}
</style>

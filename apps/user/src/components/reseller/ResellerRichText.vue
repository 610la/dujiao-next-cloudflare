<template>
  <div class="overflow-hidden rounded-xl border bg-background shadow-sm">
    <div v-if="editor" class="flex flex-wrap items-center gap-1 border-b bg-muted/40 p-2">
      <button type="button" :class="btnClass(editor.isActive('bold'))" :title="t('personalCenter.reseller.siteConfig.editor.bold')" @click="editor.chain().focus().toggleBold().run()">
        <Bold class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive('italic'))" :title="t('personalCenter.reseller.siteConfig.editor.italic')" @click="editor.chain().focus().toggleItalic().run()">
        <Italic class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive('underline'))" :title="t('personalCenter.reseller.siteConfig.editor.underline')" @click="editor.chain().focus().toggleUnderline().run()">
        <UnderlineIcon class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive('strike'))" :title="t('personalCenter.reseller.siteConfig.editor.strike')" @click="editor.chain().focus().toggleStrike().run()">
        <Strikethrough class="h-4 w-4" />
      </button>

      <span class="mx-1 h-5 w-px bg-border"></span>

      <button type="button" :class="btnClass(editor.isActive('heading', { level: 2 }))" :title="t('personalCenter.reseller.siteConfig.editor.heading2')" @click="editor.chain().focus().toggleHeading({ level: 2 }).run()">
        <Heading2 class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive('heading', { level: 3 }))" :title="t('personalCenter.reseller.siteConfig.editor.heading3')" @click="editor.chain().focus().toggleHeading({ level: 3 }).run()">
        <Heading3 class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive('bulletList'))" :title="t('personalCenter.reseller.siteConfig.editor.bulletList')" @click="editor.chain().focus().toggleBulletList().run()">
        <List class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive('orderedList'))" :title="t('personalCenter.reseller.siteConfig.editor.orderedList')" @click="editor.chain().focus().toggleOrderedList().run()">
        <ListOrdered class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive('blockquote'))" :title="t('personalCenter.reseller.siteConfig.editor.blockquote')" @click="editor.chain().focus().toggleBlockquote().run()">
        <Quote class="h-4 w-4" />
      </button>

      <span class="mx-1 h-5 w-px bg-border"></span>

      <button type="button" :class="btnClass(editor.isActive('link'))" :title="t('personalCenter.reseller.siteConfig.editor.link')" @click="addLink">
        <Link2 class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(false)" :title="t('personalCenter.reseller.siteConfig.editor.image')" :disabled="uploading" @click="triggerUpload">
        <Loader2 v-if="uploading" class="h-4 w-4 animate-spin" />
        <ImagePlus v-else class="h-4 w-4" />
      </button>

      <span class="mx-1 h-5 w-px bg-border"></span>

      <button type="button" :class="btnClass(editor.isActive({ textAlign: 'left' }))" :title="t('personalCenter.reseller.siteConfig.editor.alignLeft')" @click="editor.chain().focus().setTextAlign('left').run()">
        <AlignLeft class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive({ textAlign: 'center' }))" :title="t('personalCenter.reseller.siteConfig.editor.alignCenter')" @click="editor.chain().focus().setTextAlign('center').run()">
        <AlignCenter class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(editor.isActive({ textAlign: 'right' }))" :title="t('personalCenter.reseller.siteConfig.editor.alignRight')" @click="editor.chain().focus().setTextAlign('right').run()">
        <AlignRight class="h-4 w-4" />
      </button>

      <span class="mx-1 h-5 w-px bg-border"></span>

      <button type="button" :class="btnClass(false)" :title="t('personalCenter.reseller.siteConfig.editor.undo')" :disabled="!editor.can().undo()" @click="editor.chain().focus().undo().run()">
        <Undo2 class="h-4 w-4" />
      </button>
      <button type="button" :class="btnClass(false)" :title="t('personalCenter.reseller.siteConfig.editor.redo')" :disabled="!editor.can().redo()" @click="editor.chain().focus().redo().run()">
        <Redo2 class="h-4 w-4" />
      </button>
    </div>

    <EditorContent :editor="editor" />

    <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onFileChange" />
    <p v-if="uploadError" class="border-t border-destructive/30 bg-destructive/5 px-3 py-1.5 text-xs text-destructive">{{ uploadError }}</p>
  </div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'
import TextAlign from '@tiptap/extension-text-align'
import Underline from '@tiptap/extension-underline'
import {
    AlignCenter,
    AlignLeft,
    AlignRight,
    Bold,
    Heading2,
    Heading3,
    ImagePlus,
    Italic,
    Link2,
    List,
    ListOrdered,
    Loader2,
    Quote,
    Redo2,
    Strikethrough,
    Underline as UnderlineIcon,
    Undo2,
} from 'lucide-vue-next'
import { resellerAPI } from '../../api'
import { getImageUrl } from '../../utils/image'
import { processHtmlForDisplay, processHtmlForStorage } from '../../utils/content'

const props = defineProps<{ modelValue: string; placeholder?: string }>()
const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()

const { t } = useI18n()
const fileInput = ref<HTMLInputElement | null>(null)
const uploading = ref(false)
const uploadError = ref('')

const btnClass = (active: boolean) =>
    [
        'inline-flex h-8 w-8 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-background hover:text-foreground disabled:cursor-not-allowed disabled:opacity-30',
        active ? 'bg-background text-foreground shadow-sm' : '',
    ].join(' ')

const editor = useEditor({
    content: processHtmlForDisplay(props.modelValue),
    enableInputRules: false,
    enablePasteRules: false,
    extensions: [
        StarterKit,
        Underline,
        Link.configure({ openOnClick: false, HTMLAttributes: { class: 'text-primary underline' } }),
        Image.configure({ HTMLAttributes: { class: 'max-w-full h-auto rounded-lg' }, allowBase64: false }),
        Placeholder.configure({
            placeholder: () => props.placeholder || t('personalCenter.reseller.siteConfig.editor.placeholder'),
        }),
        TextAlign.configure({ types: ['heading', 'paragraph'] }),
    ],
    editorProps: {
        attributes: {
            class: 'prose prose-sm dark:prose-invert max-w-none focus:outline-none min-h-[180px] px-4 py-3 text-foreground',
        },
    },
    onUpdate: ({ editor }) => {
        emit('update:modelValue', editor.isEmpty ? '' : processHtmlForStorage(editor.getHTML()))
    },
})

watch(
    () => props.modelValue,
    (value) => {
        if (!editor.value) return
        const displayValue = processHtmlForDisplay(value || '')
        if (editor.value.getHTML() !== displayValue) {
            editor.value.commands.setContent(displayValue, false)
        }
    },
)

const addLink = () => {
    if (!editor.value) return
    const previous = (editor.value.getAttributes('link').href as string) || ''
    const url = window.prompt(t('personalCenter.reseller.siteConfig.editor.linkPrompt'), previous)
    if (url === null) return
    if (url === '') {
        editor.value.chain().focus().extendMarkRange('link').unsetLink().run()
        return
    }
    editor.value.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
}

const triggerUpload = () => fileInput.value?.click()

const onFileChange = async (e: Event) => {
    const input = e.target as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file) return
    uploading.value = true
    uploadError.value = ''
    try {
        const res = await resellerAPI.uploadImage(file)
        const url = res.data?.data?.url
        if (url && editor.value) {
            editor.value.chain().focus().setImage({ src: getImageUrl(url) }).run()
        }
    } catch (err: any) {
        uploadError.value = err?.message || t('personalCenter.reseller.siteConfig.uploadFailed')
    } finally {
        uploading.value = false
    }
}

onBeforeUnmount(() => editor.value?.destroy())
</script>

<style scoped>
@reference "../../style.css";

:deep(.ProseMirror) {
    outline: none;
}

:deep(.ProseMirror p.is-editor-empty:first-child::before) {
    @apply pointer-events-none float-left h-0 text-muted-foreground;
    content: attr(data-placeholder);
}

:deep(.ProseMirror img) {
    max-width: 100%;
    height: auto;
    border-radius: 0.5rem;
}

:deep(.ProseMirror a) {
    @apply text-primary underline;
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
</style>

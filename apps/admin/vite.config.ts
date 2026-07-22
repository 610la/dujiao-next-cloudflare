import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'
import { readFileSync } from 'node:fs'

const projectConfig = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../config/project.json', import.meta.url)), 'utf8'),
) as { adminPath?: string }
const adminPath = String(projectConfig.adminPath || 'admin-panel')
  .trim()
  .replace(/^\/+|\/+$/g, '')
  .replace(/[^a-zA-Z0-9_-]/g, '')

if (!adminPath) throw new Error('config/project.json adminPath is invalid')

const cfAsyncModuleScriptPlugin = () => ({
  name: 'cfasync-module-script',
  transformIndexHtml(html: string) {
    return html.replace(
      /<script\s+type="module"(?![^>]*data-cfasync)/g,
      '<script data-cfasync="false" type="module"',
    )
  },
})

const adminBaseInjector = () => ({
  name: 'inject-admin-base-placeholder',
  transformIndexHtml(html: string) {
    // 在 <head> 开标签后立即插入 <base>。占位符 __DJ_ADMIN_BASE__
    // 由后端 internal/web 包在启动时一次性替换为实际 admin path。
    return html.replace(
      /<head[^>]*>/,
      (m) => `${m}\n    <base href="__DJ_ADMIN_BASE__/">`,
    )
  },
})

const isFullstack = process.env.VITE_FULLSTACK === '1'

// https://vite.dev/config/
export default defineConfig({
  base: isFullstack ? './' : `/${adminPath}/`,
  define: {
    __ADMIN_BASE__: JSON.stringify(`/${adminPath}/`),
  },
  plugins: [
    vue(),
    cfAsyncModuleScriptPlugin(),
    ...(isFullstack ? [adminBaseInjector()] : []),
  ],
  server: {
    host: '0.0.0.0',
    port: 5174,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/uploads': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-vue': ['vue', 'vue-router', 'pinia', 'vue-i18n'],
          'vendor-ui': ['reka-ui', 'class-variance-authority', 'clsx', 'tailwind-merge', 'lucide-vue-next'],
          'vendor-tiptap': [
            '@tiptap/vue-3',
            '@tiptap/starter-kit',
            '@tiptap/extension-image',
            '@tiptap/extension-link',
            '@tiptap/extension-placeholder',
            '@tiptap/extension-text-align',
            '@tiptap/extension-color',
            '@tiptap/extension-text-style',
            '@tiptap/extension-table',
            '@tiptap/extension-table-cell',
            '@tiptap/extension-table-header',
            '@tiptap/extension-table-row',
          ],
        },
      },
    },
    chunkSizeWarningLimit: 600,
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})

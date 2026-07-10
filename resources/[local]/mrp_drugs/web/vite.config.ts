import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';

// Build target is a single self-contained index.html so FiveM only needs to
// stream one file (web/dist/index.html). This app runs inside an <iframe>
// hosted by html/index.html and communicates with the parent (vanilla layer)
// via window.postMessage.
export default defineConfig({
  plugins: [react(), viteSingleFile()],
  base: './',
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    target: 'es2020',
    assetsInlineLimit: 100_000_000,
    chunkSizeWarningLimit: 8000,
    cssCodeSplit: false,
  },
});

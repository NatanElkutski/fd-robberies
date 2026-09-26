import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// NUI pages are served from nui://fd-robberies/web/build/, so every URL must be relative.
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: 'build',
    emptyOutDir: true,
    assetsDir: 'assets',
    target: 'es2020',
  },
  server: {
    port: 3000,
    // allow importing ../locales/*.json (browser-dev fallback dictionary)
    fs: { allow: ['..'] },
  },
});

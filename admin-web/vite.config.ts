import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.indexOf('node_modules') === -1) return undefined;
          if (id.indexOf('recharts') !== -1 || id.indexOf('d3-') !== -1) return 'charts';
          if (id.indexOf('lucide-react') !== -1) return 'icons';
          return 'vendor';
        },
      },
    },
  },
  server: {
    host: '127.0.0.1',
    port: 5174,
  },
});

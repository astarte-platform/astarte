import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import eslint from 'vite-plugin-eslint';
import viteTsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig(() => ({
  server: {
    host: 'dashboard.astarte.localhost',
    open: true,
    port: 8080,
  },
  build: {
    outDir: 'build',
  },
  plugins: [react(), eslint(), viteTsconfigPaths()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/setupTests.ts',
  },
}));

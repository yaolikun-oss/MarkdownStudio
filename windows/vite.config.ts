import { defineConfig } from "vite";
export default defineConfig({
  base: "./",
  build: { outDir: "build/renderer", emptyOutDir: true },
  server: { host: "127.0.0.1", strictPort: true, port: 5199 },
});

import fs from "node:fs/promises";
import { build } from "esbuild";
await build({
  entryPoints: { main: "electron/main.ts", preload: "electron/preload.ts" },
  bundle: true,
  platform: "node",
  format: "cjs",
  target: "node22",
  outdir: "build/electron",
  outExtension: { ".js": ".cjs" },
  external: ["electron"],
  sourcemap: true,
});

for (const folder of ["cmaps", "standard_fonts", "wasm"])
  await fs.cp(
    `node_modules/pdfjs-dist/${folder}`,
    `build/renderer/pdf-assets/${folder}`,
    { recursive: true },
  );

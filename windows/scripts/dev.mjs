import { spawn } from "node:child_process";
import { createServer } from "vite";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
await import("./build-main.mjs");
const server = await createServer();
await server.listen();
const child = spawn(
  process.execPath,
  [require.resolve("electron/cli.js"), "."],
  {
    stdio: "inherit",
    env: { ...process.env, STUDIO_DEV_URL: "http://127.0.0.1:5199" },
  },
);
child.on("exit", async (code) => {
  await server.close();
  process.exit(code ?? 0);
});

child.on("error", async (error) => {
  console.error(error.message);
  await server.close();
  process.exit(1);
});

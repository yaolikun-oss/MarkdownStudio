import {
  app,
  BrowserWindow,
  WebContentsView,
  Menu,
  dialog,
  ipcMain,
  protocol,
  net,
  session,
  shell,
} from "electron";
import type { IpcMainInvokeEvent } from "electron";
import fs from "node:fs/promises";
import { createReadStream } from "node:fs";
import { Readable } from "node:stream";
import path from "node:path";
import { pathToFileURL } from "node:url";
import crypto from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  supportedKind,
  normalizePreferences,
  digest,
  atomicWrite,
  saveNoteFile,
  assetPath,
  webURL,
} from "./core.mjs";
import type { OpenFile, Preferences, WorkspaceFile, WorkspaceProject } from "../src/types";
const run = promisify(execFile);
protocol.registerSchemesAsPrivileged([
  {
    scheme: "studio-asset",
    privileges: { standard: true, secure: true, supportFetchAPI: true },
  },
  {
    scheme: "studio-file",
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      stream: true,
    },
  },
]);
app.setName("MarkdownStudioWindows");
let win: BrowserWindow;
let web: WebContentsView | null = null;
let dirty = false;
let allowClose = false;
let loaded = false;
const registry = new Map<string, OpenFile>();
const allowed = new Set<string>();
let preferences: Preferences;
let prefsFile: string;
let recoveryFile: string;
let preferenceWrites = Promise.resolve();
let recoveryWrites = Promise.resolve();
const pending: string[] = [];
function command(value: string) {
  if (win && !win.isDestroyed()) win.webContents.send("command", value);
}
function trusted(event: {
  sender: Electron.WebContents;
  senderFrame: Electron.WebFrameMain | null;
}) {
  if (
    !win ||
    event.sender !== win.webContents ||
    event.senderFrame !== win.webContents.mainFrame
  )
    throw new Error("不允许的调用来源");
}
function handle(channel: string, fn: (...args: any[]) => any) {
  ipcMain.handle(channel, (event: IpcMainInvokeEvent, ...args: unknown[]) => {
    trusted(event);
    return fn(...args);
  });
}
function item(id: string) {
  const value = registry.get(id);
  if (!value) throw new Error("文件授权已失效，请重新打开。");
  return value;
}
async function findTool(name: "office" | "calibre") {
  const names =
    name === "office"
      ? ["soffice.com", "soffice.exe", "soffice"]
      : ["ebook-convert.exe", "ebook-convert"];
  const folders = [
    ...(process.env.PATH ?? "").split(path.delimiter),
    process.env.ProgramFiles
      ? path.join(process.env.ProgramFiles, "LibreOffice", "program")
      : "",
    process.env.ProgramFiles
      ? path.join(process.env.ProgramFiles, "Calibre2")
      : "",
    "C:\\Program Files\\LibreOffice\\program",
    "C:\\Program Files\\Calibre2",
    "/Applications/LibreOffice.app/Contents/MacOS",
    "/Applications/calibre.app/Contents/MacOS",
  ];
  for (const folder of folders.filter(Boolean))
    for (const name of names) {
      const file = path.join(folder, name);
      try {
        if ((await fs.stat(file)).isFile()) return file;
      } catch {}
    }
  return null;
}
async function convertedPath(source: string, format: string) {
  const office = ["doc", "pages"].includes(format);
  const tool = await findTool(office ? "office" : "calibre");
  if (!tool)
    throw new Error(
      office
        ? "此格式需要电脑已安装 LibreOffice 才能生成只读 PDF。可先在原软件中导出 PDF，再打开阅读。"
        : "此格式需要电脑已安装 Calibre 才能转换为 EPUB；本程序不会自动安装软件，也不能解除 DRM。",
    );
  const bytes = await fs.readFile(source);
  const folder = path.join(
    app.getPath("userData"),
    "conversion-cache",
    digest(bytes),
  );
  await fs.mkdir(folder, { recursive: true });
  const output = path.join(
    folder,
    office
      ? `${path.basename(source, path.extname(source))}.pdf`
      : "reading.epub",
  );
  try {
    if ((await fs.stat(output)).size > 0) return output;
  } catch {}
  if (office) {
    const profile = pathToFileURL(path.join(folder, "office-profile")).href;
    await run(
      tool,
      [
        `-env:UserInstallation=${profile}`,
        "--headless",
        "--convert-to",
        "pdf",
        "--outdir",
        folder,
        source,
      ],
      { timeout: 120000, maxBuffer: 1024 * 1024, windowsHide: true },
    );
  } else
    await run(tool, [source, output], {
      timeout: 180000,
      maxBuffer: 1024 * 1024,
      windowsHide: true,
    });
  const result = await fs.readFile(output);
  if (office && !result.subarray(0, 5).equals(Buffer.from("%PDF-")))
    throw new Error("文档转换失败，未得到有效 PDF。原文件未改动。");
  if (!office && !(result[0] === 0x50 && result[1] === 0x4b))
    throw new Error("电子书转换失败，未得到有效 EPUB。原文件未改动。");
  return output;
}
async function openFile(file: string): Promise<OpenFile> {
  const original = path.resolve(file);
  const kind = supportedKind(original);
  const stat = await fs.stat(original);
  if (!stat.isFile())
    throw new Error("请选择一个文件；Pages 文件夹包请先在原软件导出为 PDF。");
  if (stat.size > 512 * 1024 * 1024)
    throw new Error("此版本暂不打开超过 512 MB 的文件。");
  const id = crypto.randomUUID();
  const format = path.extname(original).slice(1).toLowerCase();
  let value: OpenFile = {
    id,
    path: original,
    name: path.basename(original),
    kind,
    format,
    url: `studio-file://${id}/original`,
  };
  if (kind === "note") {
    if (stat.size > 32 * 1024 * 1024)
      throw new Error("笔记超过 32 MB，暂不支持编辑。");
    const bytes = await fs.readFile(original);
    const content = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    value = { ...value, content, hash: digest(bytes) };
  } else if (["doc", "pages", "mobi", "azw", "azw3"].includes(format)) {
    const converted = await convertedPath(original, format);
    value = {
      ...value,
      converted: true,
      format: path.extname(converted).slice(1),
    };
    convertedFiles.set(id, converted);
  }
  allowed.add(original);
  registry.set(id, value);
  return value;
}
const convertedFiles = new Map<string, string>();
async function chooseFile() {
  const result = await dialog.showOpenDialog(win, {
    title: "打开阅读文件或 Markdown 笔记",
    properties: ["openFile"],
    filters: [
      {
        name: "支持的文档",
        extensions: [
          "md",
          "markdown",
          "txt",
          "pdf",
          "epub",
          "docx",
          "doc",
          "pages",
          "mobi",
          "azw",
          "azw3",
        ],
      },
    ],
  });
  if (result.canceled) return null;
  return openFile(result.filePaths[0]);
}

const workspaceFolders = ["阅读资料", "笔记", "网页"] as const;
function safeWorkspaceName(input: unknown) {
  const name = String(input ?? "").trim().replace(/[<>:"/\\|?*\u0000-\u001f]/g, "-").slice(0, 100);
  if (!name || name === "." || name === "..") throw new Error("请输入有效的 Workspace 名称。");
  return name;
}
async function scanWorkspace(manifestPath: string): Promise<WorkspaceProject> {
  const manifest = path.resolve(manifestPath);
  if (path.extname(manifest).toLowerCase() !== ".mdworkspace")
    throw new Error("请选择 .mdworkspace 工程文件。");
  const raw = JSON.parse(await fs.readFile(manifest, "utf8"));
  if (raw?.version !== 1 || typeof raw.name !== "string")
    throw new Error("Workspace 文件格式无效或版本不受支持。");
  const root = path.dirname(manifest);
  const files: WorkspaceFile[] = [];
  async function walk(folder: string, depth: number) {
    if (depth > 8 || files.length >= 10000) return;
    for (const entry of await fs.readdir(folder, { withFileTypes: true })) {
      if (entry.name.startsWith(".") || entry.isSymbolicLink()) continue;
      const file = path.join(folder, entry.name);
      if (entry.isDirectory()) await walk(file, depth + 1);
      else if (entry.isFile() && path.resolve(file) !== manifest) {
        try {
          const kind = supportedKind(file);
          const format = path.extname(file).slice(1).toLowerCase();
          allowed.add(path.resolve(file));
          files.push({
            name: entry.name,
            path: path.resolve(file),
            kind,
            format,
            relativePath: path.relative(root, file),
          });
        } catch {}
      }
    }
  }
  await walk(root, 0);
  allowed.add(manifest);
  return {
    version: 1,
    name: raw.name.slice(0, 100),
    manifestPath: manifest,
    root,
    files: files.sort((a, b) => a.relativePath.localeCompare(b.relativePath, "zh-CN")),
  };
}
async function createWorkspace(input: unknown) {
  const name = safeWorkspaceName(input);
  const result = await dialog.showOpenDialog(win, {
    title: "选择新 Workspace 的上级文件夹",
    properties: ["openDirectory", "createDirectory"],
  });
  if (result.canceled) return null;
  const root = path.join(result.filePaths[0], name);
  try {
    await fs.mkdir(root);
  } catch (error: any) {
    if (error?.code !== "EEXIST") throw error;
    if ((await fs.readdir(root)).length)
      throw new Error("同名文件夹已经存在且不为空，请换一个 Workspace 名称。");
  }
  for (const folder of workspaceFolders) await fs.mkdir(path.join(root, folder), { recursive: true });
  const manifest = path.join(root, `${name}.mdworkspace`);
  await atomicWrite(
    manifest,
    Buffer.from(JSON.stringify({ version: 1, name, createdAt: Date.now() }, null, 2)),
  );
  const home = path.join(root, "笔记", "主笔记.md");
  await atomicWrite(
    home,
    Buffer.from(`# ${name}\n\n## 学习目标\n\n说明这个主题要解决的问题、范围和预期成果。\n\n## 资料与笔记\n\n在“阅读资料”中导入原书，在“笔记”中整理专题笔记。\n`),
  );
  return scanWorkspace(manifest);
}
async function chooseWorkspace() {
  const result = await dialog.showOpenDialog(win, {
    title: "打开 Markdown Studio Workspace",
    properties: ["openFile"],
    filters: [{ name: "Markdown Studio Workspace", extensions: ["mdworkspace"] }],
  });
  return result.canceled ? null : scanWorkspace(result.filePaths[0]);
}
async function importWorkspaceFiles(manifestPath: string) {
  const project = await scanWorkspace(manifestPath);
  const result = await dialog.showOpenDialog(win, {
    title: "导入资料或笔记到 Workspace",
    properties: ["openFile", "multiSelections"],
    filters: [{ name: "支持的文档", extensions: ["md", "markdown", "txt", "pdf", "epub", "docx", "doc", "pages", "mobi", "azw", "azw3"] }],
  });
  if (result.canceled) return null;
  for (const source of result.filePaths) {
    const kind = supportedKind(source);
    const targetFolder = path.join(project.root, kind === "note" ? "笔记" : "阅读资料");
    const ext = path.extname(source);
    const stem = path.basename(source, ext);
    let target = path.join(targetFolder, path.basename(source));
    for (let index = 2; ; index++) {
      try {
        await fs.access(target);
        target = path.join(targetFolder, `${stem} (${index})${ext}`);
      } catch {
        break;
      }
    }
    await fs.copyFile(source, target);
  }
  return scanWorkspace(project.manifestPath);
}
async function sendOpen(file: string) {
  try {
    if (!loaded) {
      pending.push(file);
      return;
    }
    const value = await openFile(file);
    win.webContents.send("file:opened", value);
  } catch (error) {
    await dialog.showMessageBox(win, {
      type: "error",
      message: "无法打开文件",
      detail: String((error as Error).message),
    });
  }
}
async function sendPending() {
  for (const file of pending.splice(0)) await sendOpen(file);
}
function webState(error?: string) {
  if (!web) return;
  win.webContents.send("web:state", {
    url: web.webContents.getURL(),
    title: web.webContents.getTitle(),
    loading: web.webContents.isLoading(),
    error,
  });
}
function createWeb() {
  const view = new WebContentsView({
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      partition: "persist:reading-web",
      webSecurity: true,
    },
  });
  const wc = view.webContents;
  wc.session.setPermissionRequestHandler((_w, _permission, cb) => cb(false));
  wc.session.setPermissionCheckHandler(() => false);
  wc.setWindowOpenHandler(({ url }) => {
    try {
      void wc.loadURL(webURL(url)).catch(() => {});
    } catch {}
    return { action: "deny" };
  });
  wc.on("will-navigate", (event, url) => {
    try {
      webURL(url);
    } catch {
      event.preventDefault();
    }
  });
  wc.on("did-navigate", () => webState());
  wc.on("did-navigate-in-page", () => webState());
  wc.on("page-title-updated", () => webState());
  wc.on("did-start-loading", () => webState());
  wc.on("did-stop-loading", () => webState());
  wc.on("did-fail-load", (_event, code, description, _url, isMain) => {
    if (isMain && code !== -3) webState(`网页加载失败：${description}`);
  });
  wc.on("before-input-event", (event, input) => {
    if (input.control && input.shift && input.key.toLowerCase() === "r") {
      event.preventDefault();
      command("focus");
    } else if (input.control && input.key.toLowerCase() === "r") {
      event.preventDefault();
      command("mode");
    }
  });
  win.contentView.addChildView(view);
  view.setVisible(false);
  return view;
}
async function registerProtocols() {
  protocol.handle("studio-asset", async (request) => {
    try {
      const u = new URL(request.url);
      const doc = item(u.hostname);
      const file = await assetPath(path.dirname(doc.path), u.pathname.slice(1));
      return net.fetch(pathToFileURL(file).href);
    } catch {
      return new Response("Not found", { status: 404 });
    }
  });
  protocol.handle("studio-file", async (request) => {
    try {
      const doc = item(new URL(request.url).hostname);
      const file = convertedFiles.get(doc.id) ?? doc.path;
      const stat = await fs.stat(file);
      const type =
        doc.format === "pdf"
          ? "application/pdf"
          : doc.format === "epub"
            ? "application/epub+zip"
            : "application/octet-stream";
      let start = 0,
        end = stat.size - 1,
        status = 200;
      const range = request.headers.get("range");
      if (range) {
        const m = /^bytes=(\d+)-(\d*)$/.exec(range);
        if (!m) return new Response(null, { status: 416 });
        start = Number(m[1]);
        end = m[2] ? Math.min(end, Number(m[2])) : end;
        status = 206;
        if (start > end || start >= stat.size)
          return new Response(null, {
            status: 416,
            headers: { "Content-Range": `bytes */${stat.size}` },
          });
      }
      const headers: Record<string, string> = {
        "Content-Type": type,
        "Accept-Ranges": "bytes",
        "Content-Length": String(end - start + 1),
        "Access-Control-Allow-Origin": "*",
      };
      if (status === 206)
        headers["Content-Range"] = `bytes ${start}-${end}/${stat.size}`;
      return new Response(
        Readable.toWeb(
          createReadStream(file, { start, end }),
        ) as ReadableStream,
        { status, headers },
      );
    } catch {
      return new Response("Not found", { status: 404 });
    }
  });
}
async function start() {
  prefsFile = path.join(app.getPath("userData"), "preferences.json");
  recoveryFile = path.join(app.getPath("userData"), "recovery.json");
  let stored = {};
  try {
    stored = JSON.parse(await fs.readFile(prefsFile, "utf8"));
  } catch {}
  preferences = normalizePreferences(stored) as Preferences;
  for (const recent of preferences.recent)
    for (const file of [recent.note, recent.reading])
      if (file && !/^https?:/.test(file)) allowed.add(path.resolve(file));
  await registerProtocols();
  win = new BrowserWindow({
    width: 1440,
    height: 940,
    minWidth: 900,
    minHeight: 620,
    backgroundColor: "#f5f6f8",
    title: "Markdown Studio",
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
    },
  });
  win.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  win.webContents.on("will-navigate", (event, url) => {
    if (url !== win.webContents.getURL()) event.preventDefault();
  });
  session.defaultSession.setPermissionRequestHandler((_w, _p, cb) => cb(false));
  win.on("close", (event) => {
    if (!allowClose && loaded) {
      event.preventDefault();
      command("close-window");
    }
  });
  win.on("closed", () => {
    web?.webContents.close();
    web = null;
  });
  const emit = (value: string) => () => command(value);
  Menu.setApplicationMenu(
    Menu.buildFromTemplate([
      {
        label: "文件",
        submenu: [
          { label: "打开文件…", accelerator: "Ctrl+O", click: emit("open") },
          {
            label: "打开文件夹…",
            accelerator: "Ctrl+Shift+O",
            click: emit("folder"),
          },
          {
            label: "新建 Markdown 笔记",
            accelerator: "Ctrl+N",
            click: emit("new"),
          },
          { label: "保存", accelerator: "Ctrl+S", click: emit("save") },
          {
            label: "另存为…",
            accelerator: "Ctrl+Shift+S",
            click: emit("save-as"),
          },
          { type: "separator" },
          {
            label: "关闭当前文件",
            accelerator: "Ctrl+W",
            click: emit("close-active"),
          },
          { label: "退出", accelerator: "Alt+F4", click: () => win.close() },
        ],
      },
      {
        label: "编辑",
        submenu: [
          { role: "undo", label: "撤销" },
          { role: "redo", label: "重做" },
          { type: "separator" },
          { role: "cut", label: "剪切" },
          { role: "copy", label: "复制" },
          { role: "paste", label: "粘贴" },
          { role: "selectAll", label: "全选" },
          { label: "查找", accelerator: "Ctrl+F", click: emit("find") },
        ],
      },
      {
        label: "视图",
        submenu: [
          {
            label: "切换 Markdown 可视化 / 源码",
            accelerator: "Ctrl+R",
            click: emit("mode"),
          },
          {
            label: "切换阅读 / 编辑区域",
            accelerator: "Ctrl+Shift+R",
            click: emit("focus"),
          },
          {
            label: "切换并排 / 单区显示",
            accelerator: "Ctrl+Alt+L",
            click: emit("layout"),
          },
          {
            label: "最大化 / 还原当前面板",
            accelerator: "Ctrl+Shift+M",
            click: emit("maximize"),
          },
          { label: "放大原文", accelerator: "Ctrl+=", click: emit("zoom-in") },
          { label: "缩小原文", accelerator: "Ctrl+-", click: emit("zoom-out") },
          { role: "togglefullscreen", label: "窗口全屏", accelerator: "F11" },
          ...(process.env.STUDIO_DEV_URL
            ? [{ role: "toggleDevTools" as const }]
            : []),
        ],
      },
    ]),
  );
  handle("file:choose", chooseFile);
  handle("workspace:create", createWorkspace);
  handle("workspace:choose", chooseWorkspace);
  handle("workspace:open", (file: string) => {
    if (typeof file !== "string") throw new Error("Workspace 路径无效。");
    return scanWorkspace(file);
  });
  handle("workspace:import", (file: string) => {
    if (typeof file !== "string") throw new Error("Workspace 路径无效。");
    return importWorkspaceFiles(file);
  });
  handle("workspace:trash", async (manifestPath: string, filePath: string) => {
    const project = await scanWorkspace(manifestPath);
    const target = path.resolve(filePath);
    const [realRoot, realTarget] = await Promise.all([
      fs.realpath(project.root),
      fs.realpath(target),
    ]);
    const relative = path.relative(realRoot, realTarget);
    if (!relative || relative.startsWith("..") || path.isAbsolute(relative))
      throw new Error("只能删除当前 Workspace 内的文件。");
    if (target === project.manifestPath) throw new Error("不能在工程打开期间删除 Workspace 文件。");
    await shell.trashItem(realTarget);
    registry.forEach((value, key) => {
      if (value.path === target) registry.delete(key);
    });
    return scanWorkspace(project.manifestPath);
  });
  handle("folder:choose", async () => {
    const result = await dialog.showOpenDialog(win, {
      properties: ["openDirectory"],
      title: "打开文档文件夹",
    });
    if (result.canceled) return null;
    const root = result.filePaths[0];
    const files: { name: string; path: string }[] = [];
    async function walk(folder: string, depth: number) {
      for (const entry of await fs.readdir(folder, { withFileTypes: true })) {
        if (entry.name.startsWith(".") || files.length >= 5000) continue;
        const file = path.join(folder, entry.name);
        if (entry.isDirectory() && depth < 5) await walk(file, depth + 1);
        else if (entry.isFile()) {
          try {
            supportedKind(file);
            allowed.add(path.resolve(file));
            files.push({ name: path.relative(root, file), path: file });
          } catch {}
        }
      }
    }
    await walk(root, 0);
    return {
      name: path.basename(root),
      files: files.sort((a, b) => a.name.localeCompare(b.name, "zh-CN")),
    };
  });
  handle("file:open", (file: string) => {
    if (typeof file !== "string" || !allowed.has(path.resolve(file)))
      throw new Error("请通过打开文件或文件夹授权此文件。");
    return openFile(file);
  });
  handle("file:bytes", async (id: string) => {
    const doc = item(id);
    const file = convertedFiles.get(id) ?? doc.path;
    if (
      (await fs.stat(file)).size >
      (doc.format === "pdf" ? 512 : 128) * 1024 * 1024
    )
      throw new Error("此阅读格式暂不支持超过 128 MB 的文件。");
    return new Uint8Array(await fs.readFile(file));
  });
  handle(
    "note:save",
    async (id: string | null, text: string, saveAs: boolean) => {
      const previous = id ? item(id) : null;
      if (previous && previous.kind !== "note")
        throw new Error("原文仅供阅读，不能写入。");
      let file = previous?.path;
      let hash = previous?.hash;
      if (!file || saveAs) {
        const result = await dialog.showSaveDialog(win, {
          title: "保存 Markdown 笔记",
          defaultPath: previous?.path ?? "未命名笔记.md",
          filters: [{ name: "Markdown 笔记", extensions: ["md"] }],
        });
        if (result.canceled || !result.filePath) return null;
        file = result.filePath;
        if (!path.extname(file)) file += ".md";
        try {
          hash = digest(await fs.readFile(file));
        } catch {
          hash = undefined;
        }
      }
      const savedHash = await saveNoteFile(file, text, hash);
      if (previous && previous.path === file) {
        previous.hash = savedHash;
        previous.content = text;
        return previous;
      }
      return openFile(file);
    },
  );
  handle("note:image", async (id: string, bytes: number[], name: string) => {
    const doc = item(id);
    if (
      doc.kind !== "note" ||
      !Array.isArray(bytes) ||
      bytes.length > 20 * 1024 * 1024
    )
      throw new Error("图片无效或超过 20 MB。");
    const buffer = Buffer.from(bytes);
    let ext = path.extname(name).toLowerCase();
    if (
      buffer
        .subarray(0, 8)
        .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
    )
      ext = ".png";
    else if (buffer[0] === 255 && buffer[1] === 216) ext = ".jpg";
    else if (
      buffer.subarray(0, 4).toString() === "RIFF" &&
      buffer.subarray(8, 12).toString() === "WEBP"
    )
      ext = ".webp";
    else throw new Error("截图粘贴仅支持 PNG、JPEG、WebP。");
    const folder = path.join(path.dirname(doc.path), ".md-assets");
    await fs.mkdir(folder, { recursive: true });
    const filename = `image-${crypto.randomUUID()}${ext}`;
    await atomicWrite(path.join(folder, filename), buffer);
    return `.md-assets/${filename}`;
  });
  handle("prefs:get", () => preferences);
  handle("prefs:set", async (value: unknown) => {
    const next = normalizePreferences(
      (value && typeof value === "object" ? value : {}) as object,
    ) as Preferences;
    for (const recent of next.recent)
      for (const file of [recent.note, recent.reading]) {
        if (file && !/^https?:/.test(file) && !allowed.has(path.resolve(file)))
          throw new Error("最近文件只能记录已打开的路径。");
      }
    preferences = next;
    const contents = JSON.stringify(preferences);
    preferenceWrites = preferenceWrites
      .catch(() => {})
      .then(() => atomicWrite(prefsFile, Buffer.from(contents)));
    await preferenceWrites;
  });
  handle("recovery:get", async () => {
    try {
      const value = JSON.parse(await fs.readFile(recoveryFile, "utf8"));
      if (typeof value.content !== "string") return null;
      return value;
    } catch {
      return null;
    }
  });
  handle(
    "recovery:set",
    (value: { path: string | null; content: string } | null) => {
      recoveryWrites = recoveryWrites
        .catch(() => {})
        .then(async () => {
          if (value === null) {
            await fs.rm(recoveryFile, { force: true });
            return;
          }
          if (
            typeof value.content !== "string" ||
            Buffer.byteLength(value.content) > 32 * 1024 * 1024
          )
            throw new Error("恢复数据无效");
          await atomicWrite(recoveryFile, Buffer.from(JSON.stringify(value)));
        });
      return recoveryWrites;
    },
  );
  ipcMain.on("note:dirty", (event, value) => {
    trusted(event);
    dirty = !!value;
    win.setDocumentEdited(dirty);
  });
  ipcMain.on("window:close-ready", (event) => {
    trusted(event);
    allowClose = true;
    win.close();
  });
  handle("web:open", async (input: string) => {
    const url = webURL(input);
    if (!web) web = createWeb();
    try {
      await web.webContents.loadURL(url);
    } catch (error) {
      webState(String((error as Error).message));
    }
  });
  ipcMain.on(
    "web:bounds",
    (
      event,
      bounds: {
        x: number;
        y: number;
        width: number;
        height: number;
        visible: boolean;
      },
    ) => {
      trusted(event);
      if (!web) return;
      const { width, height } = win.getContentBounds();
      const b = {
        x: Math.max(0, Math.min(width, Math.round(bounds.x) || 0)),
        y: Math.max(0, Math.min(height, Math.round(bounds.y) || 0)),
        width: Math.max(0, Math.min(width, Math.round(bounds.width) || 0)),
        height: Math.max(0, Math.min(height, Math.round(bounds.height) || 0)),
      };
      web.setBounds(b);
      web.setVisible(!!bounds.visible && b.width > 0 && b.height > 0);
    },
  );
  handle("web:action", async (action: string, value: unknown) => {
    if (!web) return;
    const wc = web.webContents;
    switch (action) {
      case "back":
        if (wc.navigationHistory.canGoBack()) wc.navigationHistory.goBack();
        break;
      case "forward":
        if (wc.navigationHistory.canGoForward())
          wc.navigationHistory.goForward();
        break;
      case "reload":
        wc.reload();
        break;
      case "focus":
        wc.focus();
        break;
      case "zoom":
        if (typeof value === "number")
          wc.setZoomFactor(Math.max(0.25, Math.min(4, value)));
        break;
      case "selection":
        return wc.executeJavaScript('window.getSelection()?.toString() || ""');
      case "close":
        wc.close();
        web = null;
        break;
    }
  });
  win.webContents.on("did-finish-load", () => {
    loaded = true;
    void sendPending();
  });
  if (process.env.STUDIO_DEV_URL) await win.loadURL(process.env.STUDIO_DEV_URL);
  else await win.loadFile(path.join(__dirname, "../renderer/index.html"));
}
const lock = app.requestSingleInstanceLock();
if (!lock) app.quit();
else {
  app.on("second-instance", (_event, argv) => {
    win?.show();
    win?.focus();
    const file = argv.find((x) => {
      try {
        supportedKind(x);
        return !x.startsWith("-");
      } catch {
        return false;
      }
    });
    if (file) void sendOpen(file);
  });
  app.on("open-file", (event, file) => {
    event.preventDefault();
    void sendOpen(file);
  });
  app.on("window-all-closed", () => app.quit());
  const file = process.argv.slice(1).find((x) => {
    try {
      supportedKind(x);
      return !x.startsWith("-");
    } catch {
      return false;
    }
  });
  if (file) pending.push(file);
  void app
    .whenReady()
    .then(start)
    .catch((error) => {
      dialog.showErrorBox("Markdown Studio 启动失败", String(error));
      app.quit();
    });
}

import { applyVisualStyle } from "./presentation";
import { drag } from "./splitter";
import "./style.css";
import { MarkdownEditors } from "./markdown";
import { Reader } from "./readers";
import type { EPUBAnnotation, OpenFile, Preferences, Style, WorkspaceProject } from "./types";

const api = window.studio;
const $ = <T extends HTMLElement = HTMLElement>(id: string) =>
  document.getElementById(id) as T;
const app = $("app");
app.innerHTML = `
<nav id="rail" aria-label="功能栏"><div class="brand" title="Markdown Studio">M<span>·</span></div>
<button data-side="files" title="文件与最近使用" aria-label="文件与最近使用">▱</button><button data-side="reading" title="原文目录" aria-label="原文目录">▤</button><button data-side="outline" title="Markdown 目录" aria-label="Markdown 目录">☷</button><button data-side="bookmarks" title="网页收藏" aria-label="网页收藏">☆</button><div class="rail-spacer"></div><button id="settings" title="样式设置" aria-label="样式设置">⚙</button></nav>
<aside id="sidebar"><header><span id="side-title">工程</span><button id="hide-sidebar" title="收起侧栏">‹</button></header><div class="file-actions"><button id="new-workspace" title="以学习主题新建 Workspace">新建工程</button><button id="open-workspace" title="打开 .mdworkspace 工程">打开工程</button><button id="import-workspace" title="把资料复制到当前工程" disabled>导入资料</button><button id="open-file" title="临时打开文件 Ctrl+O">打开文件</button><button id="open-folder" hidden title="打开普通文件夹 Ctrl+Shift+O">文件夹</button><button id="new-note" title="新建笔记 Ctrl+N">＋ 笔记</button></div><div id="side-content"></div><footer>Markdown Studio <b>Windows</b><span>0.2.0 · 预览版</span></footer></aside><div id="side-resizer" role="separator" aria-label="调整侧栏宽度" tabindex="0"></div>
<div id="main"><header id="topbar"><button id="show-sidebar" title="展开侧栏" hidden>☰</button><div class="document-title"><span id="window-title">阅读，思考，写下笔记</span><span id="dirty-dot" hidden>未保存</span></div><button id="save" title="保存 Ctrl+S" disabled>保存</button><button id="close-reading" disabled>关闭原文</button><button id="close-note" disabled>关闭笔记</button><div class="toolbar-spacer"></div><button id="layout">切换显示</button><button id="open-web">打开网页</button><button id="style">样式</button></header>
<div id="modebar"><div id="workspace-tabs"><button id="tab-reading">阅读原文</button><button id="tab-note">Markdown 笔记</button></div><div id="open-document-tabs" aria-label="已打开文档"></div><span id="layout-label">原文与笔记，并排思考</span><span class="shortcut">Ctrl+Shift+R 切换阅读 / 编辑</span></div>
<section id="workspace"><article id="reading-pane" class="pane"><header class="pane-bar"><span id="reading-title">阅读原文</span><div class="toolbar-spacer"></div><button id="read-prev" title="上一页">‹</button><input id="page" value="1" aria-label="阅读页码" inputmode="numeric"><span id="page-total">/ 1</span><button id="read-next" title="下一页">›</button><button id="add-annotation" title="选中 EPUB 原文后添加备注 Ctrl+Alt+M" disabled>标记</button><button id="show-annotations" title="查看当前 EPUB 的备注 Ctrl+Alt+Shift+M" disabled>备注 <span id="annotation-count">0</span></button><button id="zoom-out" title="缩小原文">−</button><input id="zoom" value="100" aria-label="阅读缩放百分比" inputmode="numeric"><span>%</span><button id="zoom-in" title="放大原文">＋</button><button id="fit-width" title="根据当前阅读区域重新计算页宽">适宽</button><button id="fit-height" title="根据当前阅读区域重新计算页高">适高</button><button id="fit-best" title="每次重新计算：扫描页原图像素 1:1，其他页面完整显示">最佳显示</button><button id="reading-max" title="最大化原文面板">⤢ 满屏</button></header>
<div id="webbar" hidden><button id="web-back" title="网页后退">‹</button><button id="web-forward" title="网页前进">›</button><button id="web-reload" title="重新加载网页">↻</button><form id="address-form"><input id="address" placeholder="输入网址，如 example.com" aria-label="网页地址"></form><button id="bookmark" title="收藏网页">☆</button><button id="clip" title="将网页选中文字附加到笔记">剪藏</button></div>
<div id="reading-body" tabindex="0" aria-label="原文阅读区"><div class="empty"><span class="empty-symbol">▤</span><h1>让阅读留下思考</h1><p>打开 PDF、EPUB 或 Word 文档，<br>在旁边写下自己的 Markdown 笔记。</p><button class="primary" data-action="open">打开阅读文件</button></div></div><div id="web-surface" hidden></div><div id="reading-status" role="status"></div></article>
<div id="splitter" class="splitter" role="separator" aria-label="调整阅读与笔记比例" tabindex="0"></div>
<article id="note-pane" class="pane"><header class="pane-bar"><span id="note-title">Markdown 笔记</span><div class="toolbar-spacer"></div><div class="segmented"><button id="visual-mode" class="selected">可视化</button><button id="source-mode">源码</button></div><details id="syntax-menu"><summary>语法 ▾</summary><div id="syntax-items" class="dropdown"></div></details><details id="source-menu"><summary>源码显示 ▾</summary><div class="dropdown"><label><input id="syntax-color" type="checkbox" checked>语法着色</label><label><input id="whitespace" type="checkbox">空白符与段落 ¶</label></div></details><button id="note-max" title="最大化或还原当前 Markdown 编辑区">⤢ 满屏</button></header>
<div id="note-content"><div id="visual-host" class="markdown-document" aria-label="Markdown 可视化编辑区"></div><div id="note-splitter" class="splitter" role="separator" aria-label="调整可视化与源码比例" tabindex="0"></div><div id="source-host" aria-label="Markdown 源码编辑区"></div><div id="note-empty" class="empty"><span class="empty-symbol">✎</span><h2>为这次阅读写一份笔记</h2><p>笔记是独立的 Markdown 文件。<br>也可以只打开 Markdown，左右对照编辑。</p><div><button class="primary" data-action="new">新建笔记</button><button data-action="open">打开已有笔记</button></div></div></div><footer id="editor-status"><span id="note-location">Markdown · UTF-8</span><span id="composition-state"></span><span id="note-words"></span></footer></article></section>
<footer id="statusbar"><span id="status">就绪</span><span id="platform-note">Windows 预览版 · 本地文档</span></footer></div>
<div id="notification" role="alert" hidden><span></span><button title="关闭提示">×</button></div>
<dialog id="dialog"><form method="dialog"><header><h2 id="dialog-title"></h2><button value="cancel" aria-label="关闭对话框">×</button></header><div id="dialog-content"></div><footer id="dialog-actions"></footer></form></dialog>`;

let prefs: Preferences;
let note: OpenFile | null = null;
let untitled = false;
let reading: OpenFile | null = null;
let website = "";
let webTitle = "";
let saved = "";
let active: "reading" | "note" = "note";
let selectedTab: "reading" | "note" = "note";
let maximized: "reading" | "note" | null = null;
let side = "files";
let sidebarHidden = false;
let folder: { name: string; files: { name: string; path: string }[] } | null =
  null;
let workspaceProject: WorkspaceProject | null = null;
let openTabs: { path: string; name: string; kind: "note" | "reading" }[] = [];
let epubSelection: { cfi: string; quote: string } | null = null;
let toc: { title: string; href: string; depth: number }[] = [];
let modal = false;
let queue = Promise.resolve();
let recoveryTimer: ReturnType<typeof setTimeout> | undefined;
let outlineTimer: ReturnType<typeof setTimeout> | undefined;
let settingsTimer: ReturnType<typeof setTimeout> | undefined;
let noteVersion = 0;
let savedVersion = 0;
const hasNote = () => !!note || untitled;
const hasReading = () => !!reading || !!website;
const isDirty = () => hasNote() && noteVersion !== savedVersion;
const currentAnnotations = () =>
  reading?.format === "epub" ? prefs.annotations[reading.path] ?? [] : [];
function notify(message: string) {
  const box = $("notification");
  box.querySelector("span")!.textContent = message;
  box.hidden = false;
}
$("notification").querySelector("button")!.onclick = () => {
  $("notification").hidden = true;
};
function status(message: string) {
  $("status").textContent = message || "就绪";
}
function run(work: () => Promise<void> | void) {
  queue = queue.then(async () => {
    try {
      await work();
    } catch (error) {
      status("操作未完成");
      notify((error as Error).message);
    }
  });
  return queue;
}
function persist() {
  clearTimeout(settingsTimer);
  settingsTimer = setTimeout(() => {
    void api.storePreferences(prefs).catch((e) => notify(e.message));
  }, 250);
}
function escape(text: string) {
  return text.replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ]!,
  );
}
function basename(file: string) {
  return file.split(/[\\/]/).filter(Boolean).at(-1) ?? file;
}
function remember() {
  const pair = {
    reading: reading?.path || website || null,
    note: note?.path || null,
    openedAt: Date.now(),
  };
  if (!pair.reading && !pair.note) return;
  prefs.recent = [
    pair,
    ...prefs.recent.filter(
      (x) => x.reading !== pair.reading || x.note !== pair.note,
    ),
  ].slice(0, 20);
  persist();
  renderSidebar();
}
function savePosition() {
  if (reading) prefs.positions[reading.path] = reader.location();
  persist();
}
function webBounds() {
  if (!website) return;
  const rect = $("web-surface").getBoundingClientRect();
  api.webBounds({
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
    visible:
      !modal && !$("reading-pane").hidden && rect.width > 0 && rect.height > 0,
  });
}
async function ask(
  title: string,
  content: string,
  buttons: { label: string; value: string; primary?: boolean }[] = [
    { label: "确定", value: "ok", primary: true },
  ],
) {
  const dlg = $<HTMLDialogElement>("dialog");
  modal = true;
  webBounds();
  $("dialog-title").textContent = title;
  $("dialog-content").innerHTML = content;
  $("dialog-actions").innerHTML = buttons
    .map(
      (b) =>
        `<button value="${b.value}" class="${b.primary ? "primary" : ""}">${b.label}</button>`,
    )
    .join("");
  dlg.showModal();
  const result = await new Promise<string>((resolve) =>
    dlg.addEventListener("close", () => resolve(dlg.returnValue), {
      once: true,
    }),
  );
  modal = false;
  webBounds();
  return result;
}
const editors = new MarkdownEditors(
  $("visual-host"),
  $("source-host"),
  changed,
  (mode) => {
    active = "note";
    if (editors.both && editors.mode !== mode) editors.switchMode(mode);
    else editors.mode = mode;
    renderToolbar();
  },
  async (file) => {
    if (!hasNote()) return null;
    if (!note && !(await save())) return null;
    const id = note!.id;
    const relative = await api.importImage(
      id,
      Array.from(new Uint8Array(await file.arrayBuffer())),
      file.name || "screenshot.png",
    );
    return relative;
  },
);
const reader = new Reader(
  $("reading-body"),
  (message) => {
    $("reading-status").textContent = message;
  },
  (position) => {
    if (reading) {
      prefs.positions[reading.path] = position;
      persist();
    }
  },
  (items) => {
    toc = items;
    if (side === "reading") renderSidebar();
  },
  (page, total) => {
    $<HTMLInputElement>("page").value = String(page);
    $("page-total").textContent = `/ ${total}`;
    $<HTMLButtonElement>("read-prev").disabled = page <= 1;
    $<HTMLButtonElement>("read-next").disabled = page >= total;
  },
  () => {
    active = "reading";
    renderToolbar();
  },
  (selection) => {
    epubSelection = selection;
    renderToolbar();
  },
);
function changed() {
  noteVersion++;
  api.setDirty(isDirty());
  renderToolbar();
  clearTimeout(recoveryTimer);
  recoveryTimer = setTimeout(() => {
    if (editors.source.composing || editors.visual.view.composing) {
      changed();
      return;
    }
    if (isDirty())
      void api
        .recovery({ path: note?.path ?? null, content: editors.text() })
        .catch((e) => notify(e.message));
  }, 1500);
  clearTimeout(outlineTimer);
  outlineTimer = setTimeout(() => {
    if (editors.source.composing || editors.visual.view.composing) return;
    const text = editors.text();
    $("note-words").textContent = `${text.length.toLocaleString()} 字符`;
    if (side === "outline") renderSidebar();
  }, 1800);
}
async function commit() {
  editors.flushComposition();
  await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
  return editors.text();
}
async function save(saveAs = false) {
  if (!hasNote()) return true;
  const text = await commit();
  const version = noteVersion;
  const result = await api.saveNote(note?.id ?? null, text, saveAs);
  if (!result) return false;
  const oldID = note?.id;
  note = result;
  untitled = false;
  saved = text;
  savedVersion = version;
  if (oldID !== result.id) {
    editors.setFileID(result.id);
  }
  api.setDirty(isDirty());
  await api.recovery(
    isDirty() ? { path: result.path, content: editors.text() } : null,
  );
  remember();
  render();
  status("已保存");
  return true;
}
async function allowDiscard() {
  if (!hasNote()) return true;
  const text = await commit();
  if (text === saved) {
    savedVersion = noteVersion;
    api.setDirty(false);
    return true;
  }
  if (!isDirty()) return true;
  const answer = await ask(
    "笔记有未保存的修改",
    "<p>继续前是否保存当前 Markdown 笔记？</p>",
    [
      { label: "取消", value: "cancel" },
      { label: "不保存", value: "discard" },
      { label: "保存", value: "save", primary: true },
    ],
  );
  if (answer === "save") return save();
  if (answer === "discard") await api.recovery(null);
  return answer === "discard";
}
function rememberTab(file: OpenFile) {
  const tab = { path: file.path, name: file.name, kind: file.kind } as const;
  openTabs = [
    ...openTabs.filter((item) => item.path !== file.path),
    tab,
  ].slice(-30);
}
async function adopt(file: OpenFile) {
  if (file.kind === "note") {
    if (note?.path === file.path) return;
    if (!(await allowDiscard())) return;
    note = file;
    untitled = false;
    saved = file.content ?? "";
    noteVersion = 0;
    savedVersion = 0;
    editors.setFile(saved, file.id);
    api.setDirty(false);
    await api.recovery(null);
    selectedTab = "note";
    active = "note";
    maximized = null;
    rememberTab(file);
    remember();
    render();
    status(`已打开笔记：${file.name}`);
  } else {
    savePosition();
    reading = file;
    website = "";
    await api.webAction("close");
    selectedTab = "reading";
    active = "reading";
    maximized = null;
    rememberTab(file);
    render();
    status(file.converted ? "正在打开转换后的阅读副本…" : "正在打开原文…");
    reader.setStyle(prefs.styles.reading);
    await reader.open(file, prefs.readingZoom, prefs.positions[file.path]);
    reader.setAnnotations(currentAnnotations());
    remember();
    render();
    status(file.converted ? "格式已转换为阅读副本，原文件未改动" : "就绪");
  }
}
async function open() {
  const file = await api.openFile();
  if (file) await adopt(file);
}
async function useWorkspace(project: WorkspaceProject) {
  if (!(await allowDiscard())) return;
  savePosition();
  reader.clear();
  reading = null;
  website = "";
  note = null;
  untitled = false;
  noteVersion = 0;
  savedVersion = 0;
  openTabs = [];
  editors.setFile("", null);
  workspaceProject = project;
  prefs.workspace = project.manifestPath;
  folder = null;
  side = "files";
  sidebarHidden = false;
  persist();
  render();
  const home = project.files.find(
    (file) => file.kind === "note" && /(^|[\\/])主笔记\.md$/i.test(file.relativePath),
  );
  if (home) await adopt(await api.openPath(home.path));
}
async function newWorkspace() {
  const result = ask(
    "新建学习 Workspace",
    '<label class="field">主题名称<input id="workspace-name" maxlength="100" placeholder="例如：汉娜·阿伦特研究" autofocus></label><p class="muted">程序会建立主题文件夹、阅读资料、笔记、网页和主笔记；之后导入的原书会复制进工程，不依赖外部原件。</p>',
    [
      { label: "取消", value: "cancel" },
      { label: "选择位置并创建", value: "create", primary: true },
    ],
  );
  if ((await result) !== "create") return;
  const project = await api.createWorkspace($<HTMLInputElement>("workspace-name").value);
  if (project) await useWorkspace(project);
}
async function openWorkspace() {
  const project = await api.chooseWorkspace();
  if (project) await useWorkspace(project);
}
async function importWorkspace() {
  if (!workspaceProject) return;
  const result = await api.importWorkspaceFiles(workspaceProject.manifestPath);
  if (!result) return;
  workspaceProject = result;
  render();
  status("资料已复制到当前 Workspace");
}
async function editAnnotation(existing?: EPUBAnnotation) {
  if (reading?.format !== "epub") return;
  const anchor = existing ?? epubSelection;
  if (!anchor) {
    notify("请先在 EPUB 原文中选中一段文字。");
    return;
  }
  const promise = ask(
    existing ? "修改 EPUB 备注" : "添加 EPUB 备注",
    `<blockquote>${escape(anchor.quote)}</blockquote><label class="field">备注<textarea id="annotation-note" rows="5" placeholder="可只做高亮，也可以写下说明"></textarea></label><div class="style-grid"><label class="field">标记方式<select id="annotation-style"><option value="highlight">高亮</option><option value="underline">下划线</option></select></label><label class="field">颜色<input id="annotation-color" type="color" value="#ffe58f"></label></div>`,
    [
      { label: "取消", value: "cancel" },
      { label: "保存", value: "save", primary: true },
    ],
  );
  $<HTMLTextAreaElement>("annotation-note").value = existing?.note ?? "";
  $<HTMLSelectElement>("annotation-style").value = existing?.style ?? "highlight";
  $<HTMLInputElement>("annotation-color").value = existing?.color ?? "#ffe58f";
  if ((await promise) !== "save" || reading?.format !== "epub") {
    reader.focus();
    return;
  }
  const now = Date.now();
  const annotation: EPUBAnnotation = {
    id: existing?.id ?? crypto.randomUUID(),
    cfi: anchor.cfi,
    quote: anchor.quote,
    note: $<HTMLTextAreaElement>("annotation-note").value.trim(),
    style: $<HTMLSelectElement>("annotation-style").value === "underline" ? "underline" : "highlight",
    color: $<HTMLInputElement>("annotation-color").value,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };
  const values = currentAnnotations().filter((item) => item.id !== annotation.id);
  prefs.annotations[reading.path] = [...values, annotation];
  epubSelection = null;
  reader.setAnnotations(prefs.annotations[reading.path]);
  persist();
  renderToolbar();
  reader.focus();
}
async function showAnnotations() {
  if (reading?.format !== "epub") return;
  const values = currentAnnotations();
  const rows = values.length
    ? values
        .map(
          (item) =>
            `<article class="annotation-row"><blockquote>${escape(item.quote)}</blockquote>${item.note ? `<p>${escape(item.note)}</p>` : ""}<div><button type="button" data-jump="${item.id}">跳转</button><button type="button" data-edit="${item.id}">修改</button><button type="button" data-delete="${item.id}">删除</button></div></article>`,
        )
        .join("")
    : '<p class="side-empty">还没有备注。选中 EPUB 原文后点击“标记”。</p>';
  const promise = ask("EPUB 备注", `<div class="annotation-list">${rows}</div>`, [
    { label: "完成", value: "done", primary: true },
  ]);
  for (const button of Array.from(document.querySelectorAll<HTMLButtonElement>("[data-jump],[data-edit],[data-delete]"))) {
    button.onclick = () => {
      const action = button.dataset.jump ? "jump" : button.dataset.edit ? "edit" : "delete";
      const id = button.dataset.jump ?? button.dataset.edit ?? button.dataset.delete;
      $<HTMLDialogElement>("dialog").close(`${action}:${id}`);
    };
  }
  const result = await promise;
  const [action, id] = result.split(":", 2);
  const annotation = values.find((item) => item.id === id);
  if (annotation && action === "jump") await reader.jumpAnnotation(annotation);
  else if (annotation && action === "edit") await editAnnotation(annotation);
  else if (annotation && action === "delete" && reading?.format === "epub") {
    const confirm = await ask(
      "删除这条 EPUB 备注？",
      `<blockquote>${escape(annotation.quote)}</blockquote>`,
      [
        { label: "取消", value: "cancel" },
        { label: "删除", value: "delete", primary: true },
      ],
    );
    if (confirm === "delete") {
      prefs.annotations[reading.path] = values.filter((item) => item.id !== annotation.id);
      reader.setAnnotations(prefs.annotations[reading.path]);
      persist();
      renderToolbar();
    }
  }
  reader.focus();
}
async function createNote() {
  if (!(await allowDiscard())) return;
  note = null;
  untitled = true;
  saved = "";
  noteVersion = 0;
  savedVersion = 0;
  editors.setFile("", null);
  selectedTab = "note";
  active = "note";
  maximized = null;
  api.setDirty(false);
  render();
  editors.focus();
}
async function closeNote() {
  if (!(await allowDiscard())) return;
  note = null;
  untitled = false;
  saved = "";
  noteVersion = 0;
  savedVersion = 0;
  editors.setFile("", null);
  api.setDirty(false);
  await api.recovery(null);
  selectedTab = hasReading() ? "reading" : "note";
  active = selectedTab;
  maximized = null;
  render();
}
async function closeReading() {
  savePosition();
  reader.clear();
  reading = null;
  website = "";
  webTitle = "";
  await api.webAction("close");
  selectedTab = "note";
  active = "note";
  maximized = null;
  render();
}
async function switchMode(mode: "visual" | "source") {
  if (!hasNote()) return;
  if (isDirty() && !(await save())) return;
  editors.switchMode(mode);
  active = "note";
  selectedTab = "note";
  render();
  requestAnimationFrame(() => editors.focus());
}
async function changeLayout() {
  if (isDirty() && !(await save())) return;
  prefs.layout = prefs.layout === "tabs" ? "split" : "tabs";
  maximized = null;
  persist();
  render();
}
async function selectArea(area: "reading" | "note") {
  if (area === "reading" && !hasReading()) {
    await switchMode(editors.mode === "visual" ? "source" : "visual");
    return;
  }
  if (isDirty() && !(await save())) return;
  active = area;
  selectedTab = area;
  if (maximized && maximized !== area) maximized = null;
  render();
  requestAnimationFrame(() => {
    if (area === "note") editors.focus();
    else if (website) void api.webAction("focus");
    else reader.focus();
  });
}
async function maximize(area: "reading" | "note") {
  if (area === "reading" && !hasReading()) return;
  if (area === "note" && !hasNote()) return;
  if (isDirty() && !(await save())) return;
  active = area;
  selectedTab = area;
  maximized = maximized === area ? null : area;
  render();
  requestAnimationFrame(() =>
    area === "note" ? editors.focus() : reader.focus(),
  );
}
async function openRecent(index: number) {
  const pair = prefs.recent[index];
  if (!pair) return;
  if (!(await allowDiscard())) return;
  // Resolve both files before replacing the visible workspace.
  let original: OpenFile | null = null;
  let markdown: OpenFile | null = null;
  let url = "";
  if (pair.reading) {
    if (/^https?:/i.test(pair.reading)) url = pair.reading;
    else original = await api.openPath(pair.reading);
  }
  if (pair.note) markdown = await api.openPath(pair.note);
  if (original) await adopt(original);
  else if (url) await navigate(url);
  else await closeReading();
  if (markdown) {
    note = null;
    untitled = false;
    await adopt(markdown);
  } else {
    note = null;
    untitled = false;
    editors.setFile("", null);
    noteVersion = 0;
    savedVersion = 0;
    api.setDirty(false);
  }
  remember();
  render();
}
async function navigate(url: string) {
  savePosition();
  reader.clear();
  reading = null;
  website = url;
  active = "reading";
  selectedTab = "reading";
  maximized = null;
  render();
  await api.webOpen(url);
  webBounds();
  remember();
}
async function openWeb() {
  const result = await ask(
    "打开网页",
    '<label class="field">网址<input id="web-input" type="text" placeholder="example.com（自动补全 https://）" autofocus></label>',
    [
      { label: "取消", value: "cancel" },
      { label: "打开", value: "open", primary: true },
    ],
  );
  if (result === "open") {
    const value = $<HTMLInputElement>("web-input").value;
    if (value.trim()) await navigate(value.trim());
  }
}
async function switchDocumentTab(path: string) {
  if (note?.path === path || reading?.path === path) return;
  await adopt(await api.openPath(path));
}
async function closeDocumentTab(path: string) {
  const target = openTabs.find((item) => item.path === path);
  if (!target) return;
  if (reading?.path === path) await closeReading();
  else if (note?.path === path) {
    await closeNote();
    if (note?.path === path) return;
  }
  openTabs = openTabs.filter((item) => item.path !== path);
  const fallback = [...openTabs].reverse().find((item) => item.kind === target.kind);
  if (fallback) await switchDocumentTab(fallback.path);
  render();
}
function renderOpenTabs() {
  const root = $("open-document-tabs");
  root.replaceChildren();
  for (const tab of openTabs) {
    const button = document.createElement("button");
    button.className = "document-tab";
    button.classList.toggle("selected", note?.path === tab.path || reading?.path === tab.path);
    button.title = tab.path;
    const label = document.createElement("span");
    label.textContent = tab.name;
    const close = document.createElement("span");
    close.className = "tab-close";
    close.textContent = "×";
    close.title = `关闭 ${tab.name}`;
    close.onclick = (event) => {
      event.stopPropagation();
      void run(() => closeDocumentTab(tab.path));
    };
    button.append(label, close);
    button.onclick = () => void run(() => switchDocumentTab(tab.path));
    root.append(button);
  }
  root.hidden = openTabs.length === 0;
}
function renderToolbar() {
  $("dirty-dot").hidden = !isDirty();
  $<HTMLButtonElement>("save").disabled = !hasNote();
  $<HTMLButtonElement>("close-note").disabled = !hasNote();
  $<HTMLButtonElement>("close-reading").disabled = !hasReading();
  $("window-title").textContent =
    reading?.name ||
    (website ? webTitle || website : note?.name) ||
    (untitled ? "未命名笔记" : "阅读，思考，写下笔记");
  $("note-title").textContent =
    note?.name || (untitled ? "未命名笔记" : "Markdown 笔记");
  $("reading-title").textContent = reading?.name || webTitle || "阅读原文";
  $("visual-mode").classList.toggle("selected", editors.mode === "visual");
  $("source-mode").classList.toggle("selected", editors.mode === "source");
  $("source-menu").hidden = editors.mode !== "source" && !editors.both;
  $("note-max").textContent = maximized === "note" ? "⤡ 还原" : "⤢ 满屏";
  $("reading-max").textContent = maximized === "reading" ? "⤡ 还原" : "⤢ 满屏";
  $("layout").textContent = prefs?.layout === "tabs" ? "并排显示" : "切换显示";
  $("layout-label").textContent =
    prefs?.layout === "tabs" ? "切换显示" : "原文与笔记，并排思考";
  $("tab-reading").classList.toggle("selected", selectedTab === "reading");
  $("tab-note").classList.toggle("selected", selectedTab === "note");
  $("note-pane").classList.toggle("active", active === "note");
  $("reading-pane").classList.toggle("active", active === "reading");
  const epub = reading?.format === "epub";
  $<HTMLButtonElement>("add-annotation").disabled = !epub || !epubSelection;
  $<HTMLButtonElement>("show-annotations").disabled = !epub;
  $("annotation-count").textContent = String(currentAnnotations().length);
  renderOpenTabs();
}
function render() {
  if (!prefs) return;
  const original = hasReading();
  const both = !original && hasNote() && prefs.layout === "split" && !maximized;
  editors.setBoth(both);
  const showReading =
    original &&
    (maximized
      ? maximized === "reading"
      : prefs.layout === "split" || selectedTab === "reading");
  const showNote = maximized
    ? maximized === "note"
    : !original || prefs.layout === "split" || selectedTab === "note";
  $("reading-pane").hidden = !showReading;
  $("note-pane").hidden = !showNote;
  $("splitter").hidden = !showReading || !showNote;
  $("workspace-tabs").hidden = prefs.layout !== "tabs" || !original;
  $("note-content").classList.toggle("both", both);
  $("visual-host").hidden = !hasNote() || (!both && editors.mode !== "visual");
  $("source-host").hidden = !hasNote() || (!both && editors.mode !== "source");
  $("note-splitter").hidden = !both;
  $("note-empty").hidden = hasNote();
  $("reading-body").hidden = !!website;
  $("web-surface").hidden = !website;
  $("webbar").hidden = !website;
  $<HTMLInputElement>("page").disabled =
    !reading || !["pdf", "docx"].includes(reading.format);
  const epubReading = reading?.format === "epub";
  $("read-prev").title = epubReading ? "上一节（←）" : "上一页";
  $("read-next").title = epubReading ? "下一节（→）" : "下一页";
  $("page").setAttribute(
    "aria-label",
    epubReading ? "EPUB 章节位置" : "阅读页码",
  );
  $("page-total").hidden = !!website;
  $("fit-width").hidden = reading?.format !== "pdf";
  $("fit-height").hidden = reading?.format !== "pdf";
  $("fit-best").hidden = reading?.format !== "pdf";
  $("workspace").style.gridTemplateColumns =
    showReading && showNote
      ? `minmax(0,${prefs.splitRatio}fr) 6px minmax(0,${1 - prefs.splitRatio}fr)`
      : "minmax(0,1fr)";
  $("note-content").style.gridTemplateColumns = both
    ? `minmax(0,${prefs.splitRatio}fr) 6px minmax(0,${1 - prefs.splitRatio}fr)`
    : "minmax(0,1fr)";
  $("sidebar").hidden = sidebarHidden;
  $("side-resizer").hidden = sidebarHidden;
  $("show-sidebar").hidden = !sidebarHidden;
  document.documentElement.style.setProperty(
    "--sidebar-width",
    `${prefs.sidebarWidth}px`,
  );
  $<HTMLInputElement>("zoom").value = String(
    Math.round(prefs.readingZoom * 10) / 10,
  );
  $<HTMLInputElement>("syntax-color").checked = prefs.syntax;
  $<HTMLInputElement>("whitespace").checked = prefs.whitespace;
  editors.configure(prefs.syntax, prefs.whitespace, prefs.styles.source);
  const style = prefs.styles.visual;
  $("visual-host").style.setProperty("--body-size", `${style.fontSize}px`);
  $("visual-host").style.setProperty("--line-height", String(style.lineHeight));
  $("visual-host").style.setProperty("--content-width", `${style.width}px`);
  $("visual-host").classList.toggle("justified", style.justify);
  applyVisualStyle($("visual-host"), style);
  renderToolbar();
  renderSidebar();
  requestAnimationFrame(() => {
    editors.source.requestMeasure();
    webBounds();
  });
}
function itemButton(
  label: string,
  subtitle: string,
  click: () => void,
  depth = 0,
) {
  const button = document.createElement("button");
  button.className = "side-item";
  button.style.paddingLeft = `${12 + depth * 12}px`;
  const title = document.createElement("span");
  title.textContent = label;
  button.append(title);
  if (subtitle) {
    const sub = document.createElement("small");
    sub.textContent = subtitle;
    button.append(sub);
  }
  button.onclick = click;
  return button;
}
function renderSidebar() {
  if (!prefs) return;
  const root = $("side-content");
  root.replaceChildren();
  const headings: Record<string, string> = {
    files: "文件",
    reading: "原文目录",
    outline: "Markdown 目录",
    bookmarks: "网页收藏",
  };
  $("side-title").textContent = headings[side];
  document
    .querySelectorAll("[data-side]")
    .forEach((el) =>
      el.classList.toggle(
        "selected",
        (el as HTMLElement).dataset.side === side,
      ),
    );
  const heading = (text: string) => {
    const el = document.createElement("h3");
    el.textContent = text;
    root.append(el);
  };
  if (side === "files") {
    $<HTMLButtonElement>("import-workspace").disabled = !workspaceProject;
    if (workspaceProject) {
      heading(workspaceProject.name);
      const groups = new Map<string, typeof workspaceProject.files>();
      for (const file of workspaceProject.files) {
        const group = file.relativePath.split(/[\\/]/)[0] || "其它";
        groups.set(group, [...(groups.get(group) ?? []), file]);
      }
      for (const [group, files] of groups) {
        heading(group);
        for (const file of files) {
          const relative = file.relativePath.split(/[\\/]/).slice(1).join(" / ") || file.name;
          const button = itemButton(
            relative,
            file.kind === "reading" ? "阅读资料" : "Markdown 笔记",
            () => void run(async () => adopt(await api.openPath(file.path))),
            1,
          );
          button.title = `${file.relativePath}\n右键可移到回收站`;
          button.oncontextmenu = (event) => {
            event.preventDefault();
            void run(async () => {
              const result = await ask(
                "将文件移到回收站？",
                `<p>“${escape(file.relativePath)}”将从当前 Workspace 移到系统回收站。</p>`,
                [
                  { label: "取消", value: "cancel" },
                  { label: "移到回收站", value: "trash", primary: true },
                ],
              );
              if (result !== "trash" || !workspaceProject) return;
              if (note?.path === file.path || reading?.path === file.path) {
                await closeDocumentTab(file.path);
                if (note?.path === file.path || reading?.path === file.path) return;
              }
              workspaceProject = await api.trashWorkspaceFile(workspaceProject.manifestPath, file.path);
              openTabs = openTabs.filter((tab) => tab.path !== file.path);
              render();
            });
          };
          root.append(button);
        }
      }
    } else if (folder) {
      heading(folder.name);
      for (const file of folder.files)
        root.append(
          itemButton(
            file.name,
            "",
            () => void run(async () => adopt(await api.openPath(file.path))),
          ),
        );
    }
    heading(workspaceProject ? "最近使用" : "最近使用 · 可先新建或打开 Workspace");
    if (!prefs.recent.length) {
      const p = document.createElement("p");
      p.className = "side-empty";
      p.textContent = "打开过的原文与笔记组合会保存在这里。";
      root.append(p);
    }
    prefs.recent.forEach((pair, i) =>
      root.append(
        itemButton(
          basename(pair.reading || pair.note || ""),
          pair.reading && pair.note
            ? `＋ ${basename(pair.note)}`
            : pair.note
              ? "Markdown 笔记"
              : "阅读原文",
          () => void run(() => openRecent(i)),
        ),
      ),
    );
  } else if (side === "outline") {
    for (const heading of editors.outline())
      root.append(
        itemButton(
          heading.title,
          "",
          () => {
            void run(async () => {
              if (prefs.layout === "tabs") await selectArea("note");
              editors.jump(heading.line);
            });
          },
          heading.level - 1,
        ),
      );
    if (!root.children.length) root.textContent = "笔记标题会显示在这里。";
  } else if (side === "reading") {
    if (toc.length)
      for (const item of toc)
        root.append(
          itemButton(
            item.title,
            "",
            () => void run(() => reader.chapter(item.href)),
            item.depth,
          ),
        );
    else
      root.append(
        itemButton(
          reading?.name || webTitle || "尚未打开原文",
          reading?.format === "docx" ? "只读排版预览" : "",
          () => void run(() => selectArea("reading")),
        ),
      );
  } else {
    for (const item of prefs.bookmarks) {
      const row = document.createElement("div");
      row.className = "bookmark-row";
      row.append(
        itemButton(
          item.title,
          item.url,
          () => void run(() => navigate(item.url)),
        ),
      );
      const remove = document.createElement("button");
      remove.className = "remove-bookmark";
      remove.textContent = "×";
      remove.title = "删除收藏";
      remove.onclick = () => {
        prefs.bookmarks = prefs.bookmarks.filter((x) => x !== item);
        persist();
        renderSidebar();
      };
      row.append(remove);
      root.append(row);
    }
    if (!root.children.length)
      root.textContent = "在阅读网页时点击 ☆ 添加收藏。";
  }
}
async function zoom(value: number) {
  prefs.readingZoom = Math.max(
    25,
    Math.min(400, Number.isFinite(value) ? value : 100),
  );
  $<HTMLInputElement>("zoom").value = String(
    Math.round(prefs.readingZoom * 10) / 10,
  );
  if (website) await api.webAction("zoom", prefs.readingZoom / 100);
  else await reader.setZoom(prefs.readingZoom);
  persist();
}
async function settings() {
  const drafts = structuredClone(prefs.styles);
  const initial = active === "reading" ? "reading" : editors.mode;
  const color = (id: string, label: string) =>
    '<label class="field">' +
    label +
    '<input id="style-' +
    id +
    '" type="color"></label>';
  const content =
    '<label class="field">调整的视图<select id="style-scope"><option value="reading">阅读区（EPUB）</option><option value="visual">Markdown 可视化</option><option value="source">Markdown 源码</option></select></label><p class="muted">三套样式独立保存。PDF、Word、网页保留原文排版，请使用缩放。字体使用本机已安装字体，缺失时自动回退。</p><div class="style-grid"><label class="field">字体<select id="style-font"><option value="system-ui">系统字体</option><option value="sans-serif">无衬线</option><option value="serif">衬线</option><option value="monospace">等宽</option><option value="Microsoft YaHei">微软雅黑</option><option value="SimSun">宋体</option><option value="KaiTi">楷体</option></select></label><label class="field">正文字号（px）<input id="style-size" type="number" min="12" max="40"></label>' +
    color("color", "正文颜色") +
    color("background", "背景颜色") +
    '<label class="field">行距倍数<input id="style-line" type="number" min="1.2" max="2.5" step="0.1"></label><label class="field">内容宽度（px）<input id="style-width" type="number" min="420" max="1600"></label></div><p id="source-style-hint" class="muted" hidden>源码保持原始文本等大字号；标题与加粗可独立着色，不改变行高。</p><div id="rich-style"><label class="check"><input id="style-justify" type="checkbox">正文两端对齐</label><div class="style-grid"><label class="field">段落间距（em）<input id="style-paragraph" type="number" min="0" max="3" step="0.1"></label><label class="field">加粗字号（px，Markdown）<input id="style-strong-size" type="number" min="12" max="72"></label>' +
    color("strong-color", "加粗颜色") +
    '</div><details><summary>标题 1–6 的字号与颜色</summary><div class="style-grid">' +
    [1, 2, 3, 4, 5, 6]
      .map(
        (i) =>
          '<label class="field">标题 ' +
          i +
          ' 字号<input id="style-h' +
          i +
          '" type="number" min="12" max="96"></label>' +
          color("h" + i + "-color", "标题 " + i + " 颜色"),
      )
      .join("") +
    "</div></details></div>";
  const promise = ask("独立样式设置", content, [
    { label: "取消", value: "cancel" },
    { label: "应用", value: "apply", primary: true },
  ]);
  const scope = $<HTMLSelectElement>("style-scope");
  scope.value = initial;
  let previous = initial as keyof typeof drafts;
  const input = (id: string) => $<HTMLInputElement>("style-" + id);
  const number = (id: string, fallback: number, min: number, max: number) => {
    const value = input(id).value === "" ? fallback : Number(input(id).value);
    return Number.isFinite(value)
      ? Math.max(min, Math.min(max, value))
      : fallback;
  };
  const stash = () => {
    const old = drafts[previous];
    drafts[previous] = {
      ...old,
      fontSize: number("size", 20, 12, 40),
      lineHeight: number("line", 1.7, 1.2, 2.5),
      width: number("width", 900, 420, 1600),
      fontFamily: $<HTMLSelectElement>("style-font").value,
      color: input("color").value,
      background: input("background").value,
      justify: previous !== "source" && input("justify").checked,
      paragraphSpacing: number("paragraph", 0.6, 0, 3),
      strongSize: number("strong-size", 18, 12, 72),
      strongColor: input("strong-color").value,
      headings: [1, 2, 3, 4, 5, 6].map((i) => ({
        size: number("h" + i, [52, 40, 36, 28, 24, 20][i - 1], 12, 96),
        color: input("h" + i + "-color").value,
      })),
    };
  };
  const load = () => {
    const st = drafts[scope.value as keyof typeof drafts];
    input("size").value = String(st.fontSize);
    input("line").value = String(st.lineHeight);
    input("width").value = String(st.width);
    $<HTMLSelectElement>("style-font").value = st.fontFamily ?? "system-ui";
    input("color").value = st.color ?? "#37434d";
    input("background").value = st.background ?? "#ffffff";
    input("justify").checked = st.justify;
    input("paragraph").value = String(st.paragraphSpacing ?? 0.6);
    input("strong-size").value = String(st.strongSize ?? 18);
    input("strong-color").value = st.strongColor ?? "#087b72";
    for (let i = 1; i <= 6; i++) {
      input("h" + i).value = String(
        st.headings?.[i - 1]?.size ?? [52, 40, 36, 28, 24, 20][i - 1],
      );
      input("h" + i + "-color").value =
        st.headings?.[i - 1]?.color ?? "#0498b7";
    }
    $("rich-style").hidden = false;
    for (const id of [
      "paragraph",
      "strong-size",
      "justify",
      ...Array.from({ length: 6 }, (_, i) => "h" + (i + 1)),
    ])
      input(id).disabled = scope.value === "source";
    $("source-style-hint").hidden = scope.value !== "source";
  };
  scope.onchange = () => {
    stash();
    previous = scope.value as keyof typeof drafts;
    load();
  };
  load();
  if ((await promise) === "apply") {
    stash();
    prefs.styles = drafts;
    persist();
    render();
    reader.setStyle(prefs.styles.reading);
  }
}

function splitDrag(element: HTMLElement, parent: HTMLElement) {
  drag(
    element,
    (x) => {
      const r = parent.getBoundingClientRect();
      prefs.splitRatio = Math.max(0.2, Math.min(0.8, (x - r.left) / r.width));
      parent.style.gridTemplateColumns = `minmax(0,${prefs.splitRatio}fr) 6px minmax(0,${1 - prefs.splitRatio}fr)`;
      editors.source.requestMeasure();
      webBounds();
    },
    () => {
      persist();
      webBounds();
    },
  );
}
splitDrag($("splitter"), $("workspace"));
splitDrag($("note-splitter"), $("note-content"));
drag(
  $("side-resizer"),
  (x) => {
    prefs.sidebarWidth = Math.max(180, Math.min(420, x - 56));
    document.documentElement.style.setProperty(
      "--sidebar-width",
      `${prefs.sidebarWidth}px`,
    );
    webBounds();
  },
  () => persist(),
);
const commands: Record<string, () => Promise<void> | void> = {
  "zoom-in": () => zoom(prefs.readingZoom + 10),
  "zoom-out": () => zoom(prefs.readingZoom - 10),
  open,
  folder: async () => {
    const result = await api.openFolder();
    if (result) {
      folder = result;
      side = "files";
      renderSidebar();
    }
  },
  new: createNote,
  save: async () => {
    await save();
  },
  "save-as": async () => {
    await save(true);
  },
  mode: () => switchMode(editors.mode === "visual" ? "source" : "visual"),
  focus: () => selectArea(active === "reading" ? "note" : "reading"),
  layout: changeLayout,
  maximize: () => maximize(active),
  find: async () => {
    if (active !== "note") return;
    if (editors.mode === "source") {
      editors.find();
      return;
    }
    const answer = ask(
      "查找文字",
      '<input id="find-text" aria-label="查找文字" autofocus>',
      [
        { value: "cancel", label: "取消" },
        { value: "find", label: "查找" },
      ],
    );
    if ((await answer) === "find")
      editors.find($<HTMLInputElement>("find-text").value);
  },
  "close-active": () => {
    if (active === "reading" && reading?.path) return closeDocumentTab(reading.path);
    if (active === "note" && note?.path) return closeDocumentTab(note.path);
    return active === "reading" ? closeReading() : closeNote();
  },
  "close-window": async () => {
    if (await allowDiscard()) {
      savePosition();
      clearTimeout(settingsTimer);
      await api.storePreferences(prefs);
      api.readyToClose();
    }
  },
};
function bind(id: string, action: () => Promise<void> | void) {
  $(id).onclick = () => void run(action);
}
bind("fit-width", async () => zoom(await reader.fit("width")));
bind("fit-height", async () => zoom(await reader.fit("height")));
bind("fit-best", async () => {
  const result = await reader.best();
  await zoom(result.zoom);
  notify(result.reason);
});
bind("new-workspace", newWorkspace);
bind("open-workspace", openWorkspace);
bind("import-workspace", importWorkspace);
bind("open-file", open);
bind("open-folder", commands.folder);
bind("new-note", createNote);
bind("save", commands.save);
bind("close-reading", () =>
  reading?.path ? closeDocumentTab(reading.path) : closeReading(),
);
bind("close-note", () => (note?.path ? closeDocumentTab(note.path) : closeNote()));
bind("layout", changeLayout);
bind("open-web", openWeb);
bind("style", settings);
bind("settings", settings);
bind("reading-max", () => maximize("reading"));
bind("note-max", () => maximize("note"));
bind("tab-reading", () => selectArea("reading"));
bind("tab-note", () => selectArea("note"));
bind("visual-mode", () => switchMode("visual"));
bind("source-mode", () => switchMode("source"));
bind("read-prev", () => reader.previous());
bind("read-next", () => reader.next());
bind("add-annotation", () => editAnnotation());
bind("show-annotations", showAnnotations);
bind("zoom-in", () => zoom(prefs.readingZoom + 10));
bind("zoom-out", () => zoom(prefs.readingZoom - 10));
bind("hide-sidebar", () => {
  sidebarHidden = true;
  render();
});
bind("show-sidebar", () => {
  sidebarHidden = false;
  render();
});
for (const el of Array.from(
  document.querySelectorAll<HTMLElement>("[data-side]"),
))
  el.onclick = () => {
    side = el.dataset.side!;
    sidebarHidden = false;
    render();
  };
for (const el of Array.from(
  document.querySelectorAll<HTMLElement>("[data-action]"),
))
  el.onclick = () => void run(commands[el.dataset.action!]);
$<HTMLInputElement>("page").onchange = (event) =>
  reader.goPage(Number((event.target as HTMLInputElement).value));
$<HTMLInputElement>("zoom").onchange = (event) =>
  void run(() => zoom(Number((event.target as HTMLInputElement).value)));
$<HTMLInputElement>("syntax-color").onchange = (event) => {
  prefs.syntax = (event.target as HTMLInputElement).checked;
  persist();
  editors.configure(prefs.syntax, prefs.whitespace, prefs.styles.source);
};
$<HTMLInputElement>("whitespace").onchange = (event) => {
  prefs.whitespace = (event.target as HTMLInputElement).checked;
  persist();
  editors.configure(prefs.syntax, prefs.whitespace, prefs.styles.source);
};
const syntaxActions = [
  ["paragraph", "段落"],
  ["h1", "标题 1"],
  ["h2", "标题 2"],
  ["h3", "标题 3"],
  ["h4", "标题 4"],
  ["h5", "标题 5"],
  ["h6", "标题 6"],
  ["bold", "加粗"],
  ["italic", "斜体"],
  ["underline", "下划线"],
  ["strike", "删除线"],
  ["bullet", "无序列表"],
  ["ordered", "有序列表"],
  ["quote", "引用"],
  ["code", "行内代码"],
  ["rule", "分隔线"],
  ["table", "表格"],
  ["link", "链接"],
];
const syntaxKeys: Record<string, string> = {
  bold: "B",
  italic: "I",
  underline: "U",
  strike: "Shift+X",
  paragraph: "Alt+0",
  h1: "Alt+1",
  h2: "Alt+2",
  h3: "Alt+3",
  h4: "Alt+4",
  h5: "Alt+5",
  h6: "Alt+6",
};
const modifierLabel = /Mac/.test(navigator.platform) ? "Cmd" : "Ctrl";
for (const [action, title] of syntaxActions) {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = title;
  if (syntaxKeys[action]) {
    const hint = document.createElement("span");
    hint.className = "shortcut-key";
    hint.textContent = modifierLabel + "+" + syntaxKeys[action];
    button.append(hint);
    button.title = title + " · " + hint.textContent;
  }
  button.onmousedown = (event) => event.preventDefault();
  button.onclick = () => {
    $<HTMLDetailsElement>("syntax-menu").open = false;
    if (hasNote()) {
      active = "note";
      editors.apply(action);
    }
  };
  $("syntax-items").append(button);
}
$<HTMLFormElement>("address-form").onsubmit = (event) => {
  event.preventDefault();
  void run(() => navigate($<HTMLInputElement>("address").value));
};
bind("web-back", () => api.webAction("back") as Promise<void>);
bind("web-forward", () => api.webAction("forward") as Promise<void>);
bind("web-reload", () => api.webAction("reload") as Promise<void>);
bind("bookmark", () => {
  if (!website) return;
  const existing = prefs.bookmarks.find((x) => x.url === website);
  if (existing) prefs.bookmarks = prefs.bookmarks.filter((x) => x !== existing);
  else prefs.bookmarks.unshift({ title: webTitle || website, url: website });
  persist();
  renderSidebar();
  $("bookmark").textContent = existing ? "☆" : "★";
});
bind("clip", async () => {
  const text = await api.webAction("selection");
  if (!text) {
    notify("请先在网页中选中文字。");
    return;
  }
  if (!hasNote()) await createNote();
  if (!hasNote()) return;
  const append = `\n\n> ${String(text).split("\n").join("\n> ")}\n\n来源：[${webTitle || website}](${website})\n`;
  const content = await commit();
  editors.setFile(content + append, note?.id ?? null);
  changed();
  active = "note";
  selectedTab = "note";
  render();
});
api.onCommand((command) => {
  if (commands[command]) void run(commands[command]);
});
api.onFile((file) => void run(() => adopt(file)));
api.onWeb((state) => {
  if (state.url) website = state.url;
  webTitle = state.title;
  $<HTMLInputElement>("address").value = state.url || website;
  $("reading-title").textContent = state.title || "网页";
  $("reading-status").textContent =
    state.error || (state.loading ? "正在加载…" : "");
  $("bookmark").textContent = prefs.bookmarks.some((x) => x.url === website)
    ? "★"
    : "☆";
  renderToolbar();
});
window.addEventListener("resize", () => {
  webBounds();
  editors.source.requestMeasure();
});
new ResizeObserver(webBounds).observe($("web-surface"));
$("note-content").addEventListener(
  "keydown",
  (event) => {
    if (modal || event.isComposing || !(event.ctrlKey || event.metaKey)) return;
    const key = event.key.toLowerCase();
    let action: string | undefined;
    if (event.altKey && /^[0-6]$/.test(event.code.replace("Digit", ""))) {
      const level = event.code.replace("Digit", "");
      action = level === "0" ? "paragraph" : "h" + level;
    } else if (!event.altKey && !event.shiftKey)
      action = (
        { b: "bold", i: "italic", u: "underline" } as Record<string, string>
      )[key];
    else if (!event.altKey && event.shiftKey && key === "x") action = "strike";
    if (action && hasNote()) {
      event.preventDefault();
      event.stopPropagation();
      editors.apply(action);
    }
  },
  true,
);
window.addEventListener("keydown", (event) => {
  if (modal) return;
  if (
    active === "reading" &&
    reading?.format === "epub" &&
    event.ctrlKey &&
    event.altKey &&
    event.key.toLowerCase() === "m"
  ) {
    event.preventDefault();
    void run(() => (event.shiftKey ? showAnnotations() : editAnnotation()));
    return;
  }
  if (event.key === "Escape" && maximized) {
    maximized = null;
    render();
    return;
  }
  if (
    active === "reading" &&
    reading?.format === "epub" &&
    ["ArrowLeft", "ArrowRight"].includes(event.key) &&
    !event.ctrlKey &&
    !event.altKey &&
    !event.shiftKey &&
    !event.metaKey &&
    !(event.target as HTMLElement).closest("input,textarea,[contenteditable=true]")
  ) {
    event.preventDefault();
    void run(() =>
      event.key === "ArrowRight" ? reader.next() : reader.previous(),
    );
  }
});
$("note-pane").addEventListener("pointerdown", () => {
  active = "note";
  renderToolbar();
});
$("reading-pane").addEventListener("pointerdown", () => {
  active = "reading";
  renderToolbar();
});
window.addEventListener("beforeunload", () => {
  clearTimeout(recoveryTimer);
  clearTimeout(settingsTimer);
});
async function init() {
  if (!api) {
    $("status").textContent = "请从 Markdown Studio 桌面程序启动。";
    return;
  }
  prefs = await api.preferences();
  if (prefs.workspace) {
    try {
      workspaceProject = await api.openWorkspace(prefs.workspace);
    } catch {
      prefs.workspace = null;
      persist();
    }
  }
  editors.setFile("", null);
  render();
  const recovery = await api.readRecovery();
  if (recovery) {
    const answer = await ask(
      "发现未保存的笔记",
      "<p>上次退出前有未保存的内容。恢复后会作为独立笔记打开，不会覆盖磁盘文件。</p>",
      [
        { label: "保留稍后恢复", value: "cancel" },
        { label: "恢复", value: "restore", primary: true },
      ],
    );
    if (answer === "restore") {
      untitled = true;
      note = null;
      saved = "";
      editors.setFile(recovery.content, null);
      noteVersion = 1;
      savedVersion = 0;
      api.setDirty(true);
      render();
      notify("已恢复为未命名笔记，请另存为文件。");
    }
  }
}
queue = init().catch((error) => notify(error.message));

import test, { after } from "node:test";
import assert from "node:assert/strict";
import { JSDOM } from "jsdom";
import { build } from "esbuild";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
const dom = new JSDOM(
  '<!doctype html><div id="visual"></div><div id="source"></div>',
  { pretendToBeVisual: true, url: "https://studio.test/" },
);
for (const key of [
  "window",
  "document",
  "Node",
  "Element",
  "HTMLElement",
  "MutationObserver",
  "DOMParser",
  "getComputedStyle",
  "requestAnimationFrame",
  "cancelAnimationFrame",
  "navigator",
])
  Object.defineProperty(globalThis, key, {
    value:
      key === "requestAnimationFrame"
        ? () => 0
        : key === "cancelAnimationFrame"
          ? () => {}
          : key === "getComputedStyle"
            ? dom.window.getComputedStyle.bind(dom.window)
            : dom.window[key],
    configurable: true,
    writable: true,
  });
globalThis.ResizeObserver = class {
  observe() {}
  unobserve() {}
  disconnect() {}
};
const bundled = path.join(os.tmpdir(), `studio-editor-${process.pid}.mjs`);
await build({
  entryPoints: ["src/markdown.ts"],
  absWorkingDir: process.cwd(),
  outfile: bundled,
  bundle: true,
  format: "esm",
  platform: "node",
  packages: "bundle",
  logLevel: "silent",
});
const { MarkdownEditors, visualLimitation, semanticSource, nearestOccurrence } =
  await import(bundled);
const editors = new MarkdownEditors(
  document.getElementById("visual"),
  document.getElementById("source"),
  () => {},
  () => {},
  async () => null,
);
after(async () => {
  editors.source.destroy();
  editors.visual.destroy();
  dom.window.close();
  await fs.rm(bundled, { force: true });
});
test("switching unedited visual and source modes never rewrites original bytes", () => {
  const source = "##### 联系强度\r\n\r\n**联系）** 与 <u>下划线</u> 保留。\r\n";
  editors.setFile(source, null);
  editors.switchMode("source");
  assert.equal(editors.text(), source.replaceAll("\r\n", "\n"));
  editors.switchMode("visual");
  assert.equal(editors.text(), source.replaceAll("\r\n", "\n"));
});
test("visual bold and underline remain inline in one paragraph after serialization", () => {
  editors.mode = "visual";
  editors.setFile("这段联系（tie）文字保持同一段。", null);
  editors.visual.commands.setTextSelection({ from: 3, to: 10 });
  editors.apply("bold");
  editors.visual.commands.setTextSelection({ from: 11, to: 13 });
  editors.apply("underline");
  const source = editors.text();
  assert.match(source, /\*\*|<strong>/);
  assert.match(source, /<u>/);
  assert.equal(source.split("\n\n").length, 1);
  const json = editors.visual.getJSON();
  editors.switchMode("source");
  editors.switchMode("visual");
  assert.deepEqual(editors.visual.getJSON(), json);
});
test("fifth-level heading after a bullet list exits list nesting and retains heading syntax", () => {
  editors.mode = "visual";
  editors.setFile("- 列表文字", null);
  editors.visual.commands.setTextSelection(4);
  editors.apply("h5");
  const source = editors.text();
  assert.match(source.trim(), /^##### 列表文字$/);
  assert.doesNotMatch(source, /\*\*/);
  editors.switchMode("source");
  editors.switchMode("visual");
  assert.equal(editors.visual.getJSON().content[0].type, "heading");
  assert.equal(editors.visual.getJSON().content[0].attrs.level, 5);
});
test("unsupported constructs block visual mutation instead of silently losing source", () => {
  for (const source of [
    "---\ntitle: test\n---\n",
    "正文[^1]\n\n[^1]: 注释",
    "- [x] 事项",
    "<div>html</div>",
  ]) {
    assert.ok(visualLimitation(source));
    editors.mode = "visual";
    editors.setFile(source, null);
    assert.equal(editors.visual.isEditable, false);
    editors.apply("bold");
    assert.equal(editors.text(), source);
  }
});
test("long source documents keep direct left/right and undo state, without source truncation", () => {
  const source = Array.from(
    { length: 2500 },
    (_, i) => `第 ${i + 1} 行：中文与 abc，**强调**。`,
  ).join("\n");
  editors.mode = "source";
  editors.setFile(source, null);
  const at = editors.source.state.doc.line(2400).from;
  editors.source.dispatch({
    selection: { anchor: at },
    changes: { from: at, insert: "新增" },
  });
  assert.equal(editors.source.state.doc.lines, 2500);
  assert.equal(
    editors.source.state.doc.line(2400).text.startsWith("新增"),
    true,
  );
  assert.equal(editors.text().length, source.length + 2);
});
test("syntax highlighting stays configured after source insertions", () => {
  editors.configure(true, true, {
    fontSize: 18,
    lineHeight: 1.7,
    width: 900,
    justify: false,
  });
  editors.mode = "source";
  editors.setFile("## heading\n\n**bold**", null);
  editors.source.dispatch({
    changes: { from: editors.source.state.doc.length, insert: "\n**new**" },
  });
  assert.ok(editors.source.state.doc.toString().endsWith("**new**"));
  assert.equal(editors.source.state.doc.lines, 4);
});

test("bold around Chinese and English closing parentheses survives a fresh parse", () => {
  for (const phrase of [
    "影响者营销（influencer marketing）",
    "影响者营销 (influencer marketing)",
    "联系",
  ]) {
    editors.mode = "visual";
    editors.setFile("采用" + phrase + "模式。", null);
    editors.visual.commands.setTextSelection({
      from: 3,
      to: 3 + phrase.length,
    });
    editors.apply("bold");
    const json = editors.visual.getJSON();
    const source = editors.text();
    editors.setFile(source, null);
    assert.deepEqual(editors.visual.getJSON(), json);
  }
});
test("loading a file and rendering readonly state do not signal document modifications", () => {
  let updates = 0;
  const instance = new MarkdownEditors(
    document.createElement("div"),
    document.createElement("div"),
    () => updates++,
    () => {},
    async () => null,
  );
  instance.setFile("内容", null);
  instance.setFile("", null);
  assert.equal(updates, 0);
  instance.visual.destroy();
  instance.source.destroy();
});

test("semantic cursor anchors retain the exact offset across headings, bold and underline", () => {
  const source =
    "##### 联系强度\n\n采用<strong>影响者营销（influencer marketing）</strong>模式，<u>下划线</u>。";
  const semantic = semanticSource(source);
  const offset = semantic.text.indexOf("marketing") + 4;
  assert.equal(
    source.slice(semantic.offsets[offset], semantic.offsets[offset] + 6),
    "eting）",
  );
  assert.equal(semantic.text.includes("<strong>"), false);
  assert.equal(semantic.text.startsWith("联系强度"), true);
});
test("overlapping underline and bold marks do not create paragraphs or lose content", () => {
  editors.mode = "visual";
  editors.setFile("连续文本包含加粗与下划线。", null);
  editors.visual.commands.setTextSelection({ from: 3, to: 10 });
  editors.apply("bold");
  editors.visual.commands.setTextSelection({ from: 6, to: 12 });
  editors.apply("underline");
  const json = editors.visual.getJSON();
  const source = editors.text();
  assert.equal(source.split("\n\n").length, 1);
  editors.setFile(source, null);
  assert.deepEqual(editors.visual.getJSON(), json);
});

test("repeated paragraph anchors choose the nearby occurrence instead of jumping to the first", () => {
  const text = "相同段落文字。\n\n".repeat(2500);
  const at = nearestOccurrence(text, "相同段落文字。", 0.999);
  assert.ok(at > text.length * 0.99);
  assert.equal(nearestOccurrence(text, "不存在", 0.5), -1);
});

test("long-document cursor returns to the exact source character after a visual round trip", () => {
  const frames = [];
  const previous = globalThis.requestAnimationFrame;
  globalThis.requestAnimationFrame = (callback) => {
    frames.push(callback);
    return frames.length;
  };
  dom.window.HTMLElement.prototype.scrollIntoView = function () {};
  try {
    const text = Array.from(
      { length: 2500 },
      (_, i) => `第${i + 1}段 内容**加粗（tie）**与<u>下划线</u>。`,
    ).join("\n\n");
    editors.mode = "source";
    editors.setFile(text, null);
    const head = text.indexOf("第2497段") + "第2497段 内容**加".length;
    editors.source.dispatch({ selection: { anchor: head } });
    editors.switchMode("visual");
    frames.pop()(0);
    assert.match(
      editors.visual.state.selection.$from.parent.textContent,
      /^第2497段/,
    );
    editors.switchMode("source");
    frames.pop()(0);
    assert.equal(editors.source.state.selection.main.head, head);
    assert.equal(editors.text(), text);
  } finally {
    globalThis.requestAnimationFrame = previous;
  }
});

test("identical paragraphs near document end retain their occurrence and exact caret", () => {
  const frames = [];
  const previous = globalThis.requestAnimationFrame;
  globalThis.requestAnimationFrame = (callback) => {
    frames.push(callback);
    return frames.length;
  };
  dom.window.HTMLElement.prototype.scrollIntoView = function () {};
  try {
    const paragraph = "完全重复的**加粗文字**与<u>下划线</u>。";
    const text = Array(2500).fill(paragraph).join("\n\n");
    editors.mode = "source";
    editors.setFile(text, null);
    const head = 2490 * (paragraph.length + 2) + 8;
    editors.source.dispatch({ selection: { anchor: head } });
    editors.switchMode("visual");
    frames.pop()(0);
    assert.ok(
      editors.visual.state.selection.from >
        editors.visual.state.doc.content.size * 0.99,
    );
    editors.switchMode("source");
    frames.pop()(0);
    assert.equal(editors.source.state.selection.main.head, head);
  } finally {
    globalThis.requestAnimationFrame = previous;
  }
});

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  normalizePreferences,
  saveNoteFile,
  digest,
  assetPath,
  webURL,
  supportedKind,
  recordRecent,
} from "../electron/core.mjs";
const temp = () => fs.mkdtemp(path.join(os.tmpdir(), "studio-windows-test-"));
test("reading, visual and source style settings are independent", () => {
  const p = normalizePreferences({
    styles: {
      reading: { fontSize: 28 },
      visual: { fontSize: 24 },
      source: { fontSize: 18 },
    },
  });
  p.styles.reading.fontSize = 30;
  assert.equal(p.styles.visual.fontSize, 24);
  assert.equal(p.styles.source.fontSize, 18);
  assert.equal(normalizePreferences(p).styles.reading.fontSize, 30);
});
test("preferences clamp corrupt sizes and reject dangerous bookmark URLs", () => {
  const p = normalizePreferences({
    splitRatio: 99,
    styles: { source: { fontSize: 99, lineHeight: -1 } },
    bookmarks: [{ title: "x", url: "javascript:alert(1)" }],
  });
  assert.equal(p.splitRatio, 0.8);
  assert.equal(p.styles.source.fontSize, 40);
  assert.equal(p.styles.source.lineHeight, 1.2);
  assert.deepEqual(p.bookmarks, []);
});
test("workspace path and EPUB annotations survive preference normalization safely", () => {
  const p = normalizePreferences({
    workspace: "C:\\Study\\theme.mdworkspace",
    annotations: {
      "C:\\Study\\book.epub": [
        {
          id: "a1",
          cfi: "epubcfi(/6/2!/4/2/1:0)",
          quote: "原文摘录",
          note: "自己的备注",
          color: "#ffee88",
          style: "underline",
          createdAt: 10,
          updatedAt: 20,
        },
        { id: "bad" },
      ],
    },
  });
  assert.equal(p.workspace, "C:\\Study\\theme.mdworkspace");
  assert.equal(p.annotations["C:\\Study\\book.epub"].length, 1);
  assert.equal(p.annotations["C:\\Study\\book.epub"][0].note, "自己的备注");
  assert.equal(p.annotations["C:\\Study\\book.epub"][0].style, "underline");
});
test("atomic save retains Unicode source and no temporary files", async () => {
  const root = await temp();
  try {
    const file = path.join(root, "笔记.md");
    const text = "##### 标题\n\n**联系）**仍在同一段。<u>下划线</u>\n";
    const hash = await saveNoteFile(file, text);
    assert.equal(await fs.readFile(file, "utf8"), text);
    assert.equal(hash, digest(Buffer.from(text)));
    await saveNoteFile(file, text + "后续", hash);
    assert.deepEqual(await fs.readdir(root), ["笔记.md"]);
  } finally {
    await fs.rm(root, { recursive: true });
  }
});
test("external modifications and deletion cannot be overwritten", async () => {
  const root = await temp();
  try {
    const file = path.join(root, "note.md");
    const hash = await saveNoteFile(file, "original");
    await fs.writeFile(file, "outside");
    await assert.rejects(saveNoteFile(file, "overwrite", hash), /修改/);
    assert.equal(await fs.readFile(file, "utf8"), "outside");
    await fs.unlink(file);
    await assert.rejects(saveNoteFile(file, "overwrite", hash), /删除/);
  } finally {
    await fs.rm(root, { recursive: true });
  }
});
test("readonly original formats cannot be saved through note writer", async () => {
  await assert.rejects(saveNoteFile("/tmp/original.docx", "bad"), /仅能保存/);
  await assert.rejects(saveNoteFile("/tmp/original.pdf", "bad"), /仅能保存/);
});
test("existing save destinations require explicit known hash", async () => {
  const root = await temp();
  try {
    const file = path.join(root, "note.md");
    await fs.writeFile(file, "first");
    await assert.rejects(saveNoteFile(file, "second"), /已存在/);
    assert.equal(await fs.readFile(file, "utf8"), "first");
  } finally {
    await fs.rm(root, { recursive: true });
  }
});
test("image authorization prevents traversal, symlink escapes and non-images", async () => {
  const root = await temp();
  try {
    await fs.mkdir(path.join(root, "notes"));
    await fs.writeFile(path.join(root, "outside.png"), "x");
    await fs.writeFile(path.join(root, "notes", "inside.png"), "x");
    await fs.writeFile(path.join(root, "notes", "secret.txt"), "x");
    let symlinkAvailable = true;
    try {
      await fs.symlink(
        path.join(root, "outside.png"),
        path.join(root, "notes", "link.png"),
      );
    } catch (error) {
      if (process.platform === "win32" && error.code === "EPERM")
        symlinkAvailable = false;
      else throw error;
    }
    assert.equal(
      await assetPath(path.join(root, "notes"), "inside.png"),
      await fs.realpath(path.join(root, "notes", "inside.png")),
    );
    for (const value of [
      "../outside.png",
      "%2e%2e/outside.png",
      ...(symlinkAvailable ? ["link.png"] : []),
      "secret.txt",
    ])
      await assert.rejects(assetPath(path.join(root, "notes"), value));
  } finally {
    await fs.rm(root, { recursive: true });
  }
});
test("web navigation disallows local schemes, passwords and malformed spaces", () => {
  assert.equal(webURL("example.com"), "https://example.com/");
  for (const value of [
    "file:///etc/passwd",
    "javascript:alert(1)",
    "https://user:pass@example.com",
    "bad url",
  ])
    assert.throws(() => webURL(value));
});
test("recent files retain exact reading/note pairing, deduplicate and cap at twenty", () => {
  let items = [];
  for (let i = 0; i < 25; i++)
    items = recordRecent(items, {
      reading: `book${i}.pdf`,
      note: `note${i}.md`,
    });
  assert.equal(items.length, 20);
  items = recordRecent(items, { reading: "book24.pdf", note: "note24.md" });
  assert.equal(items.length, 20);
  assert.equal(items[0].reading, "book24.pdf");
  assert.equal(items[0].note, "note24.md");
});
test("format routing recognizes case-insensitive supported formats and rejects WPS", () => {
  assert.equal(supportedKind("BOOK.EPUB"), "reading");
  assert.equal(supportedKind("笔记.MD"), "note");
  assert.equal(supportedKind("book.azw3"), "reading");
  assert.throws(() => supportedKind("book.wps"));
});

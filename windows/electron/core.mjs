import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";

export const noteExtensions = new Set([".md", ".markdown", ".txt"]);
export const readingExtensions = new Set([
  ".pdf",
  ".epub",
  ".docx",
  ".doc",
  ".pages",
  ".mobi",
  ".azw",
  ".azw3",
]);
export const digest = (bytes) =>
  crypto.createHash("sha256").update(bytes).digest("hex");
export function supportedKind(file) {
  const ext = path.extname(file).toLowerCase();
  if (noteExtensions.has(ext)) return "note";
  if (readingExtensions.has(ext)) return "reading";
  throw new Error(
    "暂不支持此格式。可打开 Markdown、PDF、EPUB、DOCX；DOC/Pages 需 LibreOffice，Kindle 格式需 Calibre。",
  );
}
export function webURL(input) {
  const text = String(input).trim();
  if (!text || /[\u0000-\u0020]/.test(text))
    throw new Error("请输入有效的网址。");
  const url = new URL(
    /^[a-z][a-z\d+.-]*:/i.test(text) && !/^[^/:]+:\d+(?:[/?#]|$)/.test(text)
      ? text
      : `https://${text.replace(/^\/\//, "")}`,
  );
  if (
    !["https:", "http:"].includes(url.protocol) ||
    url.username ||
    url.password
  )
    throw new Error("只支持 HTTP/HTTPS 网页，不接受带账号密码的网址。");
  return url.href;
}
export function normalizePreferences(input = {}) {
  const size = (x, d, min, max) =>
    Number.isFinite(x) ? Math.max(min, Math.min(max, x)) : d;
  const style = (x = {}, isSource = false) => ({
    fontSize: size(x.fontSize, isSource ? 18 : 20, 12, 40),
    lineHeight: size(x.lineHeight, 1.7, 1.2, 2.5),
    width: size(x.width, 900, 420, 1600),
    justify: !isSource && !!x.justify,
    fontFamily: [
      "system-ui",
      "serif",
      "sans-serif",
      "monospace",
      "Microsoft YaHei",
      "SimSun",
      "KaiTi",
    ].includes(x.fontFamily)
      ? x.fontFamily
      : isSource
        ? "monospace"
        : "system-ui",
    color: /^#[0-9a-f]{6}$/i.test(x.color) ? x.color : "#37434d",
    background: /^#[0-9a-f]{6}$/i.test(x.background) ? x.background : "#ffffff",
    paragraphSpacing: size(x.paragraphSpacing, 0.6, 0, 3),
    strongColor: /^#[0-9a-f]{6}$/i.test(x.strongColor)
      ? x.strongColor
      : "#087b72",
    strongSize: size(x.strongSize, 18, 12, 72),
    headings: [52, 40, 36, 28, 24, 20].map((d, i) => ({
      size: size(x.headings?.[i]?.size, d, 12, 96),
      color: /^#[0-9a-f]{6}$/i.test(x.headings?.[i]?.color)
        ? x.headings[i].color
        : ["#0498b7", "#0498b7", "#29664a", "#087cba", "#df8d12", "#596d62"][i],
    })),
  });
  return {
    layout: input.layout === "tabs" ? "tabs" : "split",
    splitRatio: size(input.splitRatio, 0.5, 0.2, 0.8),
    sidebarWidth: size(input.sidebarWidth, 250, 180, 420),
    syntax: input.syntax !== false,
    whitespace: !!input.whitespace,
    readingZoom: size(input.readingZoom, 100, 25, 400),
    styles: {
      reading: style(input.styles?.reading),
      visual: style(input.styles?.visual),
      source: style(input.styles?.source, true),
    },
    recent: (Array.isArray(input.recent) ? input.recent : [])
      .filter(
        (x) =>
          x &&
          [x.reading, x.note].some((v) => typeof v === "string") &&
          [x.reading, x.note].every(
            (v) => v === null || v === undefined || typeof v === "string",
          ),
      )
      .slice(0, 20),
    bookmarks: (Array.isArray(input.bookmarks) ? input.bookmarks : [])
      .filter(
        (x) => x && typeof x.url === "string" && typeof x.title === "string",
      )
      .flatMap((x) => {
        try {
          return [{ title: x.title.slice(0, 120), url: webURL(x.url) }];
        } catch {
          return [];
        }
      })
      .slice(0, 200),
    positions:
      input.positions && typeof input.positions === "object"
        ? Object.fromEntries(
            Object.entries(input.positions)
              .slice(-100)
              .filter(([, v]) => v && typeof v === "object")
              .map(([k, v]) => [
                k,
                {
                  top: size(v.top, 0, 0, 1e8),
                  page: size(v.page, 1, 1, 1e6),
                  cfi:
                    typeof v.cfi === "string"
                      ? v.cfi.slice(0, 2000)
                      : undefined,
                },
              ]),
          )
        : {},
  };
}
export async function atomicWrite(file, bytes) {
  const temp = path.join(
    path.dirname(file),
    `.${path.basename(file)}.${crypto.randomUUID()}.tmp`,
  );
  let handle;
  try {
    handle = await fs.open(temp, "wx");
    await handle.writeFile(bytes);
    await handle.sync();
    await handle.close();
    handle = null;
    await fs.rename(temp, file);
  } finally {
    if (handle) await handle.close();
    await fs.rm(temp, { force: true }).catch(() => {});
  }
}
export async function saveNoteFile(file, text, expectedHash) {
  if (!noteExtensions.has(path.extname(file).toLowerCase()))
    throw new Error("仅能保存 Markdown / 文本笔记。");
  if (typeof text !== "string" || Buffer.byteLength(text) > 32 * 1024 * 1024)
    throw new Error("笔记过大，无法安全保存。");
  let existing;
  try {
    existing = await fs.readFile(file);
  } catch (e) {
    if (e.code !== "ENOENT") throw e;
  }
  if (expectedHash && (!existing || digest(existing) !== expectedHash))
    throw new Error(
      "文件已被其他程序修改或删除。请另存为新文件，避免覆盖外部修改。",
    );
  if (!expectedHash && existing)
    throw new Error("目标文件已存在，请重新打开或选择其他文件名。");
  await atomicWrite(file, Buffer.from(text, "utf8"));
  return digest(Buffer.from(text, "utf8"));
}
export async function assetPath(root, relative) {
  const requested = decodeURIComponent(relative);
  if (!requested || /[\u0000]/.test(requested)) throw new Error("无效资源路径");
  const realRoot = await fs.realpath(root);
  const target = await fs.realpath(path.resolve(root, requested));
  const rel = path.relative(realRoot, target);
  if (rel.startsWith(".." + path.sep) || rel === ".." || path.isAbsolute(rel))
    throw new Error("资源路径超出已授权目录");
  if (
    ![
      ".png",
      ".jpg",
      ".jpeg",
      ".gif",
      ".webp",
      ".svg",
      ".avif",
      ".bmp",
    ].includes(path.extname(target).toLowerCase())
  )
    throw new Error("只允许读取图片资源");
  return target;
}
export function recordRecent(recent, pair) {
  if (!pair.reading && !pair.note) return recent;
  return [
    { ...pair, openedAt: Date.now() },
    ...recent.filter((x) => x.reading !== pair.reading || x.note !== pair.note),
  ].slice(0, 20);
}

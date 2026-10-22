import { tags } from "@lezer/highlight";
import { Editor, mergeAttributes } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import { Markdown } from "@tiptap/markdown";
import Image from "@tiptap/extension-image";
import Underline from "@tiptap/extension-underline";
import Bold from "@tiptap/extension-bold";
import { TableKit } from "@tiptap/extension-table";
import { EditorState, Compartment } from "@codemirror/state";
import {
  EditorView,
  keymap,
  lineNumbers,
  highlightActiveLineGutter,
  highlightSpecialChars,
  drawSelection,
  Decoration,
  ViewPlugin,
  WidgetType,
  highlightWhitespace,
} from "@codemirror/view";
import {
  defaultKeymap,
  history,
  historyKeymap,
  indentWithTab,
} from "@codemirror/commands";
import { markdown } from "@codemirror/lang-markdown";
import {
  syntaxHighlighting,
  defaultHighlightStyle,
  HighlightStyle,
} from "@codemirror/language";
import { searchKeymap, openSearchPanel } from "@codemirror/search";
import DOMPurify from "dompurify";
import { marked } from "marked";
import type { Style } from "./types";

export function localImageURL(src: string, id: string | null) {
  if (/^(https?:|data:image\/|blob:)/i.test(src)) return src;
  if (/^[a-z][a-z\d+.-]*:/i.test(src) || !id) return "";
  return `studio-asset://${id}/${src.split(/[\\/]/).map(encodeURIComponent).join("/")}`;
}
export function visualLimitation(source: string): string | null {
  // Preserve unsupported source rather than silently rewriting it through a schema.
  const withoutCode = source.replace(
    /^(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\1\s*$/gm,
    "",
  );
  if (/^\[\^[^\]]+\]:/m.test(withoutCode) || /\[\^[^\]]+\]/.test(withoutCode))
    return "脚注";
  if (/^\$\$|\\\[|\\\(/m.test(withoutCode)) return "数学公式";
  if (/^---\r?\n[\s\S]*?\r?\n---/.test(source)) return "YAML 文档元数据";
  if (/\]\[[^\]]*\]|^\[[^\]]+\]:/m.test(withoutCode)) return "引用式链接";
  if (/<\/?(?!u\b|strong\b|https?:|mailto:)[a-z][^>]*>/i.test(withoutCode))
    return "自定义 HTML";
  if (/^\s*[-*+]\s+\[[ xX]\]/m.test(withoutCode)) return "任务列表";
  return null;
}
class EndMarker extends WidgetType {
  constructor(readonly paragraph: boolean) {
    super();
  }
  eq(other: EndMarker) {
    return other.paragraph === this.paragraph;
  }
  toDOM() {
    const span = document.createElement("span");
    span.textContent = this.paragraph ? "¶" : "↵";
    span.className = "line-end-marker";
    span.setAttribute("aria-hidden", "true");
    return span;
  }
  ignoreEvent() {
    return true;
  }
}
const endMarkers = ViewPlugin.fromClass(
  class {
    decorations;
    constructor(view: EditorView) {
      this.decorations = this.create(view);
    }
    update(update: any) {
      if (update.docChanged || update.viewportChanged)
        this.decorations = this.create(update.view);
    }
    create(view: EditorView) {
      const items = [];
      const seen = new Set<number>();
      for (const range of view.visibleRanges) {
        let at = range.from;
        while (at <= range.to) {
          const line = view.state.doc.lineAt(at);
          if (!seen.has(line.number)) {
            items.push(
              Decoration.widget({
                widget: new EndMarker(!line.text.trim()),
                side: 1,
              }).range(line.to),
            );
            seen.add(line.number);
          }
          if (line.to >= range.to || line.number === view.state.doc.lines)
            break;
          at = line.to + 1;
        }
      }
      return Decoration.set(items, true);
    }
  },
  { decorations: (v) => v.decorations },
);

export function semanticSource(source: string) {
  const text: string[] = [];
  const offsets: number[] = [];
  const syntax =
    /<\/?(?:u|strong)\b[^>]*>|\*\*|~~|(?<=^|\n)\s{0,3}(?:#{1,6} |[-*+] |\d+\. )/gm;
  let at = 0;
  for (const match of source.matchAll(syntax)) {
    for (; at < match.index!; at++) {
      text.push(source[at]);
      offsets.push(at);
    }
    at = match.index! + match[0].length;
  }
  for (; at < source.length; at++) {
    text.push(source[at]);
    offsets.push(at);
  }
  offsets.push(source.length);
  return { text: text.join(""), offsets };
}
export function nearestOccurrence(
  text: string,
  needle: string,
  progress: number,
) {
  if (!needle) return -1;
  let best = -1,
    distance = Infinity;
  for (let from = 0; from <= text.length;) {
    const at = text.indexOf(needle, from);
    if (at < 0) break;
    const delta = Math.abs(at - progress * text.length);
    if (delta < distance) {
      best = at;
      distance = delta;
    }
    from = at + Math.max(1, needle.length);
  }
  return best;
}
type Position = {
  context: string;
  localOffset: number;
  progress: number;
  before: string;
  after: string;
  selection: number;
  fraction: number;
};
export class MarkdownEditors {
  readonly source: EditorView;
  readonly visual: Editor;
  private syntax = new Compartment();
  private spaces = new Compartment();
  private appearance = new Compartment();
  private current = "";
  private visualBase = "";
  private visualChanged = false;
  private updating = false;
  private fileID: string | null = null;
  private visualBlocked = false;
  private position: Position | null = null;
  mode: "visual" | "source" = "visual";
  both = false;
  constructor(
    readonly visualHost: HTMLElement,
    readonly sourceHost: HTMLElement,
    readonly onChange: () => void,
    readonly onFocus: (mode: "visual" | "source") => void,
    readonly onImage: (file: File) => Promise<string | null>,
  ) {
    const LocalImage = Image.extend({
      renderHTML: ({ HTMLAttributes }) => [
        "img",
        mergeAttributes(HTMLAttributes, {
          src: localImageURL(HTMLAttributes.src, this.fileID),
        }),
      ],
    });
    this.visual = new Editor({
      element: visualHost,
      extensions: [
        StarterKit.configure({
          link: { openOnClick: false },
          underline: false,
          bold: false,
        }),
        Bold.extend({
          renderMarkdown: (node, h, ctx) => {
            const content = h.renderChildren(node);
            const markText = String(ctx.meta?.markText ?? content);
            return /^[\p{P}\p{S}\s]|[\p{P}\p{S}\s]$/u.test(markText)
              ? `<strong>${content}</strong>`
              : `**${content}**`;
          },
        }),
        Underline.extend({
          renderMarkdown: (node, helpers) =>
            `<u>${helpers.renderChildren(node)}</u>`,
        }),
        LocalImage,
        TableKit.configure({ table: { resizable: false } }),
        Markdown.configure({ markedOptions: { gfm: true } }),
      ],
      content: "",
      contentType: "markdown",
      editorProps: {
        attributes: {
          "aria-label": "Markdown 可视化编辑器",
          spellcheck: "false",
        },
        handlePaste: (view, event) => {
          const image = Array.from(event.clipboardData?.files ?? []).find((f) =>
            f.type.startsWith("image/"),
          );
          if (image) {
            event.preventDefault();
            void this.onImage(image).then((src) => {
              if (src) this.visual.chain().focus().setImage({ src }).run();
            });
            return true;
          }
          const text = event.clipboardData?.getData("text/plain");
          if (text !== undefined) {
            event.preventDefault();
            const paragraphs = text
              .replace(/\r\n/g, "\n")
              .split(/\n\n+/)
              .map((block) => ({
                type: "paragraph",
                content: block
                  .split("\n")
                  .flatMap((line, i) => [
                    ...(i ? [{ type: "hardBreak" }] : []),
                    ...(line ? [{ type: "text", text: line }] : []),
                  ]),
              }));
            this.visual.commands.insertContent(paragraphs);
            return true;
          }
          return false;
        },
      },
      onUpdate: ({ transaction }) => {
        if (this.updating || !transaction.docChanged) return;
        this.visualChanged = true;
        this.onChange();
      },
      onFocus: () => this.onFocus("visual"),
    });
    this.source = new EditorView({
      parent: sourceHost,
      state: EditorState.create({
        doc: "",
        extensions: [
          lineNumbers(),
          highlightActiveLineGutter(),
          highlightSpecialChars(),
          drawSelection(),
          history(),
          keymap.of([
            ...defaultKeymap,
            ...historyKeymap,
            ...searchKeymap,
            indentWithTab,
          ]),
          EditorView.lineWrapping,
          this.syntax.of([
            markdown(),
            syntaxHighlighting(defaultHighlightStyle),
          ]),
          this.spaces.of([]),
          this.appearance.of([]),
          EditorView.contentAttributes.of({
            "aria-label": "Markdown 源码编辑器",
            spellcheck: "false",
          }),
          EditorView.updateListener.of((update) => {
            if (update.docChanged && !this.updating) {
              if (this.both) this.scheduleVisualSync();
              this.onChange();
            }
          }),
          EditorView.domEventHandlers({
            focus: () => {
              this.onFocus("source");
              return false;
            },
            paste: (_event) => false,
          }),
        ],
      }),
    });
    sourceHost.addEventListener(
      "paste",
      (event) => {
        const file = Array.from(event.clipboardData?.files ?? []).find((f) =>
          f.type.startsWith("image/"),
        );
        if (file) {
          event.preventDefault();
          event.stopPropagation();
          void this.onImage(file).then((src) => {
            if (src) this.insertSource(`![截图](${src})`);
          });
        }
      },
      true,
    );
  }
  private timer: ReturnType<typeof setTimeout> | undefined;
  private scheduleVisualSync() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      if (this.source.composing) {
        this.scheduleVisualSync();
        return;
      }
      this.current = this.source.state.doc.toString();
      this.renderVisual(this.current);
    }, 650);
  }
  setFileID(id: string | null) {
    this.fileID = id;
  }
  setFile(source: string, id: string | null) {
    clearTimeout(this.timer);
    this.fileID = id;
    this.current = source;
    this.visualBase = source;
    this.visualChanged = false;
    this.position = null;
    this.rebuildSource(source);
    this.renderVisual(source);
  }
  private sourceSettings = {
    syntax: true,
    spaces: false,
    style: { fontSize: 18, lineHeight: 1.7, width: 900, justify: false },
  };
  private rebuildSource(source: string) {
    // Reconfigure the original extension set so undo history never crosses files.
    const state = EditorState.create({
      doc: source,
      extensions: [
        lineNumbers(),
        highlightActiveLineGutter(),
        highlightSpecialChars(),
        drawSelection(),
        history(),
        keymap.of([
          ...defaultKeymap,
          ...historyKeymap,
          ...searchKeymap,
          indentWithTab,
        ]),
        EditorView.lineWrapping,
        this.syntax.of(
          this.sourceSettings.syntax
            ? [markdown(), this.coloredSyntax(this.sourceSettings.style)]
            : [],
        ),
        this.spaces.of(
          this.sourceSettings.spaces ? [highlightWhitespace(), endMarkers] : [],
        ),
        this.appearance.of(this.theme(this.sourceSettings.style)),
        EditorView.contentAttributes.of({
          "aria-label": "Markdown 源码编辑器",
          spellcheck: "false",
        }),
        EditorView.updateListener.of((update) => {
          if (update.docChanged && !this.updating) {
            if (this.both) this.scheduleVisualSync();
            this.onChange();
          }
        }),
        EditorView.domEventHandlers({
          focus: () => {
            this.onFocus("source");
            return false;
          },
        }),
      ],
    });
    this.updating = true;
    this.source.setState(state);
    this.updating = false;
  }
  private renderVisual(source: string) {
    const limitation = visualLimitation(source);
    this.visualBlocked = !!limitation;
    this.visualHost.classList.toggle(
      "unsupported-markdown",
      this.visualBlocked,
    );
    if (limitation) {
      this.visual.setEditable(false, false);
      this.visual.commands.setContent(
        `<p>此文档包含${limitation}，本版为保护原文已停用可视化编辑。请在源码区编辑。</p>${DOMPurify.sanitize(marked.parse(source, { async: false }) as string)}`,
        { emitUpdate: false },
      );
    } else {
      this.visual.setEditable(true, false);
      this.visual.commands.setContent(source, {
        contentType: "markdown",
        emitUpdate: false,
      });
    }
    this.visualBase = source;
    this.visualChanged = false;
  }
  text() {
    if (this.mode === "source") this.current = this.source.state.doc.toString();
    if (this.mode === "visual" && this.visualChanged && !this.visualBlocked) {
      this.current = this.visual.getMarkdown();
      this.visualBase = this.current;
      this.visualChanged = false;
      this.updating = true;
      this.source.dispatch({
        changes: {
          from: 0,
          to: this.source.state.doc.length,
          insert: this.current,
        },
      });
      this.updating = false;
    }
    return this.current;
  }
  private capture() {
    const host =
      this.mode === "source" ? this.source.scrollDOM : this.visualHost;
    let selection = 0;
    let content = "";
    let offset = 0;
    if (this.mode === "source") {
      selection = this.source.state.selection.main.head;
      const line = this.source.state.doc.lineAt(selection);
      const semantic = semanticSource(line.text);
      content = semantic.text;
      offset = semantic.offsets.findIndex((p) => p >= selection - line.from);
      if (offset < 0) offset = content.length;
    } else {
      selection = this.visual.state.selection.from;
      const parent = this.visual.state.selection.$from.parent;
      const semantic = semanticSource(parent.textContent);
      content = semantic.text;
      offset = semantic.offsets.findIndex(
        (p) => p >= this.visual.state.selection.$from.parentOffset,
      );
      if (offset < 0) offset = content.length;
    }
    this.position = {
      context: content,
      localOffset: offset,
      progress:
        selection /
        Math.max(
          1,
          this.mode === "source"
            ? this.source.state.doc.length
            : this.visual.state.doc.content.size,
        ),
      before: content.slice(Math.max(0, offset - 36), offset),
      after: content.slice(offset, offset + 36),
      selection,
      fraction:
        host.scrollTop / Math.max(1, host.scrollHeight - host.clientHeight),
    };
  }

  switchMode(mode: "visual" | "source") {
    if (this.mode === mode) return;
    this.capture();
    const content = this.text();
    this.mode = mode;
    if (mode === "visual" && this.visualBase !== content)
      this.renderVisual(content);
    this.restore();
  }
  private restore() {
    const pos = this.position;
    if (!pos) return;
    requestAnimationFrame(() => {
      if (this.mode === "source") {
        const semantic = semanticSource(this.current);
        const needle = pos.before + pos.after;
        let target = nearestOccurrence(
          semantic.text,
          pos.context,
          pos.progress,
        );
        let offset = pos.localOffset;
        if (target < 0) {
          target = nearestOccurrence(semantic.text, needle, pos.progress);
          offset = pos.before.length;
        }
        if (target >= 0)
          target =
            semantic.offsets[
              Math.min(semantic.offsets.length - 1, target + offset)
            ];
        const head =
          target >= 0
            ? target
            : Math.min(pos.selection, this.source.state.doc.length);
        this.source.dispatch({
          selection: { anchor: head },
          effects: EditorView.scrollIntoView(head, { y: "center" }),
        });
        this.source.focus();
      } else {
        let found = 0;
        let distance = Infinity;
        if (pos.context)
          this.visual.state.doc.descendants((node, offset) => {
            if (node.isTextblock) {
              const semantic = semanticSource(node.textContent);
              let at = semantic.text.indexOf(pos.context);
              let local = pos.localOffset;
              if (at < 0) {
                at = semantic.text.indexOf(pos.before + pos.after);
                local = pos.before.length;
              }
              if (at >= 0) {
                const candidate =
                  offset +
                  1 +
                  semantic.offsets[
                    Math.min(semantic.offsets.length - 1, at + local)
                  ];
                const delta = Math.abs(
                  candidate / this.visual.state.doc.content.size - pos.progress,
                );
                if (delta < distance) {
                  found = candidate;
                  distance = delta;
                }
              }
            }
          });
        if (found) {
          this.visual.commands.setTextSelection(found);
          const target = this.visual.view.domAtPos(found).node;
          const element =
            target.nodeType === Node.ELEMENT_NODE
              ? (target as Element)
              : target.parentElement;
          element?.scrollIntoView({ block: "center" });
        } else
          this.visualHost.scrollTop =
            pos.fraction *
            (this.visualHost.scrollHeight - this.visualHost.clientHeight);
        this.visual.commands.focus(undefined, { scrollIntoView: false });
      }
    });
  }
  setBoth(value: boolean) {
    if (this.both === value) return;
    this.text();
    this.both = value;
    if (value && this.visualBase !== this.current)
      this.renderVisual(this.current);
  }
  flushComposition() {
    if (this.source.composing || this.visual.view.composing) {
      (document.activeElement as HTMLElement)?.blur();
      return true;
    }
    return false;
  }
  focus() {
    if (this.mode === "source") this.source.focus();
    else this.visual.commands.focus(undefined, { scrollIntoView: false });
  }
  insertSource(text: string) {
    const range = this.source.state.selection.main;
    this.source.dispatch({
      changes: { from: range.from, to: range.to, insert: text },
      selection: { anchor: range.from + text.length },
      scrollIntoView: true,
    });
    this.source.focus();
  }
  apply(action: string) {
    if (this.mode === "source") {
      const range = this.source.state.selection.main;
      const selected = this.source.state.sliceDoc(range.from, range.to);
      if (
        /^h[1-6]$/.test(action) ||
        action === "paragraph" ||
        action === "bullet" ||
        action === "ordered"
      ) {
        const first = this.source.state.doc.lineAt(range.from);
        const last = this.source.state.doc.lineAt(range.to);
        const block = this.source.state.sliceDoc(first.from, last.to);
        const prefix =
          action === "paragraph"
            ? ""
            : action === "bullet"
              ? "- "
              : action === "ordered"
                ? "1. "
                : "#".repeat(Number(action[1])) + " ";
        this.source.dispatch({
          changes: {
            from: first.from,
            to: last.to,
            insert: block
              .split("\n")
              .map(
                (line) =>
                  prefix +
                  line.replace(/^\s*(?:#{1,6}\s+|[-*+]\s+|\d+\.\s+)/, ""),
              )
              .join("\n"),
          },
        });
        this.source.focus();
        return;
      }
      const pairs: Record<string, [string, string]> = {
        bold: ["**", "**"],
        italic: ["*", "*"],
        underline: ["<u>", "</u>"],
        strike: ["~~", "~~"],
        code: ["`", "`"],
        quote: ["> ", ""],
        rule: ["\n\n---\n\n", ""],
        link: ["[", "](https://)"],
        table: ["\n\n| 标题 | 标题 |\n| --- | --- |\n| 内容 | 内容 |\n\n", ""],
      };
      const pair = pairs[action];
      if (pair) this.insertSource(pair[0] + selected + pair[1]);
      return;
    }
    if (this.visualBlocked) return;
    const chain = this.visual.chain().focus();
    if (/^h[1-6]$/.test(action)) {
      if (this.visual.isActive("listItem")) chain.liftListItem("listItem");
      chain
        .setHeading({ level: Number(action[1]) as 1 | 2 | 3 | 4 | 5 | 6 })
        .run();
    } else if (action === "paragraph") chain.setParagraph().run();
    else if (action === "bold") chain.toggleBold().run();
    else if (action === "italic") chain.toggleItalic().run();
    else if (action === "underline") chain.toggleUnderline().run();
    else if (action === "strike") chain.toggleStrike().run();
    else if (action === "code") chain.toggleCode().run();
    else if (action === "bullet") chain.toggleBulletList().run();
    else if (action === "ordered") chain.toggleOrderedList().run();
    else if (action === "quote") chain.toggleBlockquote().run();
    else if (action === "rule") chain.setHorizontalRule().run();
    else if (action === "table")
      chain.insertTable({ rows: 3, cols: 2, withHeaderRow: true }).run();
    else if (action === "link")
      chain.setLink({ href: "https://example.com" }).run();
  }
  find(text?: string) {
    if (this.mode === "source") openSearchPanel(this.source);
    else {
      if (!text) return;
      let found = 0;
      this.visual.state.doc.descendants((node, pos) => {
        if (!found && node.isText && node.text?.includes(text))
          found = pos + node.text.indexOf(text);
      });
      if (found)
        this.visual
          .chain()
          .focus()
          .setTextSelection({ from: found, to: found + text.length })
          .scrollIntoView()
          .run();
    }
  }
  private theme(style: Style) {
    return EditorView.theme({
      "&": {
        height: "100%",
        fontSize: `${style.fontSize}px`,
        color: style.color ?? "#37434d",
        backgroundColor: style.background ?? "#ffffff",
      },
      ".cm-scroller": {
        fontFamily:
          style.fontFamily === "monospace" || !style.fontFamily
            ? '"Cascadia Code",Consolas,"Microsoft YaHei",monospace'
            : style.fontFamily,
        lineHeight: String(style.lineHeight),
        overflow: "auto",
      },
      ".cm-content": {
        padding: "28px 20px 24px",
        maxWidth: `${style.width}px`,
        minHeight: "100%",
        boxSizing: "border-box",
      },
      ".cm-gutters": {
        fontSize: `${Math.max(12, style.fontSize * 0.8)}px`,
        backgroundColor: style.background ?? "#f7f8fa",
        color: "#9298a1",
        borderRight: "1px solid #e5e7eb",
      },
      ".cm-gutterElement": { padding: "0 10px" },
      ".cm-cursor": { borderLeftWidth: "1.5px" },
      ".cm-focused": { outline: "none" },
      ".cm-line": { padding: "0" },
    });
  }
  private coloredSyntax(style: Style) {
    return syntaxHighlighting(
      HighlightStyle.define([
        ...defaultHighlightStyle.specs,
        {
          tag: tags.strong,
          color: style.strongColor ?? "#087b72",
          fontWeight: "bold",
        },
        ...[
          tags.heading1,
          tags.heading2,
          tags.heading3,
          tags.heading4,
          tags.heading5,
          tags.heading6,
        ].map((tag, i) => ({
          tag,
          color:
            style.headings?.[i]?.color ??
            ["#0498b7", "#0498b7", "#29664a", "#087cba", "#df8d12", "#596d62"][
              i
            ],
        })),
      ]),
    );
  }
  configure(syntax: boolean, spaces: boolean, style: Style) {
    this.sourceSettings = { syntax, spaces, style };
    this.source.dispatch({
      effects: [
        this.syntax.reconfigure(
          syntax ? [markdown(), this.coloredSyntax(style)] : [],
        ),
        this.spaces.reconfigure(
          spaces ? [highlightWhitespace(), endMarkers] : [],
        ),
        this.appearance.reconfigure(this.theme(style)),
      ],
    });
  }
  outline() {
    return this.text()
      .split("\n")
      .flatMap((text, i) => {
        const m = /^(#{1,6})\s+(.+)$/.exec(text);
        return m
          ? [
              {
                level: m[1].length,
                title: m[2].replace(/[*_`]/g, ""),
                line: i + 1,
              },
            ]
          : [];
      });
  }
  jump(line: number) {
    if (this.mode === "source") {
      const at = this.source.state.doc.line(
        Math.min(line, this.source.state.doc.lines),
      ).from;
      this.source.dispatch({
        selection: { anchor: at },
        effects: EditorView.scrollIntoView(at, { y: "start" }),
      });
      this.source.focus();
    } else {
      const text = this.current
        .split("\n")
        [line - 1]?.replace(/^#+\s+/, "")
        .replace(/[*_`]/g, "");
      for (const el of this.visualHost.querySelectorAll("h1,h2,h3,h4,h5,h6"))
        if (el.textContent === text) {
          el.scrollIntoView({ block: "start" });
          break;
        }
    }
  }
}

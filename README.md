# Markdown Studio

A quiet Markdown reader and source editor for macOS. It takes visual cues from MarkDown One's restrained interface without copying its full publishing workflow.

## 当前 Mac 工作区基线

当前冻结版本为 **0.8.16 Preview**。这一版本将一本书或一个学习主题作为 Workspace 工程管理，支持在同一工作区内打开多本 EPUB、PDF、Office 阅读资料、多份 Markdown 笔记和网页，并通过标签、分屏和停靠布局组合使用。详细功能、安装包校验值、已验证内容和当前限制见 [0.8.16 版本说明](docs/releases/0.8.16-preview.md)。

下一阶段将在此基线上开发 Markdown 笔记章节与 EPUB 章节的显式关联和双向跳转；0.8.16 标签保留为改造前的可回退版本。

正在开发的 **0.8.17 Preview** 已加入 EPUB 章节与 Markdown 标题的稳定关联、双向跳转、`/chapter` 命令及可关闭的章节跟随。使用方法和失效保护见 [0.8.17 版本说明](docs/releases/0.8.17-preview.md)。

**0.8.20 Preview** 重新梳理首次打开和按需创建笔记流程，并修复 EPUB 首次显示慢、关闭后目录残留及重复引用覆盖旧关联的问题，详见 [0.8.20 修复说明](docs/releases/0.8.20-preview.md)。

**0.8.21 Preview** 为每一条 EPUB 目录行建立独立身份：重新关联错误标题时只更新当前目录行，同页的其他章节链接继续保留；同时修复解包 EPUB 尾斜杠导致的重复配套笔记和工作区停止保存，详见 [0.8.21 修复说明](docs/releases/0.8.21-preview.md)。

**0.8.22 Preview** 重构左侧活动栏和上下文面板：空启动只显示打开、创建与最近工程；进入工程后，资源管理器、原文目录、笔记目录和网页收藏随右侧焦点切换。工具栏新增可暂停且不删除链接的“关联跟随”按钮，详见 [0.8.22 界面说明](docs/releases/0.8.22-preview.md)。

**0.8.23 Preview** 修复多 EPUB 工程中的焦点归属和目录精确关联：新建配套笔记始终使用最后实际聚焦的阅读标签；指向同一 XHTML 的不同目录行不再互相借用链接；目录行身份会跟随正向、反向跳转完整传递，详见 [0.8.23 修复说明](docs/releases/0.8.23-preview.md)。

**0.8.19 Preview** 修复连续建立第二条章节关联时覆盖第一条、同一 EPUB 页面内多个小节串联的问题，详见 [0.8.19 修复说明](docs/releases/0.8.19-preview.md)。

## Build and open

Requires macOS 14 or later and Xcode Command Line Tools.

```sh
./scripts/build-app.sh
open dist/MarkdownStudio.app
```

The build script produces a universal Apple Silicon/Intel Markdown Studio app, a compressed DMG, and `dist/SHA256SUMS.txt`.

## Included

- Open a Markdown file, or browse `.md` and `.markdown` files beneath a selected folder.
- A left outline with nested headings, collapsible sections, and repeatable click-to-jump navigation.
- A compact, collapsible left sidebar with stepped heading sizes, indentation, and per-level font settings. Outline text defaults to black while document headings keep their cyan blue style.
- Adjustable reading width and independent H1–H6 color, font family, size, and weight settings. Defaults use the macOS system font; outline text defaults to black while document headings keep their cyan blue style.
- Adjust reading width with the toolbar slider or numeric pixel field. Width changes update the preview in place without reloading the document.
- Style standard `**bold**` spans separately, including their color, font family, and size. All appearance preferences stay in the reader and never rewrite the source file.
- Switch between reading, source editing, and a resizable side-by-side editor/preview. `⇧⌘V` switches the Markdown editor and preview; `⌥⌘V` opens the preview alongside the editor. The preview and outline update as you type. `⌘S` saves edits to the current Markdown file; switching documents with unsaved edits asks whether to save, discard, or cancel.
- Open EPUB archives or already-unpacked EPUB folders in either original-book editing mode or companion-note mode. Unpacked folders are copied to the app cache before reading; the source folder is not changed. Original-book editing is WYSIWYG and saves to a new EPUB copy. Companion notes use a same-basename `.md` file next to the EPUB; if that note already exists, it is opened. The notebook workspace switches between the EPUB, Markdown notes, or both in vertically stacked, resizable panes. In note mode, the Markdown editor and rendered preview can be switched independently.
- Open unprotected MOBI, AZW, and AZW3 after installing [calibre for macOS](https://calibre-ebook.com/download_osx). On opening, Markdown Studio converts the book into a private EPUB cache, verifies its readable chapters, then offers reading, EPUB editing, or a companion Markdown note. The source file stays unchanged; edits to the book are exported as EPUB. The note and reading profile remain associated with the original file. DRM-protected books, AZW4, and KFX are not supported.
- Read PDF documents in a continuous, scrollable PDFKit view. Use the document's hierarchical bookmarks when present, or a page list when it has no outline. Navigate with previous/next controls, the page number field, or the sidebar; select and copy embedded text. Password-protected PDFs prompt for a password. Scanned pages remain viewable, but OCR is not included.
- Read text-oriented websites beside a Markdown notebook. Enter a URL or search phrase, use back/forward/reload, browse the page's semantic heading outline, and adjust page zoom. The Web menu provides `⌘L` to open a page, `⌘[` / `⌘]` to navigate history, `⌥⌘B` to edit the current favorite, and `⌃⌘C` to clip the selected text into the note. Clips preserve semantic headings, lists, links, emphasis, tables, and a breadcrumb to the containing headings, then add a source link. Favorites have editable names and notes, sync through the iCloud Reading Data folder when available, and can be edited or deleted from the sidebar context menu. This is a single-page reader without tab, extension, or download management; pages that hide text in canvas or cross-origin frames may not support text clipping.
- Use the PDF as the primary pane beside an independent Markdown note file, with the same resizable reading/preview/editor workspace as EPUB notes. In the PDF and EPUB notebook workspaces, the vertical divider adjusts the primary/notes pane balance, and the horizontal divider adjusts the preview/editor balance. Both proportions are remembered. A three-option toolbar control switches between split view, preview filling the right side, and editor filling the right side; returning to split view restores the previous proportions.
- When no Markdown note is open, the preview and editor provide a button to create one, named after the PDF or EPUB by default.
- Click a reading pane or Markdown pane to select it; the selected pane receives a subtle outline and shadow. The toolbar slider and numeric field do not switch targets on hover: when PDF is selected they set zoom relative to PDFKit's fit-to-window scale; when Markdown is selected they set the original Markdown content layout width in pixels. The PDF toolbar has separate fit-width, fit-height, and best-display buttons. Each click recalculates from the current page and reading pane. Best display uses the source image's pixels and the current display backing scale for a recognizable full-page scan; other pages fall back to showing the whole page. The `⌘+`, `⌘−`, and `⌘0` shortcuts follow the selected pane.
- Add colored highlights and text notes to selected EPUB passages. Annotations are saved in Markdown Studio's separate reading-data library; the original book is not modified. The annotation list can jump back to a marked passage. Existing adjacent annotation sidecars are imported the first time a book is opened.
- EPUB annotations support highlights and underlines, editable notes, double-click editing, contextual edit/delete actions from a note popover or right-click, configurable note font, size, and color, and a small inline note preview. Toolbar hints appear on hover and show available shortcuts. Presentation marks are applied only to the reader's temporary WebView DOM.
- Annotation shortcuts: `⇧⌘M` adds a note to selected EPUB text and `⌥⌘M` opens the annotation list.
- The source editor highlights headings, emphasis, underline, strikethrough, code, links, lists, and quotes as you type. Bold, italic, and underline are visible on the text while the Markdown markers remain in the source.
- Source highlighting waits briefly during continuous typing and rechecks only nearby lines, so long Markdown notes remain more responsive. The rendered preview catches up shortly after typing pauses.
- Paste a screenshot into the Markdown editor with `⌘V`, or choose Syntax → Image → Insert Image File (`⌥⌘I`). The image is copied into a sibling `<note name>.assets` folder and inserted as a relative Markdown image link. Save or create the Markdown note first; moving the note to another computer requires moving its assets folder too.
- Insert a GFM table from the Syntax menu with `⌘⌥T`; edit cells in the table window, then insert it into the source. Copy a cell range from Excel or Numbers and paste it into the editor to convert it into a Markdown table. Markdown keeps cell text and row/column structure, but not spreadsheet styling or merged cells.
- Insert a Markdown horizontal rule from the Syntax menu with `⌘⌥-`. H1 and H2 headings in the reading preview have the subtle divider used in MarkDown One.
- Close the current document with `⌘W`; unsaved edits prompt before the file is closed. “Close Folder” clears folder browsing while leaving the current document open.
- Markdown syntax commands: `⌘1`–`⌘6` set the current line to heading levels 1–6, `⌘B` bold, `⌘I` italic, `⌘U` underline, `⌘⇧X` strikethrough, and `⌘⇧K` inline code. Underline uses inline HTML (`<u>…</u>`), since CommonMark and GFM do not define underline syntax.
- Reading modes: `⌘R` toggles Markdown reading/editor, `⇧⌘V` toggles preview/editor, `⌥⌘V` opens Markdown preview alongside the editor, and `⌘⇧E` toggles side-by-side preview. Reading workspace shortcuts are `⌃⌘1` (document), `⌃⌘2` (notes), and `⌃⌘3` (document + preview + editor).
- Keep the last selected folder and reading preferences between launches. The app registers as a viewer for Markdown, EPUB, and PDF files, so Finder can open them with it.
- Save PDF and EPUB reading positions and per-book reading styles in a versioned JSON library. Books are identified by a full SHA-256 digest of the source file (or all file paths and contents for unpacked EPUBs), so matching copies on another Mac can load the same data. The library uses `iCloud Drive/Markdown Studio/Reading Data` when that iCloud Drive folder is available, and otherwise falls back to local Application Support. Original books and Markdown note files remain where you keep them; note contents are not copied into the reading-data library.
- Common shortcuts: `⌘O` open a file, `⇧⌘O` open a folder, `⌘+` / `⌘−` change body text size or PDF zoom according to the pointer's reading pane, `⌘0` reset it, `⌘,` open reading style settings, and `⌘⌥1` toggle the left sidebar. In the Syntax menu, Paragraph is `⌃⌥P` and Ordered List is `⌃⇧O`.
- The reading style panel's “Restore All Defaults” action resets width, fonts, font sizes, colors, line spacing, paragraph spacing, and heading weights.
- Render CommonMark and GitHub Flavored Markdown through Apple's `swift-markdown` parser, including tables, task lists, quotes, and fenced code.
- JavaScript is disabled in Markdown previews. EPUB chapters are sanitized before display and use a restrictive content security policy; local styles and book assets are retained.

## Extension boundary

`MarkdownDocumentStore` owns opening and listing documents, `MarkdownDocumentEditing` handles explicit saves, and `MarkdownBlock.parse` supplies both the reading preview and live outline. Reader preferences remain separate from document source.

## Release notes

- Folder browsing lists Markdown files recursively in one flat list.
- The current DMG contains an ad-hoc signed preview build. This seals the local app bundle for integrity checking, but it is not a Developer ID signature and macOS may still warn before opening an app downloaded from the internet.
- To create a public direct-download release, install a Developer ID Application certificate in Keychain Access and store an Apple notarytool profile locally. Then run `DEVELOPER_ID="Developer ID Application: Name (TEAMID)" NOTARY_PROFILE="profile-name" ./scripts/sign-and-notarize.sh`. The script signs with the hardened runtime, submits the app and DMG for notarization, staples the tickets, and refreshes the checksum. It does not store credentials in this project.
- The project produces a direct-download DMG; App Store distribution requires a separate sandboxed build and App Store Connect setup.

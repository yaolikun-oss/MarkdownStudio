# Markdown Studio

A quiet Markdown reader and source editor for macOS. It takes visual cues from MarkDown One's restrained interface without copying its full publishing workflow.

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
- Adjust reading width with the toolbar slider or by dragging the handle at the reading column's right edge. Width changes update the preview in place without reloading the document.
- Style standard `**bold**` spans separately, including their color, font family, and size. All appearance preferences stay in the reader and never rewrite the source file.
- Switch between reading, source editing, and a resizable side-by-side editor/preview. `⇧⌘V` switches the Markdown editor and preview; `⌥⌘V` opens the preview alongside the editor. The preview and outline update as you type. `⌘S` saves edits to the current Markdown file; switching documents with unsaved edits asks whether to save, discard, or cancel.
- Open EPUB archives or already-unpacked EPUB folders in either original-book editing mode or companion-note mode. Unpacked folders are copied to the app cache before reading; the source folder is not changed. Original-book editing is WYSIWYG and saves to a new EPUB copy. Companion notes use a same-basename `.md` file next to the EPUB; if that note already exists, it is opened. The notebook workspace switches between the EPUB, Markdown notes, or both in vertically stacked, resizable panes. In note mode, the Markdown editor and rendered preview can be switched independently.
- Add colored highlights and text notes to selected EPUB passages. Annotations are saved in a separate adjacent `.annotations.json` file; the original book is not modified. The annotation list can jump back to a marked passage.
- Annotation shortcuts: `⇧⌘M` adds a note to selected EPUB text and `⌥⌘M` opens the annotation list.
- The source editor highlights headings, emphasis, underline, strikethrough, code, links, lists, and quotes as you type. Bold, italic, and underline are visible on the text while the Markdown markers remain in the source.
- Insert a GFM table from the Syntax menu with `⌘⌥T`; edit cells in the table window, then insert it into the source. Copy a cell range from Excel or Numbers and paste it into the editor to convert it into a Markdown table. Markdown keeps cell text and row/column structure, but not spreadsheet styling or merged cells.
- Insert a Markdown horizontal rule from the Syntax menu with `⌘⌥-`. H1 and H2 headings in the reading preview have the subtle divider used in MarkDown One.
- Close the current document with `⌘W`; unsaved edits prompt before the file is closed. “Close Folder” clears folder browsing while leaving the current document open.
- Markdown syntax commands: `⌘1`–`⌘6` set the current line to heading levels 1–6, `⌘B` bold, `⌘I` italic, `⌘U` underline, `⌘⇧X` strikethrough, and `⌘⇧K` inline code. Underline uses inline HTML (`<u>…</u>`), since CommonMark and GFM do not define underline syntax.
- Reading modes: `⌘R` toggles Markdown reading/editor, `⇧⌘V` toggles preview/editor, `⌥⌘V` opens Markdown preview alongside the editor, and `⌘⇧E` toggles side-by-side preview. EPUB notebook layout shortcuts are `⌃⌘1` (book), `⌃⌘2` (notes), and `⌃⌘3` (stacked).
- Keep the last selected folder and reading preferences between launches. The app registers as a Markdown document viewer, so Finder can open `.md` files with it.
- Common shortcuts: `⌘O` open a Markdown file, `⇧⌘O` open a folder, `⌘+` / `⌘−` change body text size, `⌘0` reset body text size, `⌘,` open reading style settings, and `⌘⌥1` toggle the left sidebar.
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

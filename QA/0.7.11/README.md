# Markdown Studio Visual 0.7.11 QA

## Change under review

Editor clicks now finish native caret hit-testing before the Markdown workspace changes its active-area state. The activation is dispatched on the next main-loop turn for both the Markdown source `NSTextView` and visual `WKWebView`. This prevents a sidebar-tab or workspace refresh from interrupting the click that is choosing the caret location.

## Verification

- `swift test`: 66 tests passed across the Markdown editor, position, divider, PDF, web clipping, EPUB, image, and reading-library suites; one native drag test was skipped by its own execution constraint.
- Added a long Chinese Markdown source test confirming a rendered line maps back to its own insertion-point range.
- Added a sequencing test confirming workspace activation runs after native caret placement.
- Existing visual/source round-trip tests passed, including caret/viewport and splitter-position preservation through repeated mode switches.
- One native divider-drag test is marked skipped by the suite because its mouse-tracking loop must run in a separate test process. The divider sizing/geometry and mode-switch integration tests passed.
- Universal app signature verified; executable contains arm64 and x86_64 slices.
- `hdiutil verify` confirmed the DMG checksum is valid.

## Artifact

- `dist/MarkdownStudio-Visual-0.7.11.dmg`
- SHA-256: `14d7a29874221f52734ecd91494005e27004200e4feb1f1d011fa245bd32a8d7`

## Scope note

No changes were made to any open Markdown note or reading-position data. The caret interaction is covered by AppKit hit-testing and event-order tests; this run did not perform a physical mouse click in the user's open document.

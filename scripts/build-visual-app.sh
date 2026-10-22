#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export MARKDOWN_STUDIO_RELEASE_VERSION="0.7.31"
export MARKDOWN_STUDIO_APP_BUNDLE_NAME="MarkdownStudioVisual-0.7.31"
export MARKDOWN_STUDIO_DISPLAY_NAME="Markdown Studio Visual 0.7.31"
export MARKDOWN_STUDIO_BUNDLE_ID="local.markdownreader.visual.v0731"
export MARKDOWN_STUDIO_BUILD_NUMBER="73"
export MARKDOWN_STUDIO_DMG_BASENAME="MarkdownStudio-Visual-0.7.31"
export MARKDOWN_STUDIO_README="$(cd "$SCRIPT_DIR/.." && pwd)/README-VISUAL.md"
"$SCRIPT_DIR/build-app.sh"

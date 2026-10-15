#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/MarkdownStudio.app"
RELEASE_VERSION="0.6.1"
ARM_BUILD="$PROJECT_ROOT/.build-arm64"
INTEL_BUILD="$PROJECT_ROOT/.build-x86_64"

cd "$PROJECT_ROOT"
swift build -c release --triple arm64-apple-macos14.0 --scratch-path "$ARM_BUILD"
swift build -c release --triple x86_64-apple-macos14.0 --scratch-path "$INTEL_BUILD"
mkdir -p "$PROJECT_ROOT/Resources"
swift "$PROJECT_ROOT/scripts/make-icon.swift" "$PROJECT_ROOT/Resources"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
lipo -create \
    "$ARM_BUILD/out/Products/Release/MarkdownReader" \
    "$INTEL_BUILD/out/Products/Release/MarkdownReader" \
    -output "$APP_PATH/Contents/MacOS/MarkdownReader"
cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
LICENSES="$APP_PATH/Contents/Resources/ThirdPartyLicenses"
mkdir -p "$LICENSES"
cp "$PROJECT_ROOT/.build/checkouts/swift-markdown/LICENSE.txt" "$LICENSES/Swift-Markdown-LICENSE.txt"
cp "$PROJECT_ROOT/.build/checkouts/swift-markdown/NOTICE.txt" "$LICENSES/Swift-Markdown-NOTICE.txt"
cp "$PROJECT_ROOT/.build/checkouts/swift-cmark/COPYING" "$LICENSES/swift-cmark-COPYING.txt"
cp "$PROJECT_ROOT/.build/checkouts/ZIPFoundation/LICENSE" "$LICENSES/ZIPFoundation-LICENSE.txt"
cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>MarkdownReader</string>
    <key>CFBundleIdentifier</key><string>local.markdownreader.app</string>
    <key>CFBundleName</key><string>Markdown Studio</string>
    <key>CFBundleDisplayName</key><string>Markdown Studio</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.6.1</string>
    <key>CFBundleVersion</key><string>37</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSMultipleInstancesProhibited</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Markdown Document</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Default</string>
            <key>LSItemContentTypes</key><array><string>net.daringfireball.markdown</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>EPUB eBook</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Default</string>
            <key>LSItemContentTypes</key><array><string>org.idpf.epub-container</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>PDF Document</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Default</string>
            <key>LSItemContentTypes</key><array><string>com.adobe.pdf</string></array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key><string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key><string>Markdown Document</string>
            <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
            <key>UTTypeTagSpecification</key>
            <dict><key>public.filename-extension</key><array><string>md</string><string>markdown</string></array><key>public.mime-type</key><string>text/markdown</string></dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key><string>org.idpf.epub-container</string>
            <key>UTTypeDescription</key><string>EPUB eBook</string>
            <key>UTTypeConformsTo</key><array><string>public.data</string></array>
            <key>UTTypeTagSpecification</key>
            <dict><key>public.filename-extension</key><array><string>epub</string></array><key>public.mime-type</key><string>application/epub+zip</string></dict>
        </dict>
    </array>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

STAGING="$PROJECT_ROOT/dist/.dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/Markdown Studio.app"
cp "$PROJECT_ROOT/README.md" "$STAGING/Read Me.md"
cp -R "$LICENSES" "$STAGING/Third-Party Licenses"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Markdown Studio" -srcfolder "$STAGING" -ov -format UDZO \
    "$PROJECT_ROOT/dist/MarkdownStudio-$RELEASE_VERSION.dmg"
(
    cd "$PROJECT_ROOT/dist"
    CHECKSUM_FILE="$PROJECT_ROOT/dist/SHA256SUMS.txt"
    CHECKSUM_TEMP="$PROJECT_ROOT/dist/.SHA256SUMS.tmp"
    if [[ -f "$CHECKSUM_FILE" ]]; then
        grep -v "  MarkdownStudio-$RELEASE_VERSION.dmg$" "$CHECKSUM_FILE" > "$CHECKSUM_TEMP" || true
    else
        : > "$CHECKSUM_TEMP"
    fi
    shasum -a 256 "MarkdownStudio-$RELEASE_VERSION.dmg" >> "$CHECKSUM_TEMP"
    mv "$CHECKSUM_TEMP" "$CHECKSUM_FILE"
)
rm -rf "$STAGING"
echo "Created universal app: $APP_PATH"
echo "Created disk image: $PROJECT_ROOT/dist/MarkdownStudio-$RELEASE_VERSION.dmg"

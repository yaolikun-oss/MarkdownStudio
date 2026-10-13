#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/MarkdownStudio.app"
VERSION="0.2.6"
ZIP_PATH="$PROJECT_ROOT/dist/MarkdownStudio-$VERSION-notary.zip"
DMG_PATH="$PROJECT_ROOT/dist/MarkdownStudio-$VERSION.dmg"

if [[ -z "${DEVELOPER_ID:-}" || -z "${NOTARY_PROFILE:-}" ]]; then
    echo "Set DEVELOPER_ID to the installed Developer ID Application identity and NOTARY_PROFILE to a stored notarytool keychain profile." >&2
    exit 2
fi
[[ -d "$APP_PATH" ]] || { echo "Build the app first with scripts/build-app.sh" >&2; exit 2; }

codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"

STAGING="$PROJECT_ROOT/dist/.dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/Markdown Studio.app"
cp "$PROJECT_ROOT/README.md" "$STAGING/Read Me.md"
cp -R "$APP_PATH/Contents/Resources/ThirdPartyLicenses" "$STAGING/Third-Party Licenses"
rm -f "$DMG_PATH"
hdiutil create -volname "Markdown Studio" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
(
    cd "$PROJECT_ROOT/dist"
    shasum -a 256 "MarkdownStudio-$VERSION.dmg" > SHA256SUMS.txt
)
rm -rf "$STAGING" "$ZIP_PATH"
echo "Signed and notarized release ready: $DMG_PATH"

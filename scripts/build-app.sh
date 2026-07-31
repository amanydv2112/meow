#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="meow"
ARCH_NAME="${ARCH_NAME:-arm64}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/$APP_NAME-macOS-$ARCH_NAME.zip"
SHA_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"
export COPYFILE_DISABLE=1
swift build -c "$CONFIGURATION" --product "$APP_NAME"

if [ ! -f "$ROOT_DIR/Resources/$APP_NAME.icns" ]; then
  swift run MeowIconGen "$ROOT_DIR/Resources/$APP_NAME.icns"
fi

rm -rf "$APP_DIR" "$ZIP_PATH" "$SHA_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/$CONFIGURATION/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/$APP_NAME.icns" "$RESOURCES_DIR/$APP_NAME.icns"
plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null
find "$APP_DIR" -name '._*' -delete

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
  codesign --verify --deep --strict "$APP_DIR"
fi

find "$DIST_DIR" -name '._*' -delete
(cd "$DIST_DIR" && COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr --zlibCompressionLevel 9 "$APP_NAME.app" "$ZIP_PATH")
find "$DIST_DIR" -name '._*' -delete
shasum -a 256 "$ZIP_PATH" | tee "$SHA_PATH"

echo "Built $APP_DIR"
echo "Created $ZIP_PATH"
echo "Checksum $SHA_PATH"

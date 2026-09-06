#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Window Memory"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR"

# main.swift uses top-level executable statements, which requires the default
# (non-library) parse mode — -parse-as-library needs an explicit @main entry
# point and fails to compile this file.
swiftc "$ROOT_DIR/WindowMemory/Sources/main.swift" \
  -O \
  -o "$BUILD_DIR/WindowMemory" \
  -framework AppKit -framework ApplicationServices -framework ServiceManagement -framework CoreGraphics \
  -target "$(uname -m)-apple-macos13.0"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
mv "$BUILD_DIR/WindowMemory" "$APP_DIR/Contents/MacOS/WindowMemory"
cp "$ROOT_DIR/WindowMemory/Info.plist" "$APP_DIR/Contents/Info.plist"

# Bundle the app icon if a compiled .icns is available (built from
# AppIcon.iconset via `iconutil -c icns AppIcon.iconset -o AppIcon.icns`).
if [ -f "$ROOT_DIR/AppIcon.icns" ]; then
  cp "$ROOT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --sign - --timestamp=none "$APP_DIR/Contents/MacOS/WindowMemory"
codesign --force --sign - --timestamp=none "$APP_DIR"
echo "Built $APP_DIR"

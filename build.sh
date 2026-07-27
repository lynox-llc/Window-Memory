#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Window Memory"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR"
swiftc "$ROOT_DIR/WindowMemory/Sources/main.swift" \
  -o "$BUILD_DIR/WindowMemory" \
  -parse-as-library \
  -framework AppKit -framework ApplicationServices -framework ServiceManagement \
  -target "$(uname -m)-apple-macos13.0"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
mv "$BUILD_DIR/WindowMemory" "$APP_DIR/Contents/MacOS/WindowMemory"
cp "$ROOT_DIR/WindowMemory/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
echo "Built $APP_DIR"

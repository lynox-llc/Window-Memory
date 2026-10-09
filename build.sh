#!/bin/bash
# Build Window Memory.app from source.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Window Memory.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

echo "› Cleaning previous build"
rm -rf "$ROOT/build"
mkdir -p "$MACOS" "$RES"

echo "› Compiling (arm64 + x86_64 universal)"
swiftc -O \
    -target arm64-apple-macos13.0 \
    -o "$ROOT/build/wm-arm64" \
    "$ROOT/Sources/main.swift"

# Build an Intel slice too if the SDK supports it; ignore if unavailable.
if swiftc -O -target x86_64-apple-macos13.0 \
    -o "$ROOT/build/wm-x86_64" \
    "$ROOT/Sources/main.swift" 2>/dev/null; then
    lipo -create -output "$MACOS/WindowMemory" \
        "$ROOT/build/wm-arm64" "$ROOT/build/wm-x86_64"
    rm -f "$ROOT/build/wm-x86_64"
    echo "  built universal binary"
else
    mv "$ROOT/build/wm-arm64" "$MACOS/WindowMemory"
    echo "  built arm64-only binary"
fi
rm -f "$ROOT/build/wm-arm64"
chmod +x "$MACOS/WindowMemory"

echo "› Assembling bundle"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

# Optional icon, if AppIcon.icns was generated.
if [ -f "$ROOT/AppIcon.icns" ]; then
    cp "$ROOT/AppIcon.icns" "$RES/AppIcon.icns"
fi

echo "› 拡張属性を除去（署名を壊さないため署名前に実施）"
xattr -cr "$APP" 2>/dev/null || true
find "$APP" -name '.DS_Store' -delete 2>/dev/null || true

echo "› Ad-hoc code signing"
# --deep は非推奨。バンドル内を内側から順に署名する。
codesign --force --sign - --timestamp=none "$MACOS/WindowMemory"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP" && echo "  署名OK"

echo "✓ Built: $APP"

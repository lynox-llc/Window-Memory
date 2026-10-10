#!/bin/bash
# 配布用: Developer ID 署名 → 公証(notarize) → DMG 作成
# 事前に Apple Developer Program 登録が必要です。
#
# 使い方:
#   1. 環境変数を設定（自分の値に置き換え）
#        export DEV_ID="Developer ID Application: あなたの名前 (TEAMID)"
#        export AC_PROFILE="wm-notary"     # notarytool の保存済みプロファイル名
#   2. 事前に一度だけ認証情報を保存:
#        xcrun notarytool store-credentials "wm-notary" \
#          --apple-id "you@example.com" \
#          --team-id "TEAMID" \
#          --password "アプリ用パスワード(App-Specific Password)"
#   3. ./release.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Window Memory.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Info.plist")"
DMG="$ROOT/build/WindowMemory-$VERSION.dmg"

: "${DEV_ID:?DEV_ID を設定してください}"
: "${AC_PROFILE:?AC_PROFILE を設定してください}"

echo "› ビルド"
bash "$ROOT/build.sh"

echo "› Developer ID 署名（Hardened Runtime 付き）"
codesign --force --deep --options runtime --timestamp \
    --sign "$DEV_ID" "$APP"

echo "› 署名検証"
codesign --verify --strict --verbose=2 "$APP"

echo "› 公証用に zip 化して申請"
ZIP="$ROOT/build/WindowMemory.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$AC_PROFILE" --wait

echo "› 公証チケットをアプリに添付(staple)"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "› 配布用 DMG を作成"
rm -f "$DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Window Memory" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "› DMG も署名して公証"
codesign --force --sign "$DEV_ID" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$AC_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "✓ 配布可能: $DMG"

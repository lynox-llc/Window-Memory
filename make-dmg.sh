#!/bin/bash
# 配布用 DMG を作成し、ダウンロードフォルダへ出力する（Apple署名なし）。
#
# 未署名アプリはダウンロード時に隔離属性(quarantine)が付き、Gatekeeper に
# ブロックされます。そのため DMG には次の2つを同梱します：
#   ・はじめにお読みください.txt … 「このまま開く」の手順
#   ・かんたんインストール.command … 隔離属性を外して自動インストール
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Window Memory.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Info.plist")"
OUT="$HOME/Downloads/WindowMemory-$VERSION.dmg"

echo "› 最新ビルドを作成"
bash "$ROOT/build.sh" >/dev/null
echo "  ビルド完了"

echo "› DMG の中身を準備"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # ドラッグでインストールできるように

# --- 同梱その1：かんたんインストーラ（隔離属性を外して /Applications へ配置） ---
cat > "$STAGE/かんたんインストール.command" <<'INSTALLER'
#!/bin/bash
# Window Memory をインストールし、Gatekeeper の隔離属性を解除します。
cd "$(dirname "$0")"
SRC="./Window Memory.app"
DEST="/Applications/Window Memory.app"

echo "──────────────────────────────────────"
echo "  Window Memory かんたんインストール"
echo "──────────────────────────────────────"
echo ""

if [ ! -d "$SRC" ]; then
    echo "エラー: Window Memory.app が見つかりません。"
    echo "DMG をマウントした状態で実行してください。"
    read -n 1 -s -r -p "Enterキーで閉じます..."; exit 1
fi

echo "› 既存のアプリを終了"
pkill -x WindowMemory 2>/dev/null || true
sleep 1

echo "› /Applications へコピー"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

echo "› セキュリティの隔離属性を解除"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "› アプリを起動"
open "$DEST"

echo ""
echo "✅ インストール完了！"
echo ""
echo "最後に、ウィンドウ操作の許可をお願いします："
echo "  システム設定 → プライバシーとセキュリティ → アクセシビリティ"
echo "  → 「Window Memory」をオンにする"
echo ""
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
read -n 1 -s -r -p "Enterキーでこのウインドウを閉じます..."
echo ""
INSTALLER
chmod +x "$STAGE/かんたんインストール.command"

# --- 同梱その2：初回起動の案内 ---
cat > "$STAGE/はじめにお読みください.txt" <<'README'
────────────────────────────────────────────
 Window Memory __VERSION__  インストール手順
 開発: LYNOX LLC
────────────────────────────────────────────

このアプリは Apple の署名を行っていないため、初回のみ
macOS のセキュリティ確認を通す操作が必要です。
（2回目以降は普通にダブルクリックで起動できます）

■ 方法A：システム設定から許可する（推奨・ターミナル不要）

  1. 「Window Memory」を「Applications」フォルダへドラッグ
  2. アプリケーションフォルダで Window Memory を
     ダブルクリック
     → 「開発元を確認できないため開けません」と表示されます。
        これは正常です。そのまま次へ進んでください。
  3. システム設定 →「プライバシーとセキュリティ」を開き、
     画面を下の方までスクロール
  4. 「"Window Memory"は開発元を確認できないため
     ブロックされました」という項目の横にある
     【このまま開く】をクリック
  5. 確認ダイアログでもう一度【開く】をクリック
     （Mac のパスワードまたは Touch ID を求められます）

  ※ macOS 15 (Sequoia) 以降では、右クリック →「開く」では
     開けなくなりました。上記4の【このまま開く】が必要です。

■ 方法B：ターミナルで解除する（最も確実）

  方法Aで【このまま開く】が見つからない・うまくいかない場合は、
  ターミナル（アプリケーション → ユーティリティ）を開き、
  次の1行をコピーして貼り付け、Enterキーを押してください：

    xattr -dr com.apple.quarantine "/Applications/Window Memory.app"

  そのあと Window Memory をダブルクリックすれば起動します。

■ 方法C：かんたんインストール（自動）

  このディスク内の「かんたんインストール.command」を
  ダブルクリックすると、コピーとセキュリティ解除を自動で行います。
  ※ この方法でも「開けません」と出る場合は、方法A または B を
     お使いください（ダウンロードしたファイルは macOS の仕様で
     ブロックされることがあります）。

────────────────────────────────────────────
 最後に：ウィンドウ操作の許可（必須）
────────────────────────────────────────────

  システム設定 →「プライバシーとセキュリティ」
   →「アクセシビリティ」→ Window Memory を【オン】

  これでウィンドウ配置の保存・復元ができます。

  うまく動かないときは、メニューバーの ⊞ アイコンから
  「アクセシビリティを診断…」で状態を確認できます。

────────────────────────────────────────────
 使い方
────────────────────────────────────────────

  1. メニューバーの ⊞ アイコンをクリック
  2. 「現在の配置を保存…」で今のウィンドウ配置を保存
  3. 配置が崩れたら「配置を復元」→ 保存した名前を選ぶ

© 2026 LYNOX LLC. All rights reserved.
README
sed -i '' "s/__VERSION__/$VERSION/" "$STAGE/はじめにお読みください.txt"

echo "› DMG を作成"
rm -f "$OUT"
hdiutil create \
    -volname "Window Memory $VERSION" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$OUT" >/dev/null
rm -rf "$STAGE"

echo "› DMG に ad-hoc 署名（未署名だと Finder が開けないことがあるため）"
codesign --force --sign - "$OUT" && echo "  署名OK"

SIZE="$(du -h "$OUT" | cut -f1)"
echo "✓ 出力: $OUT ($SIZE)"

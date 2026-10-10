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
# --- 同梱その3：多言語の案内（English / 简体中文 / 한국어 / Italiano / Español） ---
cat > "$STAGE/README (English, 中文, 한국어, Italiano, Español).txt" <<'README_I18N'
Window Memory __VERSION__  -  LYNOX LLC
============================================================

[English]
This app is not signed by Apple, so macOS asks for confirmation on first launch.
1. Drag "Window Memory" to Applications, then double-click it (a warning appears: this is normal).
2. System Settings > Privacy & Security > scroll down > "Open Anyway" > Open.
   (On macOS 15+ right-click > Open does not work.)
   Or run in Terminal:  xattr -dr com.apple.quarantine "/Applications/Window Memory.app"
3. System Settings > Privacy & Security > Accessibility > turn Window Memory ON.
Then click the menu bar icon > "Save Current Layout...". If something fails, use "Diagnose Accessibility...".

[简体中文]
本应用未经 Apple 签名，首次启动时 macOS 会要求确认。
1. 将 Window Memory 拖到“应用程序”并双击（出现警告属正常现象）。
2. 系统设置 >“隐私与安全性”> 向下滚动 >“仍要打开”> 打开。（macOS 15 及以上无法使用右键“打开”）
   或在终端中运行：xattr -dr com.apple.quarantine "/Applications/Window Memory.app"
3. 系统设置 >“隐私与安全性”>“辅助功能”> 开启 Window Memory。
之后点击菜单栏图标 >“保存当前布局…”。如遇问题，请使用“诊断辅助功能…”。

[한국어]
이 앱은 Apple 서명이 없어 처음 실행할 때 macOS가 확인을 요청합니다.
1. Window Memory를 응용 프로그램으로 드래그한 뒤 더블 클릭합니다(경고가 나타나는 것은 정상입니다).
2. 시스템 설정 > 개인정보 보호 및 보안 > 아래로 스크롤 > "그래도 열기" > 열기.
   (macOS 15 이상에서는 오른쪽 클릭 > 열기가 동작하지 않습니다.)
   또는 터미널에서 실행: xattr -dr com.apple.quarantine "/Applications/Window Memory.app"
3. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > Window Memory를 켭니다.
그다음 메뉴 막대 아이콘 > "현재 배치 저장…". 문제가 있으면 "손쉬운 사용 진단…"을 사용하세요.

[Italiano]
Questa app non e firmata da Apple, quindi al primo avvio macOS chiede conferma.
1. Trascina Window Memory in Applicazioni e fai doppio clic (compare un avviso: e normale).
2. Impostazioni di Sistema > Privacy e sicurezza > scorri in basso > "Apri comunque" > Apri.
   (Da macOS 15 il clic destro > Apri non funziona.)
   Oppure nel Terminale:  xattr -dr com.apple.quarantine "/Applications/Window Memory.app"
3. Impostazioni di Sistema > Privacy e sicurezza > Accessibilita > attiva Window Memory.
Poi clicca l'icona nella barra dei menu > "Salva disposizione attuale...". In caso di problemi usa "Diagnostica Accessibilita...".

[Espanol]
Esta app no esta firmada por Apple, por lo que macOS pide confirmacion al abrirla por primera vez.
1. Arrastra Window Memory a Aplicaciones y haz doble clic (aparece un aviso: es normal).
2. Ajustes del Sistema > Privacidad y seguridad > desplazate hacia abajo > "Abrir igualmente" > Abrir.
   (En macOS 15 o posterior, clic derecho > Abrir no funciona.)
   O en Terminal:  xattr -dr com.apple.quarantine "/Applications/Window Memory.app"
3. Ajustes del Sistema > Privacidad y seguridad > Accesibilidad > activa Window Memory.
Despues pulsa el icono de la barra de menus > "Guardar disposicion actual...". Si algo falla, usa "Diagnosticar Accesibilidad...".

(c) 2026 LYNOX LLC. All rights reserved.
README_I18N
sed -i '' "s/__VERSION__/$VERSION/" "$STAGE/README (English, 中文, 한국어, Italiano, Español).txt"
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

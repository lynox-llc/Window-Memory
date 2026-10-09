#!/bin/bash
# アクセシビリティ権限が「オンなのに効かない」ときの修復スクリプト。
# アドホック署名のアプリは再ビルドで署名が変わり、以前の許可が無効化されます。
# このスクリプトは「再インストール → 古い許可をリセット → 再起動」を行い、
# 現在のビルドに対して許可を付け直せる状態にします。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "› アプリを終了"
pkill -x WindowMemory 2>/dev/null || true
sleep 1

echo "› 最新ビルドを作成"
bash "$ROOT/build.sh" >/dev/null

echo "› /Applications へ再インストール"
rm -rf "/Applications/Window Memory.app"
cp -R "$ROOT/build/Window Memory.app" /Applications/

echo "› 古いアクセシビリティ許可をリセット"
tccutil reset Accessibility com.windowmemory.app 2>/dev/null || true

echo "› アプリを起動"
open "/Applications/Window Memory.app"

cat <<'EOS'

────────────────────────────────────────────
✓ 準備完了。あと1ステップだけ手動で行ってください：

  システム設定 → プライバシーとセキュリティ → アクセシビリティ
  → 「Window Memory」を【オン】にする

  （リストに残っていて古い場合は「−」で削除してから、
    メニューバーのアプリで何か操作すると再追加されます）

  今度は現在のビルドに正しく紐づくので、以後は動作します。
  ※ 恒久的に解決するには、配布用の Developer ID 証明書で署名します
    （release.sh 参照）。その署名は再ビルドしても変わりません。
────────────────────────────────────────────
EOS

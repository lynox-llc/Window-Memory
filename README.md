# Window Memory

Mac のメニューバーアプリ。ウィンドウ配置を保存し、1クリックで復元します。
外部モニターの抜き差しで崩れた配置を、元通りに戻せます。

## 機能

- **アプリ配置保存** — 起動中の全アプリのウィンドウ位置・サイズを記録
- **1クリック復元** — メニューから選ぶだけで一括復元（⌘1〜⌘9 のショートカット付き）
- **ディスプレイごとにプロファイル保存** — モニター構成ごとに自動でグループ分け。
  同じ構成に戻ったときだけ、その配置が「Restore Layout」に出ます
- **ログイン時に自動起動**（トグル）
- Dock に出ないメニューバー常駐アプリ

## 使い方

1. `/Applications/Window Memory.app` を起動（メニューバーに ⊞ アイコンが出ます）
2. **初回のみ**アクセシビリティ権限を許可：
   システム設定 → プライバシーとセキュリティ → アクセシビリティ →
   「Window Memory」をオン
   （メニューの「Grant Access in System Settings…」から直接開けます）
3. 好きな配置にしてから **Save Current Layout…** → 名前を付けて保存
4. 配置が崩れたら **Restore Layout → 保存した名前** で一発復元

## しくみ

macOS の Accessibility API（`AXUIElement`）で各アプリのウィンドウ位置・サイズを
読み書きします。保存先は
`~/Library/Application Support/WindowMemory/profiles.json`。
ウィンドウの照合はウィンドウタイトル → ウィンドウ番号の順で行います。

## ビルド

```bash
./build.sh          # build/Window Memory.app を生成（universal binary）
open "build/Window Memory.app"
```

必要環境：macOS 13+ / Swift（Xcode Command Line Tools）

## 構成

```
WindowMemory/
├── Sources/main.swift   アプリ本体（メニューバー UI + ウィンドウ制御 + 永続化）
├── Info.plist           バンドル設定（LSUIElement = メニューバー常駐）
├── build.sh             ビルド & .app 化スクリプト
└── README.md
```

## 補足

- 商用配布する場合は Apple Developer 証明書での署名と公証（notarization）が必要です
  （現状はアドホック署名）。
- ミニマイズ中・サイズ 0 のウィンドウは保存対象外です。

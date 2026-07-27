# Window Memory V1.1

Mac のメニューバーアプリ。ウィンドウ配置を保存し、1クリックで復元します。
外部モニターの抜き差しで崩れた配置を、元通りに戻せます。

## 機能

- **アプリ配置保存** — 起動中の全アプリのウィンドウ位置・サイズを記録
- **1クリック復元** — メニューから選ぶだけで一括復元（⌘1〜⌘9 のショートカット付き）
- **ディスプレイごとにプロファイル保存** — モニター構成ごとに自動でグループ分け。
  同じ構成に戻ったときだけ、その配置が「Restore Layout」に出ます
- **ログイン時に自動起動**（トグル）
- Dock に出ないメニューバー常駐アプリ

### V1.1 の変更点

- V1.0で欠落していたアプリ本体・Info.plist・ビルドスクリプトを追加
- Accessibility権限がない場合に、メニューから設定画面を直接開ける導線を追加
- 保存時にウィンドウが取得できなかった場合は保存せず、理由を通知
- 復元結果を確認し、照合できなかったウィンドウ数を警告
- 保存レイアウトの削除と、現在のディスプレイ構成だけを表示するメニューを追加
- `SMAppService` によるログイン時起動の登録・解除
- JSONを一時ファイル経由で保存し、書き込み中の破損を防止

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
./build.sh          # build/Window Memory.app を生成
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

## V1.1の検証

ビルドはmacOS上で次のコマンドを実行します。Accessibility APIを使うため、実機で権限を許可した後に保存・復元を確認してください。

```bash
./build.sh
codesign --verify --deep --strict "build/Window Memory.app"
plutil -p "build/Window Memory.app/Contents/Info.plist"
```

## 補足

- 商用配布する場合は Apple Developer 証明書での署名と公証（notarization）が必要です
  （現状はアドホック署名）。
- ミニマイズ中・サイズ 0 のウィンドウは保存対象外です。
- V1.1では、既存JSONの読み込みに失敗した場合は空のプロファイルとして起動します。元ファイルは上書きしません。

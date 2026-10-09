<div align="center">

<img src="icon.png" width="128" alt="Window Memory">

# Window Memory

**ウィンドウ配置を1クリックで復元する、Mac用メニューバーアプリ**

外部モニターを外したり再接続したりすると崩れるウィンドウ配置を、いつもの状態に戻します。

[![Download](https://img.shields.io/badge/⬇_ダウンロード-最新版-4F6BFF?style=for-the-badge)](https://github.com/lynox-llc/Window-Memory/releases)
&nbsp;
![Platform](https://img.shields.io/badge/macOS-13%2B-black?style=for-the-badge&logo=apple)
![Price](https://img.shields.io/badge/料金-無料-2CB84F?style=for-the-badge)

</div>

---

## ✨ 機能

- 🖥 **アプリ配置保存** — 起動中の全アプリのウィンドウ位置・サイズをまとめて記録
- ⚡️ **1クリック復元** — メニューから選ぶだけで一括復元（⌘1〜⌘9 のショートカット対応）
- 🔀 **ディスプレイごとのプロファイル** — モニター構成ごとに自動グループ化。同じ構成に戻ったときだけ、その配置が「配置を復元」に表示されます
- 🔄 **ディスプレイ変更で自動復元（任意）** — モニターの抜き差しを検知し、その構成で最後に保存した配置を自動で復元。メニューの「ディスプレイ変更時に自動復元」でオン／オフ
- 🔔 **アップデート確認** — 起動時に新しいバージョンを確認。メニューの「アップデートを確認…」から手動でも確認できます
- 🚀 **ログイン時に自動起動**
- 🔒 **プライバシー重視** — 配置データはお使いのMac内にのみ保存。外部への送信は一切ありません（アップデート確認では GitHub の公開バージョン情報を取得するだけです）
- 🪶 Dockに出ない軽量なメニューバー常駐アプリ

## 💻 動作環境

- macOS 13 以降
- Apple Silicon / Intel 両対応（ユニバーサルバイナリ）

## 📥 インストール

1. [**最新版の DMG をダウンロード**](https://github.com/lynox-llc/Window-Memory/releases)して開く
2. `Window Memory` を `Applications` フォルダへドラッグ

### 🔑 初回起動の手順（重要）

このアプリはApple署名を行っていないため、初回のみセキュリティ確認を通す操作が必要です。
（2回目以降は普通にダブルクリックで起動できます）

1. `アプリケーション` フォルダの **Window Memory をダブルクリック**
   → 「開発元を確認できないため開けません」と表示されます（**正常です**）
2. **システム設定 →「プライバシーとセキュリティ」** を開き、下へスクロール
3. 「"Window Memory"は開発元を確認できないためブロックされました」の横の **【このまま開く】** をクリック
4. 確認ダイアログでもう一度 **【開く】** をクリック

> [!WARNING]
> **macOS 15 (Sequoia) 以降では、右クリック →「開く」では開けません。** 必ず上記3の **【このまま開く】** をお使いください。

> [!TIP]
> DMG内の **「かんたんインストール.command」** を使うと、この手順を自動化できます。
> どうしても開けない場合は、ターミナルで次の1行を実行すると確実です：
> ```bash
> xattr -dr com.apple.quarantine "/Applications/Window Memory.app"
> ```

### アクセシビリティを許可（必須）

ウィンドウを操作するために許可が必要です。

**システム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」→ Window Memory をオン**

> [!NOTE]
> アプリを**更新した場合は、以前の許可が無効になることがあります。** その場合はリストから一度「−」で削除し、「＋」で `/Applications/Window Memory.app` を追加し直してください。

## 🚀 使い方

1. メニューバーの **⊞ アイコン** をクリック
2. **「現在の配置を保存…」** で今のウィンドウ配置に名前を付けて保存
3. 配置が崩れたら **「配置を復元」→ 保存した名前** を選ぶだけ

うまく動かないときは、メニューの **「アクセシビリティを診断…」** で状態を確認できます。

## 🛠 しくみ

macOS の Accessibility API（`AXUIElement`）で各アプリのウィンドウ位置・サイズを読み書きします。配置データの保存先は `~/Library/Application Support/WindowMemory/profiles.json`。ウィンドウの照合は「ウィンドウタイトル → ウィンドウ番号」の順で行います。

## ⚙️ ソースからビルド

```bash
bash build.sh                     # build/Window Memory.app を生成（universal binary）
bash make-dmg.sh                  # 配布用 DMG を ~/Downloads に作成
bash fix-accessibility.sh         # 再インストールして古いアクセシビリティ許可をリセット
```

必要環境：macOS 13+ / Swift（Xcode Command Line Tools）

| ファイル | 役割 |
|---|---|
| `Sources/main.swift` | アプリ本体（メニューバーUI + ウィンドウ制御 + 永続化） |
| `Info.plist` | バンドル設定（`LSUIElement` = メニューバー常駐） |
| `build.sh` | ビルド & `.app` 化 |
| `make-dmg.sh` | 配布用DMG作成 |
| `fix-accessibility.sh` | 再インストール & アクセシビリティ許可のリセット |
| `make_icon.swift` | アプリアイコン生成 |
| `release.sh` | Developer ID 署名・公証（配布用） |

## ❓ よくある質問

<details>
<summary>「開発元を確認できないため開けません」と出ます</summary>

正常です。上記「初回起動の手順」の **【このまま開く】** をお使いください。Apple署名（公証）を行っていないための表示で、アプリの安全性とは別の話です。
</details>

<details>
<summary>アクセシビリティを許可したのに保存できません</summary>

アプリを更新すると以前の許可が無効になることがあります。メニューの **「アクセシビリティを診断…」** で「実際のウィンドウ取得」が0個の場合は、設定でWindow Memoryを一度削除して追加し直してください。
</details>

<details>
<summary>復元したのに一部のウィンドウが動きません</summary>

保存時に起動していたアプリが、復元時に起動していない場合はそのウィンドウは配置されません。対象アプリを起動してから復元してください。
</details>

## 📄 ライセンス / 開発

開発： **LYNOX LLC**
© 2026 LYNOX LLC. All rights reserved.

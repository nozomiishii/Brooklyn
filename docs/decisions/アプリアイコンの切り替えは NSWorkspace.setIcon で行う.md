---
status: accepted
date: 2026-08-21
---

# アプリアイコンの切り替えは NSWorkspace.setIcon で行う

## 背景と課題

新旧 2 つのアプリアイコンをユーザーが選べるようにしたい。Finder・Launchpad・Dock に反映され、アプリを終了しても残ること。ホストアプリは窓を閉じると終了する。

macOS には iOS の `setAlternateIconName` に相当する API がない。

## 検討した選択肢

### 切り替えの手段

| 選択肢 | 評価 |
| --- | --- |
| Assets.car の別 appiconset へ切り替える | 手段が無い。AppKit SDK に alternate icon 系の宣言は 1 つも無く、システムがマスクして描くのは `CFBundleIconName` が指す 1 つだけ。Info.plist の書き換えは署名を壊す |
| `NSApplication.applicationIconImage` | 起動中の Dock だけが変わり、終了で戻る。[AppIconKit](https://github.com/danielsaidi/AppIconKit) の macOS 実装がこれで、起動のたびに再適用している |
| `NSWorkspace.setIcon` | バンドルにカスタム Finder アイコンを書く。[Loop](https://github.com/mrkai77/Loop) と [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) が同じ方式 |

### アイコンの形の持ち方

システムがマスクするのはバンドルアイコンだけで、カスタムアイコンは渡した画像がそのまま描かれる。Brooklyn の素材は macOS 26 の作法どおりフルブリードなので、角丸と影をどこかで足すことになる。

| 選択肢 | 評価 |
| --- | --- |
| 素材に焼き込む | Loop と Karabiner のやり方。バンドルアイコン用とカスタムアイコン用で素材が 2 通りに増える |
| 渡す直前に描く | 素材はフルブリードの 1 つで済む。形の比率を自前で持つ |

## 決定

`NSWorkspace.setIcon` を使い、角丸と影は渡す直前に描く。比率は Calculator.app から実測した。

デフォルト側は画像を渡さず、カスタムアイコンの解除で表現する。扱う画像が 1 つで済む。

## 結果

### 良くなったこと

- アイコンの選択が Finder・Launchpad・Dock に残る。cask upgrade でバンドルごと入れ替わっても、次のアプリ起動で戻る

### 引き受けたコスト

- カスタムアイコン適用中はバンドルに `Icon\r` と `com.apple.FinderInfo` が付き、`codesign --verify --strict` が落ちる。通常の `--verify` は通り、デフォルトに戻せば両方消える
- アイコンの形の比率を自前で持つ。macOS が形を変えたら実測し直す
- ビルド成果物でアイコンを切り替えると、次のビルドで CodeSign が同じ detritus を弾く。署名の前に落とすビルドフェーズを project.yaml に置いている

### 保留した論点

- macOS に alternate app icon の公式 API が出たら置き換える

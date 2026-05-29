# CLAUDE.md

## プロジェクト概要

Apple の 2018 年 Brooklyn イベントにインスパイアされた macOS スクリーンセーバー。[Pedro Carrasco のオリジナル](https://github.com/pedrommcarrasco/Brooklyn)を Swift 6 / macOS 26 (Tahoe) / Apple Silicon 向けにモダンに再実装したもの。75 個の MP4 アニメーションを `AVPlayerLayer` でループ再生する。

## Canvas での動作確認

`.saver` をインストールせずにデバッグするには Canvas ターゲットを使う:

```bash
make generate && open Brooklyn.xcodeproj
```

## アーキテクチャ

### ターゲット構成（project.yaml で定義）

- **Brooklyn** — `.saver` バンドル。`NSPrincipalClass: Brooklyn.BrooklynView` でシステムに登録
- **Canvas** — デバッグ用 macOS アプリ。Brooklyn と同じソースをビルドし、ウィンドウ内でスクリーンセーバーを表示
- **BrooklynTests** — ユニットテスト。ソースを直接含めてテスト

### レイヤー構成

```
BrooklynView (ScreenSaverView)
  ├── BrooklynManager          # 再生ロジック・選択管理
  │     ├── Database           # ScreenSaverDefaults ラッパー
  │     └── Animation (enum)   # 75 種の動画定義、rawValue がファイル名
  ├── LoopPlayer (AVQueuePlayer)  # 無限ループ再生
  └── ConfigureSheet (SwiftUI)    # 設定 UI
        ├── ConfigureSheetViewModel
        └── ConfigureSheetController (NSWindowController ブリッジ)
```

## 触る前に読む（壊しやすいポイント）

### macOS Sonoma+ バグ回避（変更時はテストで regression を確認）

- `stopAnimation()` が呼ばれない → `com.apple.screensaver.willstop` 通知で cleanup
- `isPreview` が常に true → フレームサイズで判定（< 400×300 = プレビュー）
- `AVQueuePlayer` が 1 アイテムで停止 → `LoopPlayer` が自動複製

### Swift 6 Strict Concurrency

- `BrooklynManager`, `Database`, `ConfigureSheetViewModel` は `@MainActor`
- NotificationCenter オブザーバーは `nonisolated(unsafe)` で保持
- 通知コールバックから `@MainActor` メソッドを呼ぶ際は `MainActor.assumeIsolated` を使用



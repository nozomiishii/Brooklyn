---
paths:
  - "Brooklyn/**/*.swift"
  - "Canvas/**/*.swift"
  - "BrooklynTests/**/*.swift"
  - "project.yaml"
---

# アーキテクチャ詳細

CLAUDE.md の「アーキテクチャ」「ハードルール」節の補足。コードを変更する前に該当箇所を読むこと。

## 再生ロジック (`BrooklynManager.makePlayerItems`)

### Customize OFF（デフォルト）

全 75 アニメーション使用。`original` を先頭に 1 回再生 → 残りをランダムシャッフル → `LoopPlayer` が各アイテムを末尾にコピーして無限ループ。

### Customize ON

ユーザー選択のアニメーションのみ使用。ループ回数・ランダム順も設定 (`Database`) に従う。

## macOS Sonoma+ バグ回避

`BrooklynView` に実装済み。**変更時はテストで regression を確認すること。** 各回避策の症状と根本原因:

### `stopAnimation()` が呼ばれない

**症状**: macOS Sonoma 以降、`ScreenSaverView.stopAnimation()` がライフサイクル終了時に呼ばれず、`AVPlayer` がメモリに残り続ける（screensaver プロセスが生き残るとリソースリーク）。

**回避策**: `com.apple.screensaver.willstop` 通知を購読し、コールバック内で `AVPlayerLayer` の解放と `LoopPlayer` の停止を実行する。

### `isPreview` が常に true

**症状**: System Settings のプレビュー外（実際のスクリーンセーバー起動時）でも `ScreenSaverView.isPreview` が `true` を返す。プレビュー判定ロジックを `isPreview` に依存すると、本番再生でもプレビュー用パスを実行してしまう。

**回避策**: フレームサイズで判定する（**幅 < 400 または 高さ < 300 をプレビューと見なす**）。System Settings のプレビューウィンドウサイズを基準にした閾値。

### `AVQueuePlayer` が 1 アイテムで停止

**症状**: `AVQueuePlayer` がキューを使い切った後、デフォルトではループしない（最後のアイテム再生後に停止）。

**回避策**: `LoopPlayer` クラスが `AVPlayerItemDidPlayToEndTimeNotification` を監視し、終了したアイテムをキュー末尾に再追加する。これにより無限ループを実現。

## Swift 6 Strict Concurrency

### `@MainActor` 対象クラス

- `BrooklynManager`
- `Database`
- `ConfigureSheetViewModel`

UI / 設定に直接触るため MainActor で隔離。

### `NotificationCenter` オブザーバー

`nonisolated(unsafe)` プロパティで保持する。理由: `NSObjectProtocol` トークン自体は thread-safe で actor isolation を要求しないため、わざわざ `@MainActor` で囲む必要がない（むしろデイニシャライザで解放する際に actor 制約が邪魔になる）。

### 通知コールバックから `@MainActor` メソッドを呼ぶ

`MainActor.assumeIsolated { ... }` を使用する。`com.apple.screensaver.*` 通知は MainActor 上でディスパッチされる契約のため、`Task { @MainActor in ... }` で async コンテキストを作る必要はない（同期的に MainActor を assume すれば足りる）。

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Apple の 2018 年 Brooklyn イベントにインスパイアされた macOS スクリーンセーバー。[Pedro Carrasco のオリジナル](https://github.com/pedrommcarrasco/Brooklyn)を Swift 6 / macOS 26 (Tahoe) / Apple Silicon 向けにモダンに再実装したもの。75 個の MP4 アニメーションを `AVPlayerLayer` でループ再生する。

## Canvas での動作確認

`.saver` をインストールせずにデバッグするには Canvas ターゲットを使う:

```bash
make generate && open Brooklyn.xcodeproj  # Xcode で Canvas スキームを実行
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

## ハードルール

### macOS Sonoma+ バグ回避（変更時はテストで regression を確認）

- `stopAnimation()` が呼ばれない → `com.apple.screensaver.willstop` 通知で cleanup
- `isPreview` が常に true → フレームサイズで判定（< 400×300 = プレビュー）
- `AVQueuePlayer` が 1 アイテムで停止 → `LoopPlayer` が自動複製

### Swift 6 Strict Concurrency

- `BrooklynManager`, `Database`, `ConfigureSheetViewModel` は `@MainActor`
- NotificationCenter オブザーバーは `nonisolated(unsafe)` で保持
- 通知コールバックから `@MainActor` メソッドを呼ぶ際は `MainActor.assumeIsolated` を使用

### Animation enum と MP4 ファイルの対応

`Animation` enum の `rawValue` が `Resources/Animations/` 内のファイル名（拡張子なし）と一致する必要がある。不一致があると黒画面になる。`AnimationTests.testAllAnimationsHaveMatchingMP4Files` で検証済み。

## Git・GitHub・Conventional Commits

- PR タイトルは英語、semantic commit 形式、小文字開始（`_pull-request.yaml` で検証）
- Release Please が CHANGELOG とバージョンを自動管理。手動でバージョンを変更しない
- YAML ファイルの拡張子は `.yaml` に統一（ツールのデフォルトが `.yml` の場合は Makefile で `--config` / `--spec` を指定）
- `BREAKING CHANGE:` フッターと `feat!:` / `fix!:` の `!` 修飾は、**リリースされるパッケージ・公開アセットの互換性を破る変更にのみ**使用する。CI / workflows / branch protection / リポジトリ運用上の変更には使わない。これらの注意事項は PR 本文に記述する
  <!-- 2026-04-25 に chore: migrate reusable workflows to v3.0.0 PR が誤って BREAKING CHANGE として記録された経緯あり。release-please の major bump 誤発火を防ぐため、ops-only な変更は ! / BREAKING CHANGE フッターを絶対につけない -->

<!--
Convention: docs/ は人間ドキュメント兼 Claude rules。
.claude/rules は ../docs への symlink (Pattern A、Path E)。
docs/*.md に YAML frontmatter `paths:` を書くと、マッチするファイル編集時に自動 inject される。
- docs/architecture.md → Swift 編集時
- docs/release.md → release.yaml / Makefile 編集時
新しい docs を追加する際も同じ規約に従うこと。人間専用 doc は root (README.md) や .github/ に置く。
-->


# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Apple の 2018 年 Brooklyn イベントにインスパイアされた macOS スクリーンセーバー。[Pedro Carrasco のオリジナル](https://github.com/pedrommcarrasco/Brooklyn)を Swift 6 / macOS 26 (Tahoe) / Apple Silicon 向けにモダンに再実装したもの。75 個の MP4 アニメーションを `AVPlayerLayer` でループ再生する。

## コマンド

```bash
make generate     # XcodeGen で project.yaml から Xcode プロジェクトを生成
make build        # generate + Release ビルド
make test         # generate + テスト実行
make format       # SwiftFormat で自動整形
make format-check # フォーマット差分チェック（CI 用）
make lint         # SwiftLint（--strict）
make install      # build + ~/Library/Screen Savers/ にコピー + codesign
make uninstall    # スクリーンセーバーを削除
make clean        # build/ と Brooklyn.xcodeproj を削除
```

Canvas（デバッグ用アプリ）で `.saver` をインストールせずに動作確認：
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

### 再生ロジック（BrooklynManager.makePlayerItems）

- **Customize OFF（デフォルト）**: 全 75 アニメーション使用。original を先頭に 1 回再生 → 残りをランダムシャッフル → LoopPlayer が各アイテムを末尾にコピーして無限ループ
- **Customize ON**: ユーザー選択のアニメーションのみ使用。ループ回数・ランダム順も設定に従う

### macOS Sonoma+ バグ回避

`BrooklynView` に実装済みの回避策（変更時はテストで regression を確認）:

- `stopAnimation()` が呼ばれない → `com.apple.screensaver.willstop` 通知で cleanup
- `isPreview` が常に true → フレームサイズで判定（< 400×300 = プレビュー）
- AVQueuePlayer が 1 アイテムで停止 → LoopPlayer が自動複製

### Swift 6 Strict Concurrency

- `BrooklynManager`, `Database`, `ConfigureSheetViewModel` は `@MainActor`
- NotificationCenter オブザーバーは `nonisolated(unsafe)` で保持
- 通知コールバックから `@MainActor` メソッドを呼ぶ際は `MainActor.assumeIsolated` を使用

## Animation enum と MP4 ファイルの対応

`Animation` enum の `rawValue` が `Resources/Animations/` 内のファイル名（拡張子なし）と一致する必要がある。不一致があると動画が読み込めず黒画面になる。`AnimationTests.testAllAnimationsHaveMatchingMP4Files` で検証済み。

## CI/CD

- **CI（ci.yaml）**: push / 全 PR で `make build` + arm64 検証 + 75 MP4 検証 + `make test`
- **Release（release.yaml）**: Release Please で conventional commits からバージョン自動判定 → PR マージで `Info.plist` のバージョン更新 + `.saver.zip` を GitHub Releases にアップロード
- **actionlint / secretlint / pull-request title**: git-harvest と共通の品質チェック

## Git・GitHub 運用ルール

- PR タイトルは英語、semantic commit 形式、小文字開始（`_pull-request.yaml` で検証）
- Release Please が CHANGELOG とバージョンを自動管理。手動でバージョンを変更しない
- YAML ファイルの拡張子は `.yaml` に統一（ツールのデフォルトが `.yml` の場合は Makefile で `--config` / `--spec` を指定）

## リリース・Conventional Commits

- `BREAKING CHANGE:` フッターと `feat!:` / `fix!:` の `!` 修飾は、**リリースされるパッケージ・公開アセットの互換性を破る変更にのみ**使用する。CI / workflows / branch protection / リポジトリ運用上の変更には使わない。これらの注意事項は PR 本文に記述する（release-please など自動リリースツールが major / minor バンプを誤って行い、CHANGELOG に `⚠ BREAKING CHANGES` セクションを誤生成するのを防ぐため。実例: 2026-04-25 にこのリポジトリ群で `chore: migrate reusable workflows to v3.0.0` PR が誤って BREAKING CHANGE として記録された）。

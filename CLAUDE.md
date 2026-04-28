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
- **Release（release.yaml）**: 後述「リリースフロー」を参照
- **actionlint / secretlint / pull-request title**: git-harvest と共通の品質チェック

## リリースフロー

`release.yaml` は `main` への push / `workflow_dispatch` で起動し、以下 4 ジョブで構成される。

1. **`create-draft-release`** (ubuntu): release-please が conventional commits を集計し、release PR が既にマージされていれば draft release + tag を作成。`release_created` と `tag_name` を outputs として返す
2. **`upload-assets`** (macos-26, `release_created == 'true'` のみ): XcodeGen + `make build` + `make test` で `.saver` をビルドし、`.saver.zip` を GitHub Release に upload 後 publish
3. **`homebrew-update`** (macos-26, `release_created == 'true'` のみ): `brew bump-cask-pr` で `nozomiishii/homebrew-tap` の `Casks/brooklyn.rb` を新バージョンに更新する PR を作成し、出力から PR URL を捕捉して `gh pr merge --auto --squash` で auto-merge を有効化
4. **`release-pr`** (ubuntu, `upload-assets` 失敗時を除き常時): release-please で次の release PR を作成 / 更新

### Homebrew Cask 更新の実装方針

`homebrew-update` は **Homebrew 公式 CLI `brew bump-cask-pr` を直接呼ぶ** 実装。検討した代替案を採用しなかった理由:

- **Renovate に任せる**: `homebrew` manager は **Formula のみ対応**で Cask 未サポート（[renovate#32965](https://github.com/renovatebot/renovate/discussions/32965) が open のまま、コメント 0）。`postUpgradeTasks` で sha256 を再計算する手は Mend Cloud では使えない
- **`mislav/bump-homebrew-formula-action`**: homebrew-tap の `main` が GitHub Rulesets で保護されていると、`branchRes.data.protected === true` 判定で `update-<file>-<timestamp>` という別ブランチに commit を作る経路に入り、`create-pullrequest: false` のままだと PR 化もマージもされず孤立ブランチが残る。ジョブは "success" で終わるためサイレント失敗（実例: `update-git-harvest.rb-1777372050` が放置されていた）
- **手書き `git push` + `gh pr create`**: 動くが Homebrew エコシステム非標準。本流は公式 [Autobump](https://docs.brew.sh/Autobump) でも使われている `brew bump-cask-pr` / `brew bump --casks`

`brew bump-cask-pr` が肩代わりすること:

- 新版 tarball を取得して `sha256` を自動再計算
- `Casks/brooklyn.rb` のフィールド単位更新
- API 経由で commit + PR 作成（重複 PR 検出も内蔵）
- `brew style` での文法検証

### runner 選定

`homebrew-update` は **macos-26** で動かす（`upload-assets` と統一）。Linux runner + `Homebrew/actions/setup-homebrew` も試したが、`Homebrew/actions` が monorepo で個別 tag を持たないため zizmor の `stale-action-refs` ルールに引っかかり、commit pin しても警告が出続ける。macOS runner なら `brew` がプリインストールされているので setup ステップごと不要になる。

### 周辺前提

- GitHub App `nozomiishii-release` に `homebrew-tap` への `contents: write` + `pull-requests: write` 権限が付与済み
- `homebrew-tap` で `allow_auto_merge: true` 有効化済み
- `homebrew-tap` の `main` は GitHub Rulesets で 4 つの required status checks (`pull-request / validate`, `github-actions / required`, `secret-scan / secretlint`, `GitGuardian Security Checks`) を要求
- これらが pass 後 GitHub auto-merge で `brew bump-cask-pr` が作成した PR が自動 squash merge される

## Git・GitHub 運用ルール

- PR タイトルは英語、semantic commit 形式、小文字開始（`_pull-request.yaml` で検証）
- Release Please が CHANGELOG とバージョンを自動管理。手動でバージョンを変更しない
- YAML ファイルの拡張子は `.yaml` に統一（ツールのデフォルトが `.yml` の場合は Makefile で `--config` / `--spec` を指定）

## リリース・Conventional Commits

- `BREAKING CHANGE:` フッターと `feat!:` / `fix!:` の `!` 修飾は、**リリースされるパッケージ・公開アセットの互換性を破る変更にのみ**使用する。CI / workflows / branch protection / リポジトリ運用上の変更には使わない。これらの注意事項は PR 本文に記述する（release-please など自動リリースツールが major / minor バンプを誤って行い、CHANGELOG に `⚠ BREAKING CHANGES` セクションを誤生成するのを防ぐため。実例: 2026-04-25 にこのリポジトリ群で `chore: migrate reusable workflows to v3.0.0` PR が誤って BREAKING CHANGE として記録された）。

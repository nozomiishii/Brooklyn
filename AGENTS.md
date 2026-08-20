# Repository Guidelines

## Canvas での動作確認

インストールせずにデバッグするには Canvas ターゲットを使う:

```bash
make generate && open Brooklyn.xcodeproj
```

実機で確認するには `make install` で /Applications へ配置し、システム設定のスクリーンセーバー一覧から選ぶ。表示や選択がおかしいときは `make reset` を先に実行する。

## アーキテクチャ

### ターゲット構成

project.yaml で定義する。

- Brooklyn — ホストアプリ (`Brooklyn.app`)。extension を安定したパスで持ち運び、起動時に pluginkit へ登録する
- BrooklynExtension — スクリーンセーバー本体の App Extension。`NSExtensionPointIdentifier: com.apple.screensaver` (private API) でシステムに登録され、独立した sandboxed プロセスで動く
- Canvas — デバッグ用 macOS アプリ。extension と同じソースをビルドし、ウィンドウ内でスクリーンセーバーを表示
- BrooklynTests — ユニットテスト。ソースを直接含めてテスト

### レイヤー構成

```
BrooklynViewController (ScreenSaverViewController サブクラス)
  └── BrooklynView (ScreenSaverView)
        ├── BrooklynManager          # 再生ロジック・選択管理
        │     ├── Database           # ScreenSaverDefaults ラッパー
        │     └── Animation (enum)   # 75 種の動画定義、rawValue がファイル名
        └── LoopPlayer (AVQueuePlayer)  # 無限ループ再生

BrooklynConfigurationViewController (設定シート)
  └── ConfigureSheet (SwiftUI)
        └── ConfigureSheetViewModel
```

## 触る前に読む

壊しやすいポイント。

### private API 依存

`ScreenSaverExtension` / `ScreenSaverViewController` / `ScreenSaverConfigurationViewController` はヘッダ非公開の private クラスで、宣言は BrooklynExtension/PrivateHeaders/ScreenSaverPrivate.h にある。Apple 純正 saver が全て同じ構成のため安定しているが、macOS 更新時は動作確認する。背景は docs/decisions/ の ADR。

### appex の実挙動 (macOS 26 実測)

変更時はテストで regression を確認する。

- 再生の開始・停止は BrooklynViewController の viewDidAppear / viewWillDisappear が駆動する。ScreenSaverView の startAnimation / stopAnimation は framework からは確実には呼ばれない
- `isPreview` は渡ってこない。再生コードは isPreview で分岐しないため、view controller は false を渡す
- player は初回 startAnimation で遅延構築する。サイズ 0 のインスタンスは構築をスキップ
- `AVQueuePlayer` は 1 アイテムで停止する仕様 → `LoopPlayer` が自動複製
- 設定シートに SwiftUI を載せるには NSHostingController + addChild が必須。NSHostingView 単体は ViewBridge のリモートシートで描画されない
- シートを閉じる操作は extension 側の実装が全て。NSApp.keyWindow も sheetParent も nil で、`configureSheetDidEnd` を呼ぶのが唯一の閉じ方
- 一覧に出すには pluginkit 登録 + use への election が要る。WallpaperAgent は解決済みモジュールパスをキャッシュするため、パスが変わったら `make reset`
- legacy の ScreenSaverEngine は appex を起動しない

### Swift 6 Strict Concurrency

- `BrooklynManager`, `Database`, `ConfigureSheetViewModel`, `ExtensionRegistrar` は `@MainActor`
- NotificationCenter オブザーバーは `nonisolated(unsafe)` で保持
- 通知コールバックから `@MainActor` メソッドを呼ぶ際は `MainActor.assumeIsolated` を使用

## Homebrew cask の同名衝突

homebrew/cask に pedrommcarrasco/Brooklyn の `brooklyn` がある。素のトークンはそちらに解決されるため、install / upgrade / info / uninstall のすべてでフルトークンを使う。

```bash
brew upgrade --cask nozomiishii/tap/brooklyn   # 正
brew upgrade --cask brooklyn                   # 誤。別プロジェクトの 2.1.0 に置き換わる
```

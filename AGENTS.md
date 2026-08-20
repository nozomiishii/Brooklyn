# Repository Guidelines

## 動作確認

| 手段 | 手順 |
| --- | --- |
| Canvas ターゲット | `make generate && open Brooklyn.xcodeproj`。インストール不要で、ウィンドウ内で再生する |
| 実機 | `make install` で /Applications へ配置し、システム設定のスクリーンセーバー一覧から選ぶ |

一覧に出ない、選んでも反映されないときは `make reset` を先に実行する。WallpaperAgent が解決済みのパスをキャッシュしている。

## アーキテクチャ

### ターゲット構成

project.yaml で定義する。

| ターゲット | 役割 |
| --- | --- |
| Brooklyn | ホストアプリ (`Brooklyn.app`)。extension を安定したパスで持ち運び、起動時に pluginkit へ登録する |
| BrooklynExtension | スクリーンセーバー本体の App Extension。`NSExtensionPointIdentifier: com.apple.screensaver` でシステムに登録され、独立した sandboxed プロセスで動く |
| Canvas | デバッグ用 macOS アプリ。ウィンドウ内でスクリーンセーバーを表示する |
| BrooklynTests | ユニットテスト |

再生まわりのソースは `Shared/` に置き、BrooklynExtension・Canvas・BrooklynTests の 3 つが同じものをビルドする。ホストアプリだけは `BrooklynApp/` の独自ソースで動く。

### レイヤー構成

```
BrooklynExtension.appex
  BrooklynViewController (ScreenSaverViewController サブクラス)
    └── BrooklynView (ScreenSaverView)
          └── LoopPlayer (AVQueuePlayer)    # 無限ループ再生

  BrooklynConfigurationViewController (設定シート)
    └── ConfigureSheet (SwiftUI)
          └── ConfigureSheetViewModel

  再生アイテムの組み立てに使う。BrooklynView は参照を保持しない
    BrooklynManager                         # 再生ロジック・選択管理
      ├── Database                          # ScreenSaverDefaults ラッパー
      └── Animation (enum)                  # 75 種の動画定義、rawValue がファイル名

Brooklyn.app
  BrooklynApp (SwiftUI App)
    ├── ContentView
    └── ExtensionRegistrar                  # pluginkit 登録・legacy .saver の掃除
```

## 触る前に読む

壊しやすいポイント。

### private API 依存

`ScreenSaverExtension` / `ScreenSaverViewController` / `ScreenSaverConfigurationViewController` はヘッダ非公開の private クラス。宣言は BrooklynExtension/PrivateHeaders/ScreenSaverPrivate.h にある。

Apple 純正 saver が全て同じ構成のため安定しているが、macOS 更新時は動作確認する。この構成を選んだ経緯は [saver をやめアプリ + ScreenSaver App Extension で配布する](<docs/decisions/saver をやめアプリ + ScreenSaver App Extension で配布する.md>)にある。

### appex の実挙動 (macOS 26 実測)

変更時はテストで regression を確認する。

| 実挙動 | 対応 |
| --- | --- |
| ScreenSaverView の startAnimation / stopAnimation は framework から確実には呼ばれない | BrooklynViewController の viewDidAppear / viewWillDisappear で再生を駆動する |
| `isPreview` は渡ってこない | 再生コードは isPreview で分岐しない。view controller は false を渡す |
| 表示されないインスタンスが生成されることがある | player は初回 startAnimation で遅延構築する。サイズ 0 のインスタンスは構築をスキップする |
| `AVQueuePlayer` は 1 アイテムで停止する | `LoopPlayer` が自動複製する |
| NSHostingView 単体は ViewBridge のリモートシートで描画されない | 設定シートに SwiftUI を載せるには NSHostingController + addChild を使う |
| リモートシートでは NSApp.keyWindow も sheetParent も nil | `configureSheetDidEnd` を呼ぶのが唯一の閉じ方。閉じる操作は extension 側の実装が全て |
| WallpaperAgent は解決済みモジュールパスとサムネイルのタイルをキャッシュする | 一覧に出すには pluginkit 登録 + use への election が要る。パスやサムネイルが変わったら `make reset` |

legacy の ScreenSaverEngine は appex を起動しない。

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

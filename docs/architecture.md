---
paths:
  - "Shared/**/*.swift"
  - "BrooklynApp/**/*.swift"
  - "BrooklynExtension/**/*"
  - "Canvas/**/*.swift"
  - "BrooklynTests/**/*.swift"
  - "project.yaml"
---

# アーキテクチャ詳細

CLAUDE.md の「アーキテクチャ」「触る前に読む」節の補足。コードを変更する前に該当箇所を読むこと。

## 再生ロジック (`BrooklynManager.makePlayerItems`)

### Customize OFF

デフォルトの動作。全 75 アニメーション使用。`original` を先頭に 1 回再生 → 残りをランダムシャッフル → `LoopPlayer` が各アイテムを末尾にコピーして無限ループ。

### Customize ON

ユーザー選択のアニメーションのみ使用。ループ回数・ランダム順も設定 (`Database`) に従う。

## App Extension の構成

スクリーンセーバー本体は `Brooklyn.app/Contents/PlugIns/BrooklynExtension.appex`。システムが appex を独立プロセスとして起動し、ディスプレイごとに view controller を生成する。System Settings のプレビューも appex 自身が描画する。

```
選択・起動      System Settings / WallpaperAgent
                     │  pluginkit の登録情報でモジュールを解決
                     ▼
プロセス        BrooklynExtension.appex (sandboxed)
                     │  Info.plist の ScreenSaverViewControllerClass
                     ▼
表示            BrooklynViewController → BrooklynView → LoopPlayer
```

登録は pluginkit が持つ。ホストアプリが起動時に `pluginkit -a` + `-e use` を実行する。WallpaperAgent は解決済みモジュールパスをキャッシュするため、appex のパスが変わったら `killall WallpaperAgent` (`make reset`) が要る。

## ライフサイクル (macOS 26 実測)

- viewDidAppear / viewWillDisappear は開始・停止のたびに確実に届く。再生の開始・停止はここで駆動する
- ScreenSaverView の startAnimation / stopAnimation は framework からは確実には呼ばれない。view controller が呼ぶ
- `com.apple.screensaver.willstop` 通知の購読は BrooklynView に残している。viewWillDisappear が来ない構成が現れたときの第 2 の停止経路で、pause のみ行う。インスタンスは再利用されるため、player を破棄する後始末をここでやってはいけない
- framework は principal class (`BrooklynExtension`) のインスタンスをプロセス内で複数回生成・破棄する。principal は stateless に保つ
- 仮想ディスプレイ (Duet 等) では MediaToolbox が `VRP err=-12852` をクリップ遷移のたびに出し、そのディスプレイの描画が止まることがある (2026-08 実測)。再生自体は進み続けるため、ログ上はエラーの継続だけが手がかり

### 残っている防御

- `isPreview` は渡ってこない。再生コードは isPreview で分岐しないため、view controller は false を渡す
- player は初回 startAnimation で遅延構築する。表示されないインスタンスは 75 本の AVPlayerItem を読み込まず、破棄された player も次の startAnimation で再構築される
- サイズ 0 のインスタンスが生成されることがある → `BrooklynView` が player 構築をスキップ
- `AVQueuePlayer` はキューを使い切ると停止する仕様 → `LoopPlayer` が `AVPlayerItemDidPlayToEndTimeNotification` を監視し、終了したアイテムを末尾に再追加して無限ループ。通知は object: nil で購読するため、自分が所有するアイテムかを `ownedItems` で判定する。プロセス内にはディスプレイごとの player が同居しており、判定なしでは互いのキューを際限なく膨らませる

## 設定シート

System Settings の Options… で `BrooklynConfigurationViewController` が開き、SwiftUI の `ConfigureSheet` を NSHostingController + addChild で載せる。NSHostingView 単体だと ViewBridge のリモートシートで描画されない。

シートを閉じる経路は extension 側の実装が全て。リモートシートでは NSApp.keyWindow・sheetParent・presentingViewController がすべて nil で、`configureSheetDidEnd` (private API、Apple 純正 saver と同じ) を呼ぶのが唯一の閉じ方。Escape でも閉じない。

設定は `ScreenSaverDefaults` のまま。書き先は appex の sandbox コンテナ (`~/Library/Containers/dev.nozomiishii.brooklyn.extension/Data/Library/Preferences/ByHost/`)。

## Swift 6 Strict Concurrency

### `@MainActor` 対象クラス

- `BrooklynManager`
- `Database`
- `ConfigureSheetViewModel`
- `ExtensionRegistrar`

UI / 設定に直接触るため MainActor で隔離。`ExtensionRegistrar` の pluginkit 呼び出しだけは nonisolated な async 関数で main 外に逃がす。

### `NotificationCenter` オブザーバー

`nonisolated(unsafe)` プロパティで保持する。理由: `NSObjectProtocol` トークン自体は thread-safe で actor isolation を要求しないため、わざわざ `@MainActor` で囲む必要がない。むしろデイニシャライザで解放する際に actor 制約が邪魔になる。

### 通知コールバックから `@MainActor` メソッドを呼ぶ

`MainActor.assumeIsolated { ... }` を使用する。`com.apple.screensaver.*` 通知は MainActor 上でディスパッチされる契約のため、`Task { @MainActor in ... }` で async コンテキストを作る必要はない。同期的に MainActor を assume すれば足りる。

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

```
makePlayerItems
  ├── Customize OFF … デフォルト。全 75 アニメーションを使う
  │     → original を先頭に 1 回再生
  │     → 残りをランダムシャッフル
  └── Customize ON  … ユーザーが選んだアニメーションだけを使う
        → ループ回数もランダム順も Database の設定に従う
```

どちらも `LoopPlayer` が無限ループさせる。実現方法は[残っている防御](#残っている防御)に書いた。

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

登録は pluginkit が持ち、ホストアプリの `ExtensionRegistrar` が起動時に更新する。

```
起動   registerAndRefresh()
         │
         ├── 既存の登録が別パスを指していたら pluginkit -r で外す
         │     → 外したときだけ killall WallpaperAgent
         │        (解決済みパスのキャッシュを捨てさせる)
         ├── pluginkit -a <appex パス>
         ├── pluginkit -e use -i <extension id>
         └── refresh()
               → 未登録なら 1 秒待って再確認
                  (pkd が登録を非同期に公開することがある)
```

`make install` も同じ登録をコマンドで行う。開発中に appex のパスが変わったときは `make reset` で WallpaperAgent を落とす。

cask の更新は同じパスへの入れ替えになり、WallpaperAgent が古い解決のまま extension を起動して黒画面になる。tap の cask は install / upgrade の postflight で WallpaperAgent を再起動してこれを防ぐ。

選択画面のタイルは appex から毎回読まれない。legacy プロバイダが thumbnail を一度抽出し、`$(getconf DARWIN_USER_CACHE_DIR)` 配下の `com.apple.wallpaper.extension.legacy/com.apple.wallpaper.legacy.thumbnails/` の PNG と `com.apple.wallpaper.agent/com.apple.wallpaper.view-model-cache/extension-com.apple.wallpaper.extension.legacy-screenSaver` の view-model で持ち続ける。appex を同じパスへ入れ替えても無効化されない (2026-08 実測)。サムネイルを変えたら `make reset` で消す。

## ライフサイクル (macOS 26 実測)

```
開始   viewDidAppear                          → startAnimation()
                                                  → 初回だけ player を構築
停止   viewWillDisappear                      → stopAnimation()
       com.apple.screensaver.willstop 通知    → stopAnimation()
```

view controller のライフサイクルは開始・停止のたびに確実に届くので、再生はここで駆動する。ScreenSaverView の startAnimation / stopAnimation は framework からは確実には呼ばれず、view controller が呼ぶ。

通知の購読は `BrooklynView` に残している。viewWillDisappear が来ない構成が現れたときの第 2 の停止経路。どちらの停止経路も pause しかしない。framework はインスタンスを再利用するため、player を破棄する後始末をここでやると次に開始できなくなる。

framework は principal class (`BrooklynExtension`) のインスタンスをプロセス内で複数回生成・破棄する。principal は stateless に保つ。

仮想ディスプレイ (Duet 等) では MediaToolbox が `VRP err=-12852` をクリップ遷移のたびに出し、そのディスプレイの描画が止まることがある (2026-08 実測)。再生自体は進み続けるため、ログ上はエラーの継続だけが手がかり。

### 残っている防御

| 実挙動 | 防御 |
| --- | --- |
| `isPreview` は渡ってこない | 再生コードは isPreview で分岐しない。view controller は false を渡す |
| 表示されないインスタンスが生成されることがある | player を初回 startAnimation で遅延構築する。表示されなければ 75 本の AVPlayerItem を読み込まず、破棄された player も次の開始で組み直せる |
| サイズ 0 のインスタンスが生成されることがある | `BrooklynView` が player 構築をスキップする |
| `AVQueuePlayer` はキューを使い切ると停止する | `LoopPlayer` が `AVPlayerItemDidPlayToEndTimeNotification` を監視し、終了したアイテムを末尾に再追加する |
| 終了通知は object: nil でしか購読できない | 自分が所有するアイテムかを `ownedItems` で判定する。プロセス内にはディスプレイごとの player が同居しており、判定なしでは互いのキューを際限なく膨らませる |

## 設定シート

System Settings の Options… で `BrooklynConfigurationViewController` が開き、SwiftUI の `ConfigureSheet` を NSHostingController + addChild で載せる。NSHostingView 単体だと ViewBridge のリモートシートで描画されない。

シートを閉じる経路は extension 側の実装が全て。リモートシートでは NSApp.keyWindow・sheetParent・presentingViewController がすべて nil で、`configureSheetDidEnd` (private API、Apple 純正 saver と同じ) を呼ぶのが唯一の閉じ方。Escape でも閉じない。

設定は `ScreenSaverDefaults` のまま。書き先は appex の sandbox コンテナ (`~/Library/Containers/dev.nozomiishii.brooklyn.extension/Data/Library/Preferences/ByHost/`)。

## Swift 6 Strict Concurrency

### `@MainActor` 対象クラス

UI / 設定に直接触るため MainActor で隔離する。

- `BrooklynManager`
- `Database`
- `ConfigureSheetViewModel`
- `ExtensionRegistrar`

`ExtensionRegistrar` の pluginkit 呼び出しだけは nonisolated な async 関数で main 外に逃がす。

### `NotificationCenter` オブザーバー

`nonisolated(unsafe)` プロパティで保持する。`NSObjectProtocol` トークン自体は thread-safe で actor isolation を要求しないため、`@MainActor` で囲む必要がない。デイニシャライザで解放する際は actor 制約が邪魔になる。

### 通知コールバックから `@MainActor` メソッドを呼ぶ

`MainActor.assumeIsolated { ... }` を使用する。`com.apple.screensaver.*` 通知は MainActor 上でディスパッチされる契約のため、`Task { @MainActor in ... }` で async コンテキストを作る必要はない。同期的に MainActor を assume すれば足りる。

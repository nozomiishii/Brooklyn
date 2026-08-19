# .saver をやめアプリ + ScreenSaver App Extension で配布する

Status: accepted
Date: 2026-08-20

## Context — 判断を迫られた状況

legacyScreenSaver 経由の `.saver` は macOS の更新のたびに壊れ、回避コードが[増え続けていた](https://github.com/nozomiishii/Brooklyn/issues/161)。[mise の brew-cask から入らない問題](https://github.com/nozomiishii/homebrew-tap/issues/63)も cask の screen_saver スタンザ由来だった。

選択肢は 3 つ。

- 現状維持。Tahoe では preview の二重起動に回避策が無いことを Aerial の作者が[記録しており](https://github.com/JohnCoates/Aerial/issues/1396)、悪化は続く
- Aerial と同じ、アプリ + ScreenSaver App Extension。`com.apple.screensaver` extension point はヘッダ非公開の private API だが、Apple 純正 saver 全部が同構成で Sonoma から Tahoe まで安定している
- 背景プロセス + フルスクリーンアプリ。システム設定の一覧に出ず、スクリーンセーバーの UX を失う

## Decision — 決めたこと

アプリ + ScreenSaver App Extension を採用する。macOS 26 実機の PoC で、一覧表示・再生・SwiftUI 設定シート・設定永続化・フルスクリーン実走行の全部が通ることを[検証した](https://github.com/nozomiishii/Brooklyn/issues/161#issuecomment-5347557110)。

private API 依存は残る。依存先は予告なく壊れる legacyScreenSaver から、Apple が全純正 saver で使う基盤に変わる。終了時は viewWillDisappear が確実に届くため、最大の問題だった stopAnimation 不発は正攻法で解決する。

## Consequences — 決定がもたらすもの

- 配布物が Brooklyn.app になる。cask は app アーティファクトへ移行でき、mise の brew-cask からも入るようになる
- PrivateHeaders/ScreenSaverPrivate.h の private 宣言を自前保守する。macOS 更新時に動作確認が要る
- 設定は appex の sandbox コンテナに移り、既存ユーザーの選択状態は引き継がれない
- 旧 .saver の掃除が要る
  - Homebrew: cask の入れ替えで消える
  - 手動インストール: アプリ内の削除ボタンで消す

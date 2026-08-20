---
status: accepted
date: 2026-08-20
---

# saver をやめアプリ + ScreenSaver App Extension で配布する

## 背景と課題

legacyScreenSaver 経由の `.saver` は macOS の更新のたびに壊れ、回避コードが[増え続けていた](https://github.com/nozomiishii/Brooklyn/issues/161)。[mise の brew-cask から入らない問題](https://github.com/nozomiishii/homebrew-tap/issues/63)も cask の screen_saver スタンザ由来だった。

## 検討した選択肢

- 現状維持。Tahoe では preview の二重起動に回避策が無いことを Aerial の作者が[記録しており](https://github.com/JohnCoates/Aerial/issues/1396)、悪化は続く
- アプリ + ScreenSaver App Extension。Aerial と同じ構成。`com.apple.screensaver` extension point はヘッダ非公開の private API だが、Apple 純正 saver 全部が同構成で Sonoma から Tahoe まで安定している
- 背景プロセス + フルスクリーンアプリ。システム設定の一覧に出ず、スクリーンセーバーの UX を失う

## 決定

アプリ + ScreenSaver App Extension を採用する。macOS 26 実機の PoC で、一覧表示・再生・SwiftUI 設定シート・設定永続化・フルスクリーン実走行の全部が通ることを[検証した](https://github.com/nozomiishii/Brooklyn/issues/161#issuecomment-5347557110)。

private API 依存は残るが、依存先が変わる。予告なく壊れる legacyScreenSaver から、Apple が全純正 saver で使う基盤へ移る。

## 結果

### 良くなったこと

- 終了時に viewWillDisappear が確実に届く。最大の問題だった stopAnimation 不発が正攻法で解決する
- 配布物が Brooklyn.app になる。cask を app アーティファクトへ移行でき、mise の brew-cask からも入る

### 引き受けたコスト

- PrivateHeaders/ScreenSaverPrivate.h の private 宣言を自前保守する。macOS 更新時に動作確認が要る
- 設定が appex の sandbox コンテナへ移り、既存ユーザーの選択状態は引き継がれない
- 旧 `.saver` の掃除が要る。Homebrew で入れた場合は cask の入れ替えで消え、手動インストールの場合はアプリ内の削除ボタンで消す

### 保留した論点

なし

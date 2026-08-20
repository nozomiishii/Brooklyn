---
status: accepted
date: 2026-08-12
---

# CI の Apple 署名は Apple 純正 CLI の手書きで行う

## 背景と課題

リリース CI に Developer ID 署名 + 公証を[入れる](https://github.com/nozomiishii/Brooklyn/pull/141)にあたり、Apple は GitHub Actions 向けの公式ツールを提供していなかった。公式の抽象化は Xcode GUI と Xcode Cloud だけ。

## 検討した選択肢

| 選択肢 | 評価 |
| --- | --- |
| `security` + `codesign` + `notarytool` を手書き | 中身は GitHub 公式手順のまま。UTM や alt-tab-macos など主要 macOS OSS と同じ構成 |
| コミュニティ Action (Apple-Actions/import-codesign-certs 等) | 名前に反して Apple 非公式の unverified org |
| OSS 再実装 rcodesign | キーチェーン不要で Linux でも動くが、2024-11 を最後にリリースが止まっている |

## 決定

Apple 純正 CLI の手書きを採用する。署名鍵を扱う工程が最もセンシティブで、SHA ピン留めで運用しているこのリポジトリにサードパーティ依存を足すのは方針に反する。

## 結果

### 良くなったこと

- 署名工程の依存がゼロになり、監査対象が workflow 内の bash 約 30 行に閉じる

### 引き受けたコスト

- キーチェーン儀式のボイラープレートを自前保守する。解説は [リリースフロー詳細](../release.md)に置く

### 保留した論点

- Apple が公式 CI ツールを出したら置き換える。検知は[追跡 issue](https://github.com/nozomiishii/Brooklyn/issues/140) でウォッチする

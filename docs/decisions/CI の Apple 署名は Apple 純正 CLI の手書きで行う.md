# CI の Apple 署名は Apple 純正 CLI の手書きで行う

Status: accepted
Date: 2026-08-12

## Context — 判断を迫られた状況

リリース CI に Developer ID 署名 + 公証を入れるにあたり ([#141](https://github.com/nozomiishii/Brooklyn/pull/141))、Apple は GitHub Actions 向けの公式ツールを提供していなかった (公式の抽象化は Xcode GUI と Xcode Cloud のみ)。選択肢は 3 つ。

- コミュニティ Action を使う (Apple-Actions/import-codesign-certs 等)。名前に反して Apple 非公式の unverified org
- OSS 再実装 rcodesign を使う。キーチェーン不要で Linux でも動くが、2024-11 を最後にリリースが止まっている
- `security` + `codesign` + `notarytool` を GitHub 公式ドキュメントの手順どおりに手書きする

## Decision — 決めたこと

Apple 純正 CLI の手書きを採用する。署名鍵を扱う最もセンシティブな工程に、SHA ピン留め運用のこのリポジトリがサードパーティ依存を足すのは方針に反する。手書きといっても中身は GitHub 公式手順のままで、UTM や alt-tab-macos など主要 macOS OSS と同じ構成。

## Consequences — 決定がもたらすもの

- 署名工程の依存がゼロになり、監査対象が workflow 内の bash 約 30 行に閉じる
- キーチェーン儀式のボイラープレートは自前保守になる。解説は docs/release.md に置く
- Apple が公式 CI ツールを出したら置き換える。検知は [#140](https://github.com/nozomiishii/Brooklyn/issues/140) でウォッチする

# リリースフロー詳細

CLAUDE.md の「CI / リリース」節の補足。`release.yaml` / `.github/workflows/*` / Homebrew Cask 関連を変更する前に必ず読むこと。

## ジョブ構成

`release.yaml` は `main` への push / `workflow_dispatch` で起動し、以下 4 ジョブで構成される。

1. **`create-draft-release`** (ubuntu): release-please が conventional commits を集計し、release PR が既にマージされていれば draft release + tag を作成。`release_created` と `tag_name` を outputs として返す
2. **`upload-assets`** (macos-26, `release_created == 'true'` のみ): XcodeGen + `make build` + `make test` で `.saver` をビルドし、`.saver.zip` を GitHub Release に upload 後 publish
3. **`homebrew-update`** (macos-26, `release_created == 'true'` のみ): `brew bump-cask-pr` で `nozomiishii/homebrew-tap` の `Casks/brooklyn.rb` を新バージョンに更新する PR を作成し、出力から PR URL を捕捉して `gh pr merge --auto --squash` で auto-merge を有効化
4. **`release-pr`** (ubuntu, `upload-assets` 失敗時を除き常時): release-please で次の release PR を作成 / 更新

## Homebrew Cask 更新の実装方針

`homebrew-update` は **Homebrew 公式 CLI `brew bump-cask-pr` を直接呼ぶ** 実装。検討した代替案を採用しなかった理由:

### Renovate に任せる（不採用）

`homebrew` manager は **Formula のみ対応**で Cask 未サポート（[renovate#32965](https://github.com/renovatebot/renovate/discussions/32965) が open のまま、コメント 0）。`postUpgradeTasks` で sha256 を再計算する手は Mend Cloud では使えない。

### `mislav/bump-homebrew-formula-action`（不採用）

`homebrew-tap` の `main` が GitHub Rulesets で保護されていると、`branchRes.data.protected === true` 判定で `update-<file>-<timestamp>` という別ブランチに commit を作る経路に入り、`create-pullrequest: false` のままだと PR 化もマージもされず孤立ブランチが残る。ジョブは "success" で終わるためサイレント失敗（実例: `update-git-harvest.rb-1777372050` が放置されていた）。

### 手書き `git push` + `gh pr create`（不採用）

動くが Homebrew エコシステム非標準。本流は公式 [Autobump](https://docs.brew.sh/Autobump) でも使われている `brew bump-cask-pr` / `brew bump --casks`。

### 採用: `brew bump-cask-pr` が肩代わりすること

- 新版 tarball を取得して `sha256` を自動再計算
- `Casks/brooklyn.rb` のフィールド単位更新
- API 経由で commit + PR 作成（重複 PR 検出も内蔵）
- `brew style` での文法検証

## runner 選定

`homebrew-update` は **macos-26** で動かす（`upload-assets` と統一）。Linux runner + `Homebrew/actions/setup-homebrew` も試したが、`Homebrew/actions` が monorepo で個別 tag を持たないため zizmor の `stale-action-refs` ルールに引っかかり、commit pin しても警告が出続ける。macOS runner なら `brew` がプリインストールされているので setup ステップごと不要になる。

## 周辺前提

- GitHub App `nozomiishii-release` に `homebrew-tap` への `contents: write` + `pull-requests: write` 権限が付与済み
- `homebrew-tap` で `allow_auto_merge: true` 有効化済み
- `homebrew-tap` の `main` は GitHub Rulesets で 4 つの required status checks (`pull-request / validate`, `github-actions / required`, `secret-scan / secretlint`, `GitGuardian Security Checks`) を要求
- これらが pass 後 GitHub auto-merge で `brew bump-cask-pr` が作成した PR が自動 squash merge される

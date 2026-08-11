---
paths:
  - ".github/workflows/release.yaml"
  - "Makefile"
  - "release-please-config.json"
  - ".release-please-manifest.json"
---

# リリースフロー詳細

CLAUDE.md の「CI / リリース」節の補足。`release.yaml` / `.github/workflows/*` / Homebrew Cask 関連を変更する前に必ず読むこと。

## ジョブ構成

`release.yaml` は `main` への push / `workflow_dispatch` で起動し、以下 4 ジョブで構成される。

1. **`create-draft-release`** (ubuntu): release-please が conventional commits を集計し、release PR が既にマージされていれば draft release + tag を作成。`release_created` と `tag_name` を outputs として返す
2. **`upload-assets`** (macos-26, `release_created == 'true'` のみ): XcodeGen + `make build` + `make test` で `.saver` をビルドし、Developer ID 署名 + 公証 + staple を経て `.saver.zip` を GitHub Release に upload 後 publish（詳細は後述「署名と公証」）
3. **`homebrew-update`** (macos-26, `release_created == 'true'` のみ): `brew bump-cask-pr` で `nozomiishii/homebrew-tap` の `Casks/brooklyn.rb` を新バージョンに更新する PR を作成し、出力から PR URL を捕捉して `gh pr merge --auto --squash` で auto-merge を有効化
4. **`release-pr`** (ubuntu, `upload-assets` 失敗時を除き常時): release-please で次の release PR を作成 / 更新

## 署名と公証

`upload-assets` はビルド後に次の順で配布物を仕上げる。ローカルビルド (`make build` / `make install`) は ad-hoc 署名のままで、この処理はリリース CI だけで行う。

- `.p12` を一時キーチェーンへ import（job 末尾の cleanup step で削除）
- `codesign --force --options runtime --timestamp` で `Brooklyn.saver` に Developer ID 署名
- `ditto` で zip 化して `notarytool submit --wait` で公証。`Accepted` 以外なら `notarytool log` を出力して fail
- `stapler staple` でチケットをバンドルに貼付し、staple 済みバンドルを配布用 zip に固め直す

補足:

- `--options runtime`（hardened runtime）と `--timestamp` は公証の必須要件
- `Brooklyn.saver` は framework を embed していないため、バンドル 1 回の codesign で完結する（ネスト署名は不要）
- 署名 identity は一時キーチェーンから自動検出する。1Password に identity 文字列は持たない
- 提出用 zip は使い捨てで、配布物は Package step が staple 済みバンドルから作り直す

キーチェーン import は [GitHub 公式手順](https://docs.github.com/ja/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)に準拠。公式手順との相違点:

- キーチェーンパスワードは secret にせず `openssl rand` で実行ごとに生成する。job の中でしか使わない値なので、長命の secret を増やさない
- provisioning profile の step はない。Developer ID 直接配布では使わない
- `.p12` ファイルは import 直後に削除する
- cleanup は公式手順だと self-hosted runner のみ必要とされるが、防御的に常に実行する

### 1Password vault `apple-developer`

Apple の鍵は共有の `github-app` vault ではなく専用 vault に置く。vault の切り方は「同じ場所に配る鍵は同じ vault」を基準にする。

- service account は repo ごとに 1 つ (Brooklyn 用は「Brooklyn」)。`apple-developer` vault を読めるのは Brooklyn の service account だけにし、他リポジトリの CI が侵害されても署名鍵に届かないようにする
- 1Password の service account は作成後に vault の追加・権限変更ができない ([公式](https://www.1password.dev/service-accounts/manage-service-accounts/))。アクセスする vault を増やすときは service account を作り直し、`OP_SERVICE_ACCOUNT_TOKEN` の値を新トークンに差し替える
- 鍵が漏れた・漏れた疑いがある場合は、この vault の全アイテムをローテーションする

| item | フィールド | 内容 |
| --- | --- | --- |
| `developer-id` | `certificate-p12` | Developer ID Application 証明書 + 秘密鍵の .p12 を base64 化した文字列 |
| `developer-id` | `p12-password` | .p12 エクスポート時に設定したパスワード |
| `app-store-connect` | `key-id` | App Store Connect API キーの Key ID |
| `app-store-connect` | `issuer-id` | App Store Connect API の Issuer ID |
| `app-store-connect` | `private-key` | API キー .p8 の中身（PEM テキスト） |

### 鍵の更新

- Developer ID Application 証明書は有効期限 5 年。期限が切れたら Xcode → Settings → Accounts → Manage Certificates で作り直し、Keychain Access から .p12 を書き出して `certificate-p12` / `p12-password` を更新する。署名 identity は workflow がキーチェーンから自動検出するため identity 文字列の登録は不要
- 公証済みの配布物は証明書が失効しても有効なまま（staple されたチケットで検証される）
- App Store Connect API キーに期限はないが、revoke したら `app-store-connect` item の `key-id` / `private-key` を差し替える

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

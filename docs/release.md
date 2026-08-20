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

`release.yaml` は `main` への push / `workflow_dispatch` で起動する。

```
create-draft-release (ubuntu)
  │  outputs: release_created / tag_name
  ▼
upload-assets (macos-26)          release_created == 'true' のときだけ
  ├── homebrew-update (macos-26)  同上
  └── release-pr (ubuntu)         upload-assets が失敗したときを除き常に走る
```

- `create-draft-release`: release-please が conventional commits を集計し、release PR が既にマージされていれば draft release + tag を作成
- `upload-assets`: XcodeGen + `make build` + `make test` で `Brooklyn.app` (screen saver extension 内蔵) をビルドし、[署名と公証](#署名と公証)を経て `Brooklyn.app.zip` を GitHub Release に upload 後 publish
- `homebrew-update`: `brew bump-cask-pr` で `nozomiishii/homebrew-tap` の `Casks/brooklyn.rb` を更新する PR を作り、`gh pr merge --auto --squash` で auto-merge を有効化
- `release-pr`: release-please で次の release PR を作成 / 更新

## 署名と公証

`upload-assets` はビルド後に配布物を仕上げる。ローカルビルド (`make build` / `make install`) は ad-hoc 署名のままで、この処理はリリース CI だけで行う。

```
security import      .p12 を一時キーチェーンへ。job 末尾の cleanup step で削除
      ▼
codesign             inside-out に署名
      │                先に BrooklynExtension.appex
      │                次に Brooklyn.app
      ▼
codesign --verify    --deep でネスト込みに検証。appex の署名から
      │                app-sandbox が落ちていたら fail
      ▼
notarytool submit    ditto で固めた zip を提出。Accepted 以外なら
      │                notarytool log を出力して fail
      ▼
stapler staple       チケットをバンドルに貼付
      ▼
ditto                staple 済みバンドルを配布用 zip に固め直す
```

`codesign` は `--force --options runtime --timestamp` で呼ぶ。hardened runtime を有効にする `--options runtime` と `--timestamp` は、どちらも公証の必須要件。

`--force` は既存の entitlements を落とすため、appex には `--entitlements` で BrooklynExtension/BrooklynExtension.entitlements を渡し直す。app 側は entitlements 無し。

署名 identity は一時キーチェーンから自動検出する。1Password に identity 文字列は持たない。

提出用 zip は使い捨てで、配布物は Package step が staple 済みバンドルから作り直す。

キーチェーン import は [GitHub 公式手順](https://docs.github.com/ja/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)に準拠する。変えたのは次の 4 点。

- キーチェーンパスワードは secret にせず `openssl rand` で実行ごとに生成する。job の中でしか使わない値なので、長命の secret を増やさない
- provisioning profile の step はない。Developer ID 直接配布では使わない
- `.p12` ファイルは import 直後に削除する
- cleanup は公式手順だと self-hosted runner のみ必要とされるが、防御的に常に実行する

### 1Password vault `apple-developer`

Apple の鍵は共有の `nozomiishii-release` vault ではなく専用 vault に置く。vault の切り方は「同じ場所に配る鍵は同じ vault」を基準にする。

- service account は repo ごとに 1 つ (Brooklyn 用は「Brooklyn」)。`apple-developer` vault を読めるのは Brooklyn の service account だけにし、他リポジトリの CI が侵害されても署名鍵に届かないようにする
- 1Password の service account は作成後に vault の追加・権限変更ができない ([公式](https://www.1password.dev/service-accounts/manage-service-accounts/))。アクセスする vault を増やすときは service account を作り直し、`OP_SERVICE_ACCOUNT_TOKEN` の値を新トークンに差し替える
- 鍵が漏れた・漏れた疑いがある場合は、この vault の全アイテムをローテーションする

| item | フィールド | 内容 |
| --- | --- | --- |
| `developer-id` | `certificate-p12` | Developer ID Application 証明書 + 秘密鍵の .p12 を base64 化した文字列 |
| `developer-id` | `p12-password` | .p12 エクスポート時に設定したパスワード |
| `app-store-connect` | `key-id` | App Store Connect API キーの Key ID |
| `app-store-connect` | `issuer-id` | App Store Connect API の Issuer ID |
| `app-store-connect` | `private-key` | API キー .p8 を base64 化した文字列。改行を含む PEM をフィールドで壊さず保持するため |

### 鍵の更新

- Developer ID Application 証明書は有効期限 5 年。期限が切れたら Xcode → Settings → Accounts → Manage Certificates で作り直し、Keychain Access から .p12 を書き出して `certificate-p12` / `p12-password` を更新する。署名 identity は workflow がキーチェーンから自動検出するため identity 文字列の登録は不要
- 公証済みの配布物は証明書が失効しても有効なまま。staple されたチケットで検証される
- App Store Connect API キーに期限はないが、revoke したら `app-store-connect` item の `key-id` / `private-key` を差し替える

## Homebrew Cask 更新の実装方針

`homebrew-update` は Homebrew 公式 CLI `brew bump-cask-pr` を直接呼ぶ。

| 手段 | 採否 |
| --- | --- |
| `brew bump-cask-pr` | 採用。公式 [Autobump](https://docs.brew.sh/Autobump) でも使われている本流 |
| Renovate に任せる | `homebrew` manager は Formula のみ対応で Cask 未サポート。[要望の issue](https://github.com/renovatebot/renovate/discussions/32965) は open のままコメント 0。`postUpgradeTasks` で sha256 を再計算する手は Mend Cloud では使えない |
| `mislav/bump-homebrew-formula-action` | サイレント失敗する。下に詳しく書いた |
| 手書き `git push` + `gh pr create` | 動くが Homebrew エコシステム非標準 |

`brew bump-cask-pr` が肩代わりするのは次の 4 つ。

- 新版 tarball を取得して `sha256` を自動再計算
- `Casks/brooklyn.rb` のフィールド単位更新
- API 経由で commit + PR 作成。重複 PR 検出も内蔵
- `brew style` での文法検証

### `mislav/bump-homebrew-formula-action` のサイレント失敗

`homebrew-tap` の `main` は GitHub Rulesets で保護されている。この action は `branchRes.data.protected === true` を見て、`update-<file>-<timestamp>` という別ブランチに commit を作る経路へ入る。`create-pullrequest: false` のままだと PR 化もマージもされず、孤立ブランチだけが残る。

ジョブは success で終わるため気付けない。実例として `update-git-harvest.rb-1777372050` が放置されていた。

## runner 選定

`homebrew-update` は macos-26 で動かし、runner を `upload-assets` と統一する。macOS runner なら `brew` がプリインストールされているので setup ステップごと不要になる。

Linux runner + `Homebrew/actions/setup-homebrew` も試したが、`Homebrew/actions` が monorepo で個別 tag を持たないため zizmor の `stale-action-refs` に引っかかり、commit pin しても警告が出続ける。

## 周辺前提

- GitHub App `nozomiishii-release` に `homebrew-tap` への `contents: write` + `pull-requests: write` 権限が付与済み
- `homebrew-tap` で `allow_auto_merge: true` 有効化済み
- `homebrew-tap` の `main` は GitHub Rulesets で 4 つの required status checks (`pull-request / validate`, `github-actions / required`, `secret-scan / secretlint`, `GitGuardian Security Checks`) を要求
- これらが pass 後 GitHub auto-merge で `brew bump-cask-pr` が作成した PR が自動 squash merge される

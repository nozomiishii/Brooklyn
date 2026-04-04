# Brooklyn

[English](./README.md) | 日本語

[Apple の 2018 年 Brooklyn イベント](https://www.apple.com/newsroom/2018/10/highlights-from-apples-keynote-event/)にインスパイアされた macOS スクリーンセーバー。75 種類の美しい Apple ロゴアニメーションが画面でループし続けます。

[Pedro Carrasco のオリジナル Brooklyn](https://github.com/pedrommcarrasco/Brooklyn) を Swift 6 / macOS 26 (Tahoe) / Apple Silicon 向けに再実装したものです。

## Requirements

- macOS 26 (Tahoe) 以降
- Apple Silicon (arm64)

## Install

### GitHub Releases からダウンロード

1. [最新リリース](https://github.com/nozomiishii/Brooklyn/releases/latest)から `Brooklyn.saver.zip` をダウンロード
2. 解凍して `Brooklyn.saver` をダブルクリック
3. macOS がインストールするか聞いてくるので **Install** をクリック

### ソースからビルド

```sh
make install
```

`.saver` バンドルをビルドし、`~/Library/Screen Savers/` にコピーして署名します。

## Uninstall

```sh
make uninstall
```

または **システム設定 > スクリーンセーバー** から手動で削除できます。

## Customization

**システム設定 > スクリーンセーバー > Brooklyn** を開いてオプションボタンをクリックします。

- **Customize OFF（デフォルト）**: 全 75 アニメーションがランダム順で再生。オリジナルの Apple ロゴが最初に流れます
- **Customize ON**: お気に入りのアニメーションを選んで、ループ回数やシャッフル順を設定できます

## 謝辞

Brooklyn はこれらの素晴らしいプロジェクトなしには存在しませんでした。Screen Saver中のMacも美しいです。

- [Brooklyn by Pedro Carrasco](https://github.com/pedrommcarrasco/Brooklyn) オリジナルの Brooklyn スクリーンセーバー。伝説的です。
- [Apple の Brooklyn イベント (2018)](https://www.apple.com/newsroom/2018/10/highlights-from-apples-keynote-event/) 僕がAppleに入社した時Zのイベント。同時期にあった[Apple 渋谷のリニューアルオープンビデオ](https://www.youtube.com/watch?v=30rXa448tGA)とも重なって[ANIMAL HACKさんのFranny](https://open.spotify.com/track/31a06sRIW6qMMfONkhl9yR)がずっと脳内再生されてます。思い出深いです。しみじみです。

## License

[MIT](LICENSE)

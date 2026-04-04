# Brooklyn

English | [日本語](./README.ja.md)

<br>
<div align="center">
  <img src="demo/demo.gif" alt="Brooklyn" width="600" />
</div>
<br>

A macOS screen saver inspired by [Apple's 2018 Brooklyn event](https://www.apple.com/newsroom/2018/10/highlights-from-apples-keynote-event/). 75 mesmerizing Apple logo animations looping endlessly on your screen.

A reimplementation of [Pedro Carrasco's original Brooklyn](https://github.com/pedrommcarrasco/Brooklyn), rebuilt for Swift 6, macOS 26 (Tahoe), and Apple Silicon.

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon (arm64)

## Install

### Homebrew

```sh
brew install nozomiishii/tap/brooklyn
```

### Build from source

```sh
make install
```

This builds the `.saver` bundle, copies it to `~/Library/Screen Savers/`, and signs it.

## Uninstall

```sh
brew uninstall nozomiishii/tap/brooklyn
```

If you built from source, run `make uninstall` instead. Or remove it manually from **System Settings > Screen Saver**.

## Customization

Open **System Settings > Screen Saver > Brooklyn** and click the options button.

- **Customize OFF (default)**: All 75 animations play in random order, starting with the original Apple logo
- **Customize ON**: Pick your favorite animations and control the loop count and shuffle order

## Acknowledgments

Brooklyn wouldn't exist without these amazing projects. Your Mac looks beautiful even during screen saver time.

- [Brooklyn by Pedro Carrasco](https://github.com/pedrommcarrasco/Brooklyn) The original Brooklyn screen saver. Truly legendary.
- [Apple's Brooklyn event (2018)](https://www.apple.com/newsroom/2018/10/highlights-from-apples-keynote-event/) The event around when I joined Apple. It overlaps in my memory with the [Apple Shibuya reopening video](https://www.youtube.com/watch?v=30rXa448tGA) from the same time, and [ANIMAL HACK's Franny](https://open.spotify.com/track/31a06sRIW6qMMfONkhl9yR) keeps playing in my head. Deeply nostalgic.

## License

[MIT](LICENSE)

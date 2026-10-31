# herdr-fork-pkg

Arch package for my [herdr](https://github.com/vyorkin/herdr-fork) fork, which
adds `keys.direct_keys` and `herdr pane direct-keys`: prefix-free keybindings
can be handed to the pane's application instead of always staying with Herdr.

## Build and install

```sh
makepkg -s
sudo pacman -U herdr-*.pkg.tar.*
herdr server stop   # a running server keeps the old binary until restarted
```

`arch=('x86_64' 'aarch64')`, so each architecture builds on its own host. The
package keeps the upstream `herdr` name and replaces the distribution build.
`pkgver` ends in `.fork.N`, which sorts below the next upstream release, so an
`omarchy update` takes the official package back; reinstall this one to keep the
patch. `herdr update` also installs an official release over it.

## What the fork changes

`keys.direct_keys` accepts `herdr` (default), `auto`, and `pane`. `auto`
forwards direct chords to the pane while its application is on the alternate
screen, so Neovim and pagers keep `ctrl+letter` while a plain shell still sends
those chords to Herdr. `herdr pane direct-keys` sets the same choice per pane.

Bump `_commit` in the PKGBUILD and `pkgver` together when the fork branch moves.

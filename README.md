# herdr-fork-pkg

Arch package for my [herdr](https://github.com/vyorkin/herdr-fork) fork, which
adds `keys.direct_keys` and `herdr pane direct-keys`: prefix-free keybindings
can be handed to the pane's application instead of always staying with Herdr.

## Take an upstream update

```sh
./update.sh              # fetch upstream, rebase the patch, run format/clippy/tests/docs
./update.sh --build      # ...and rebuild the package
./update.sh --install    # ...and install it (needs cached sudo)
./update.sh --restart    # ...and restart the server, unless an agent is working
```

`update.sh` keeps two branches in `~/Projects/herdr-src` apart:

- `master` tracks `upstream/master` and is never edited, so `git fetch upstream`
  always moves forward cleanly.
- `feat/direct-keys-passthrough` is the fork's single commit, rebased onto
  upstream on every update.

The script enables `rerere`, stops on a conflicting rebase and lists the
conflicted files, then verifies the result with the fork's own tests
(`input_domain::*direct_keys*`, `pane_direct_keys_set_*`), the API-shape and
schema contracts, and the config-reference and translation-parity checks. It
then rewrites `_commit`/`pkgver`/`_zigver` in the PKGBUILD from the checkout,
exports the patch series to `patches/`, and force-pushes the fork branch with
`--force-with-lease`.

`patches/` is the fallback: `git am patches/*.patch` reproduces the feature on a
clean upstream clone when a rebase is not the right tool.

The zig version comes from `vendor/libghostty-vt/build.zig.zon` and is looked up
in mise (`mise install zig@<ver>`) before falling back to `PATH`.

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

## Upstream

Herdr's `CONTRIBUTING.md` does not accept unsolicited pull requests: only
verified maintainers and people in `.github/APPROVED_CONTRIBUTORS` may send
implementation PRs, and everything else is closed automatically. Feature
requests go to GitHub Discussions. So this fork stays personal unless the
maintainers invite the change; the branch is written to be reviewable in case
they do, with tests, docs, API schema, and a changelog entry.

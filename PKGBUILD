# Maintainer: Vasiliy Yorkin <vasiliy.yorkin@gmail.com>
#
# Personal fork of herdr with direct-keybinding passthrough:
# keys.direct_keys and `herdr pane direct-keys` let a pane keep the
# prefix-free chords its own application needs.
#
# The package keeps the upstream name so it replaces the distribution build
# through `pacman -U`, and the .fork. pkgver keeps it below the next upstream
# release, so an `omarchy update` picks the official package back up. Reinstall
# this package afterwards if you still want the patch.

pkgname=herdr
pkgver=0.9.5.fork.1
pkgrel=3
pkgdesc="Herdr terminal workspace manager for AI coding agents (vyorkin fork: direct key passthrough)"
arch=('x86_64' 'aarch64')
url="https://github.com/vyorkin/herdr-fork"
license=('Apache-2.0')
depends=('gcc-libs' 'glibc')
makedepends=('cargo')
conflicts=('omarchy-herdr')
replaces=('omarchy-herdr')
options=('!debug' '!lto')

# Full commit that carries the feature. Bump it and pkgver together;
# GitHub archives unpack into herdr-fork-<full sha>.
_commit=0ae4c42f00476577b50e888542fd53270f42eba5
_zigver=0.16.0
source=("herdr-fork-$_commit.tar.gz::$url/archive/$_commit.tar.gz")
source_x86_64=("zig-x86_64-linux-$_zigver.tar.xz::https://ziglang.org/download/$_zigver/zig-x86_64-linux-$_zigver.tar.xz")
source_aarch64=("zig-aarch64-linux-$_zigver.tar.xz::https://ziglang.org/download/$_zigver/zig-aarch64-linux-$_zigver.tar.xz")
sha256sums=('SKIP')
sha256sums_x86_64=('SKIP')
sha256sums_aarch64=('SKIP')

prepare() {
  cd "herdr-fork-$_commit"

  cargo fetch --locked --target "$CARCH-unknown-linux-gnu"
}

build() {
  cd "herdr-fork-$_commit"

  export CARGO_TARGET_DIR=target
  export ZIG="$srcdir/zig-$CARCH-linux-$_zigver/zig"
  export ZIG_GLOBAL_CACHE_DIR="$srcdir/zig-cache"
  cargo build --frozen --release
}

package() {
  cd "herdr-fork-$_commit"

  install -Dm755 target/release/herdr "$pkgdir/usr/bin/herdr"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}

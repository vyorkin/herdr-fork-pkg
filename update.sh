#!/usr/bin/env bash
#
# Rebase the herdr fork patch onto upstream, verify it, repackage it.
#
#   ./update.sh                 # fetch upstream, rebase the patch, run the checks
#   ./update.sh --build         # ... then rebuild the Arch package
#   ./update.sh --install       # ... then install it (needs cached sudo)
#   ./update.sh --restart       # ... then restart the herdr server if it is idle
#
# The script never resolves conflicts for you: a rebase that needs one stops
# with the conflicted files listed, so an agent or a human can look at the
# upstream change with the whole diff in hand.
set -euo pipefail

SRC="${HERDR_SRC:-$HOME/Projects/herdr-src}"
PKG_DIR="${HERDR_PKG_DIR:-$HOME/Projects/personal/herdr-fork-pkg}"
BRANCH="${HERDR_FORK_BRANCH:-feat/direct-keys-passthrough}"
UPSTREAM_REF="${HERDR_UPSTREAM_REF:-upstream/master}"

BUILD=0
INSTALL=0
RESTART=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --build) BUILD=1 ;;
    --install) BUILD=1; INSTALL=1 ;;
    --restart) BUILD=1; INSTALL=1; RESTART=1 ;;
    --force) FORCE=1 ;;
    -h | --help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$SRC/.git" ] || die "$SRC is not a git checkout"
[ -d "$PKG_DIR/PKGBUILD" ] || [ -f "$PKG_DIR/PKGBUILD" ] || die "$PKG_DIR has no PKGBUILD"

step "fetch upstream"
git -C "$SRC" fetch --prune upstream "+refs/heads/master:refs/remotes/upstream/master" --tags
git -C "$SRC" config rerere.enabled true
git -C "$SRC" config rerere.autoUpdate true

step "switch to $BRANCH"
if [ -n "$(git -C "$SRC" status --porcelain)" ]; then
  die "$SRC has uncommitted changes; commit or stash them first"
fi
git -C "$SRC" switch "$BRANCH"

step "rebase onto $UPSTREAM_REF"
if ! git -C "$SRC" rebase "$UPSTREAM_REF"; then
  echo
  echo "Rebase stopped. Conflicted files:"
  git -C "$SRC" diff --name-only --diff-filter=U | sed 's/^/  /'
  cat <<'EOF'

Resolve the conflicts, then:

  git -C "$SRC" add <files>
  git -C "$SRC" rebase --continue
  ./update.sh

Tests in the fork's commit (input_domain::*direct_keys*, pane_direct_keys_set_*)
are the guard: if the rebase kept them failing, the feature is broken.
EOF
  exit 1
fi
git -C "$SRC" log --oneline "$UPSTREAM_REF"..HEAD | sed 's/^/  /'

zigver="$(sed -n 's/.*minimum_zig_version = "\([0-9.]*\)".*/\1/p' \
  "$SRC/vendor/libghostty-vt/build.zig.zon")"
[ -n "$zigver" ] || die "could not read the required zig version"
zig="$HOME/.local/share/mise/installs/zig/$zigver/zig"
if [ ! -x "$zig" ]; then
  zig="$(command -v zig || true)"
fi
[ -x "$zig" ] || die "zig $zigver not found; run: mise install zig@$zigver"
[ "$("$zig" version)" = "$zigver" ] || die "zig $zigver required, $zig is $("$zig" version)"
export ZIG="$zig"

# Run cargo from the checkout: rust-toolchain.toml pins the toolchain by cwd.
step "format"
if ! (cd "$SRC" && cargo fmt --check --quiet); then
  (cd "$SRC" && cargo fmt)
  echo "reformatted; review and amend the fork commit"
fi

step "clippy"
(cd "$SRC" && cargo clippy --all-targets --locked -- -D warnings)

step "fork tests"
(cd "$SRC" && cargo test --bin herdr --quiet -- \
  direct_keys pane_direct_keys pane_choices_cover parse_pane_direct_keys \
  advertised_client_shell_method_shapes generated_protocol_schema_artifact_is_current \
  operation_ui_impact pane_projection_all_leaf client::shell::tests::input)

step "docs contracts"
python3 "$SRC/scripts/config_reference_check.py" --model-root "$SRC/src/config" \
  --reference "$SRC/docs/next/website/src/data/config-reference.json"
python3 "$SRC/scripts/docs_translation_parity.py" \
  --docs-root "$SRC/docs/next/website/src/content/docs"

step "export patches"
rm -rf "$PKG_DIR/patches"
mkdir -p "$PKG_DIR/patches"
git -C "$SRC" format-patch --no-signature --quiet -o "$PKG_DIR/patches" "$UPSTREAM_REF"..HEAD
ls "$PKG_DIR/patches" | sed 's/^/  /'

step "update PKGBUILD"
commit="$(git -C "$SRC" rev-parse HEAD)"
pkgver_base="$(sed -n 's/^version = "\(.*\)"/\1/p' "$SRC/Cargo.toml" | head -1)"
old_pkgver="$(sed -n 's/^pkgver=//p' "$PKG_DIR/PKGBUILD")"
old_commit="$(sed -n 's/^_commit=//p' "$PKG_DIR/PKGBUILD")"
pkgrel="$(sed -n 's/^pkgrel=//p' "$PKG_DIR/PKGBUILD")"
pkgver="$pkgver_base.fork.1"
if [ "$pkgver" = "$old_pkgver" ] && [ "$commit" != "$old_commit" ]; then
  pkgrel="$((pkgrel + 1))"
fi
sed -i \
  -e "s/^pkgver=.*/pkgver=$pkgver/" \
  -e "s/^pkgrel=.*/pkgrel=$pkgrel/" \
  -e "s/^_commit=.*/_commit=$commit/" \
  -e "s/^_zigver=.*/_zigver=$zigver/" \
  "$PKG_DIR/PKGBUILD"
printf '  %s-%s, %s\n' "$pkgver" "$pkgrel" "$commit"

step "push fork branch"
git -C "$SRC" push --force-with-lease origin "$BRANCH"

if [ "$BUILD" = 0 ]; then
  echo
  echo "Checks passed. Repackage with: ./update.sh --build (or --install, --restart)"
  exit 0
fi

step "build package"
(cd "$PKG_DIR" && makepkg -s -f --noconfirm)
package="$(ls -t "$PKG_DIR"/herdr-"$pkgver-$pkgrel"-*.pkg.tar.* | head -1)"
echo "  $package"

[ "$INSTALL" = 1 ] || exit 0

step "install package"
# sudo without a password when the timestamp is cached, otherwise through
# SUDO_ASKPASS so the same command works on a host that wants one.
if [ -n "${SUDO_ASKPASS:-}" ]; then
  sudo -A -v || die "sudo -A failed; check SUDO_ASKPASS"
else
  sudo -n true 2>/dev/null ||
    die "sudo needs a password here; set SUDO_ASKPASS or run: sudo pacman -U $package"
fi
sudo "${SUDO_ASKPASS:+-A}" pacman -U --noconfirm "$package"

[ "$RESTART" = 1 ] || {
  echo
  echo "The running server keeps the old binary until it restarts:"
  echo "  herdr server stop && setsid herdr server"
  exit 0
}

step "restart server"
if [ "$FORCE" = 0 ] && herdr api snapshot 2>/dev/null |
  grep -q '"agent_status": *"working"'; then
  die "an agent is working in a pane; rerun with --restart --force or restart by hand"
fi
herdr server stop || true
sleep 2
setsid herdr server >/dev/null 2>&1 < /dev/null &
sleep 8
herdr status server | sed -n '2p'

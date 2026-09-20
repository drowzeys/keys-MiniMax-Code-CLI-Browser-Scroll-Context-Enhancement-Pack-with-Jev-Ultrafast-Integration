#!/usr/bin/env bash
# Reapply the pack after an MCode self-update. This is intentionally best-effort:
# a failed rebuild must never prevent the official launcher from starting.
set -euo pipefail

PACK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
INSTALL_ROOT="${MCODE_INSTALL_ROOT:-$HOME/.minimax-code}"
CURRENT_LINK="$INSTALL_ROOT/current"
STAMP_FILE="${MCODE_ENHANCEMENT_STAMP:-$INSTALL_ROOT/.mcode-enhancement-pack-applied}"
BUILD_ROOT="${MCODE_ENHANCEMENT_BUILD_ROOT:-$HOME/.cache/mcode-enhancement-pack/build}"
SOURCE_TREE="${MCODE_SOURCE_TREE:-/home/keyspark/minimax-code}"
SOURCE_REF="${MCODE_SOURCE_REF:-main}"
UPSTREAM_URL="${MCODE_UPSTREAM_URL:-https://github.com/MiniMax-AI/minimax-code.git}"

warn() { printf 'mcode enhancement maintenance: %s\n' "$*" >&2; }

[ -e "$CURRENT_LINK" ] || exit 0
RELEASE_DIR="$(readlink -f "$CURRENT_LINK")"
VERSION="$(basename "$RELEASE_DIR")"
ACTIVE_PACKAGE="$RELEASE_DIR/lib/node_modules/@minimax-ai/code"
[ -f "$ACTIVE_PACKAGE/package.json" ] || exit 0

if [ -f "$STAMP_FILE" ] && grep -Fxq "$VERSION" "$STAMP_FILE"; then
  exit 0
fi

LOCK_DIR="${MCODE_ENHANCEMENT_LOCK:-$HOME/.cache/mcode-enhancement-pack/lock}"
mkdir -p "$(dirname "$LOCK_DIR")"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

mkdir -p "$BUILD_ROOT"
if [ -f "$SOURCE_TREE/package.json" ] && [ -d "$SOURCE_TREE/.git" ]; then
  BUILD_TREE="$SOURCE_TREE"
  warn "using source tree $BUILD_TREE"
else
  BUILD_TREE="$BUILD_ROOT/mcode-$VERSION"
  if [ ! -d "$BUILD_TREE/.git" ]; then
    warn "cloning $UPSTREAM_URL ($SOURCE_REF)"
    git clone --filter=blob:none --depth 1 --branch "$SOURCE_REF" "$UPSTREAM_URL" "$BUILD_TREE"
  fi
fi

apply_patch_file() {
  local patch="$1"
  if git -C "$BUILD_TREE" apply --check "$patch" >/dev/null 2>&1; then
    git -C "$BUILD_TREE" apply "$patch"
  elif git -C "$BUILD_TREE" apply --reverse --check "$patch" >/dev/null 2>&1; then
    :
  else
    warn "cannot apply $(basename "$patch") to $BUILD_TREE"
    return 1
  fi
}

apply_patch_file "$PACK_DIR/patches/0001-tui-transcript-scrollbar.patch"
apply_patch_file "$PACK_DIR/patches/0002-tui-context-meter-status-item.patch"
apply_patch_file "$PACK_DIR/patches/0003-continuous-context-renewal-25-percent.patch"

if ! command -v pnpm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
  warn "node and pnpm are required to rebuild version $VERSION"
  exit 1
fi

if ! (cd "$BUILD_TREE" && pnpm install --frozen-lockfile && node scripts/build.mjs); then
  warn "patched rebuild failed for version $VERSION"
  exit 1
fi

if [ ! -d "$BUILD_TREE/dist" ]; then
  warn "build completed without a dist directory"
  exit 1
fi
cp -a "$BUILD_TREE/dist/." "$ACTIVE_PACKAGE/"
mkdir -p "$(dirname "$STAMP_FILE")"
stamp_tmp="$STAMP_FILE.tmp.$$"
printf '%s\n' "$VERSION" > "$stamp_tmp"
mv "$stamp_tmp" "$STAMP_FILE"
warn "reapplied pack to MCode $VERSION"

#!/usr/bin/env bash
# Apply the complete MCode enhancement pack to a checked-out MCode source tree.
# Usage: ./install-one-shot.sh [/path/to/minimax-code]
set -euo pipefail

PACK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
SOURCE_TREE="${1:-${MCODE_SOURCE_TREE:-/home/keyspark/minimax-code}}"

if [ ! -d "$SOURCE_TREE/.git" ]; then
  echo "MCode source tree not found: $SOURCE_TREE" >&2
  echo "Usage: $0 /path/to/minimax-code" >&2
  exit 1
fi

echo "Applying MCode patches to $SOURCE_TREE"
for patch in \
  "$PACK_DIR/patches/0001-tui-transcript-scrollbar.patch" \
  "$PACK_DIR/patches/0002-tui-context-meter-status-item.patch" \
  "$PACK_DIR/patches/0003-continuous-context-renewal-25-percent.patch"; do
  if git -C "$SOURCE_TREE" apply --check "$patch" >/dev/null 2>&1; then
    git -C "$SOURCE_TREE" apply "$patch"
    echo "applied: $(basename "$patch")"
  elif git -C "$SOURCE_TREE" apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "already applied: $(basename "$patch")"
  else
    echo "cannot apply cleanly: $(basename "$patch")" >&2
    echo "Review the source version and apply the patch manually." >&2
    exit 1
  fi
done

echo "Enforcing the safe local-vLLM context ceiling"
python3 "$PACK_DIR/compaction-fix/set-glm53-context-limit.py" --limit "${CONTINUOUS_COMPACTION_LIMIT:-64000}"

mkdir -p "$HOME/.local/bin"
USER_LAUNCHER="$HOME/.local/bin/mcode-enhanced"
if [ -e "$USER_LAUNCHER" ] && ! grep -q "$PACK_DIR/maintenance/maintain-active-mcode.sh" "$USER_LAUNCHER" 2>/dev/null; then
  echo "NOTE: preserving existing $USER_LAUNCHER; install the pack launcher elsewhere if needed."
else
  install -m 0755 "$PACK_DIR/bin/mcode-enhanced" "$USER_LAUNCHER"
  echo "installed automatic launcher: $USER_LAUNCHER"
fi

if [ -x "$HOME/.local/bin/mcode" ] && grep -q 'enforce-continuous-compaction.sh' "$HOME/.local/bin/mcode"; then
  echo "launch enforcer: already wired into $HOME/.local/bin/mcode"
else
  echo "NOTE: wire compaction-fix/enforce-continuous-compaction.sh into your mcode launcher."
fi

if [ -x "$HOME/.local/bin/mcode" ] && grep -q 'maintain-active-mcode.sh' "$HOME/.local/bin/mcode"; then
  echo "update reapply hook: already wired into $HOME/.local/bin/mcode"
else
  echo "NOTE: wire maintenance/maintain-active-mcode.sh into your mcode launcher."
fi

echo
echo "Done. Restart MCode so the new context policy is loaded."
echo "Run: $PACK_DIR/compaction-fix/check-status.sh"
echo "Launch future sessions with: $USER_LAUNCHER"
echo "Set MCODE_SOURCE_TREE if the MCode source is not /home/keyspark/minimax-code."

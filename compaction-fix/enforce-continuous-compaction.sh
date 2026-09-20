#!/usr/bin/env bash
# enforce-continuous-compaction.sh — launch-time guarantee for the never-reset
# compaction policy on the local GLM-5.3-EXL3 lane.
#
# Called by the local mcode wrapper on EVERY launch (see README.md in this
# directory). It is the "permanent" half of the fix: config drift from any
# source (provider UI edits, restores, hand-editing) is repaired before any
# new session can start and cache a dangerous limit.
#
# Why the limit at all: the compactor's checkpoint request shares ZERO prefix
# cache with the resident session history (different system prompt), so the
# worst case is pair = 2 x trigger + output. The server's KV cache is
# 257,472 tokens. The trigger is a pure function of the configured limit:
#   trigger = limit - min(2 x 16384, limit/4)
# Default target 64000 -> trigger 48000 -> worst-case pair ~104K, 153K
# headroom: compaction ALWAYS fits, even with other resident sessions.
#
# Non-fatal by design: if enforcement fails, we warn loudly on stderr and
# still launch mcode — a broken enforcer must not brick the CLI.
set -uo pipefail

TARGET="${CONTINUOUS_COMPACTION_LIMIT:-64000}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SETTER="$HERE/set-glm53-context-limit.py"

if [ ! -f "$SETTER" ]; then
  echo "[compaction-enforcer] WARNING: setter not found at $SETTER; cannot enforce limit $TARGET." >&2
  exit 0
fi

OUT="$(python3 "$SETTER" --limit "$TARGET" 2>&1)"
RC=$?
case $RC in
  0) echo "$OUT" | grep -q "Already set" || echo "[compaction-enforcer] $OUT" >&2 ;;
  *) echo "[compaction-enforcer] ENFORCEMENT FAILED (rc=$RC): $OUT" >&2
     echo "[compaction-enforcer] Compaction may fail near the context ceiling until this is fixed." >&2
     ;;
esac
exit 0

#!/usr/bin/env bash
# keeper.sh — interval watchdog for the continuous-compaction policy.
#
# Run it from cron or a systemd timer (examples at the bottom of this file).
# Three checks, one line each:
#   1. DRIFT   — is the configured limit still the never-reset target?
#   2. FAILURES— did any session log context_compaction_failed recently?
#   3. STALE   — reminder: the limit is cached at session start; any session
#                that started before a limit change keeps the OLD limit until
#                restarted. Failed compaction in a running session after a
#                config fix means exactly that: restart it.
#
# Exit codes: 0 healthy, 1 needs attention (drift or fresh failures).
set -uo pipefail

TARGET="${CONTINUOUS_COMPACTION_LIMIT:-64000}"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOGS=~/.minimax/v2/observability/logs
RC=0

echo "== [keeper $(date -u +%FT%TZ)] =="

echo "-- 1. configured limit (target $TARGET) --"
OUT="$(python3 "$HERE/set-glm53-context-limit.py" --limit "$TARGET" --dry-run 2>&1)"
if echo "$OUT" | grep -q "Already set"; then
  echo "ok: limit.context == $TARGET (compaction trigger at ~$((TARGET - (32768 < TARGET/4 ? 32768 : TARGET/4))) tokens)"
else
  echo "DRIFT: $OUT"
  echo "fix:  python3 $HERE/set-glm53-context-limit.py --limit $TARGET"
  RC=1
fi

echo "-- 2. compaction failures in runtime logs (last 24h) --"
FAILS="$(find "$LOGS" -name 'runtime-*.log' -mmin -1440 -print0 2>/dev/null \
  | xargs -0 -r grep -h "context_compaction_failed" 2>/dev/null)"
if [ -z "$FAILS" ]; then
  echo "ok: no compaction failures in the last 24h"
else
  echo "attention: $(echo "$FAILS" | wc -l) failure event(s):"
  echo "$FAILS" | grep -oE '"session_id":"[^"]*"|"error_code":"[^"]*"' | sort | uniq -c | sort -rn | head -8
  echo "reminder: the limit is cached at session start. A session failing after"
  echo "a config fix is running on the OLD cached limit -> restart that session."
  RC=1
fi

exit $RC

# ---------------------------------------------------------------------------
# Interval wiring (pick ONE; neither is installed by this file):
#
#   cron, every 30 minutes:
#     */30 * * * *  /path/to/pack/compaction-fix/keeper.sh >> /tmp/mcode-compaction-keeper.log 2>&1
#
#   systemd user timer (systemctl --user enable --now mcode-compaction-keeper.timer):
#     ~/.config/systemd/user/mcode-compaction-keeper.timer:
#       [Timer]
#       OnBootSec=10min
#       OnUnitActiveSec=30min
#     ~/.config/systemd/user/mcode-compaction-keeper.service:
#       [Service]
#       Type=oneshot
#       ExecStart=/path/to/pack/compaction-fix/keeper.sh
# ---------------------------------------------------------------------------

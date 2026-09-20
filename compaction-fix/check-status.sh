#!/usr/bin/env bash
# Check the state of the context-compaction fix on this machine.
# Prints: configured limit, trigger math, latest compaction outcomes from the
# runtime logs, and whether a restart is needed for the limit to apply.
set -uo pipefail

CONFIG="$HOME/.minimax/config.yaml"
LOGS="$HOME/.minimax/v2/observability/logs"

echo "== configured limit =="
python3 - "$CONFIG" <<'EOF'
import sys, yaml
try:
    cfg = yaml.safe_load(open(sys.argv[1]))
    m = cfg["custom_provider"]["glm53"]["models"]["GLM-5.3-EXL3"]
    ctx = m["limit"]["context"]
    out = m["limit"]["output"]
    reserve = 16384
    trigger = ctx - min(2 * reserve, ctx // 4)
    pair = 2 * trigger + 8192  # worst case: resident history + checkpoint + output
    target = int(__import__("os").environ.get("CONTINUOUS_COMPACTION_LIMIT", "64000"))
    print(f"limit.context={ctx}  limit.output={out}")
    print(f"compaction trigger ≈ {trigger} estimated tokens (ctx - min(2*16384, ctx/4))")
    print(f"worst-case compaction pair ≈ {pair} tokens vs 257,472-token KV cache")
    if ctx <= target:
        print(f"CONTINUOUS ({ctx//1000}K: never-reset policy, pair fits with {257472-pair} headroom)")
    elif ctx <= 128000:
        print(f"FIXED (single-session safe) but below never-reset target {target} —")
        print(f"  run: python3 set-glm53-context-limit.py --limit {target}")
    else:
        print("DANGEROUS — compaction near the ceiling CANNOT fit the KV cache.")
except Exception as e:
    print(f"could not read config: {e}")
EOF

echo
echo "== latest compaction outcomes (all sessions, newest last) =="
grep -h -oE '"event":"context_compaction_checkpoint_attempt_settled".*?"outcome":"[a-z]+"' \
  "$LOGS"/runtime-*.log 2>/dev/null \
  | grep -oE '"input_message_count":[0-9]+|"outcome":"[a-z]+"' \
  | paste - - 2>/dev/null | tail -8
echo
echo "NOTE: the model limit is read when a session starts. If the limit above"
echo "changed after the current session began, restart MCode for it to apply."

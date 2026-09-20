# Context-Compaction Repair for MCode on local vLLM (GLM-5.3-EXL3)

Diagnosis and fix for the `INVALID_CHECKPOINT` compaction failures that killed a
7.7-hour MCode session at 7% remaining context on 2026-09-19.

## Symptom

Automatic context compaction fired repeatedly as the session approached the
ceiling and failed **every time — 28 failed attempts in total** across the
session's 12:40–20:37 lifetime (from
`~/.minimax/v2/observability/logs/runtime-*.log`). The final burst (20:19–20:37)
is representative:

```
context_compaction_checkpoint_attempt_settled ... input_message_count: 435-442 ... outcome: "failed", duration_ms: 21529-27202
context_compaction_failed ... stop_reason: "error", output_tokens: 0, error_code: "INVALID_CHECKPOINT", error_stage: "llm_checkpoint"
```

All 28 attempts ended with **0 output tokens**; not one succeeded. The session
then hard-stalled with ~7% context left and had to be abandoned.

## Server facts (read from vLLM `/metrics`)

| Setting | Value |
|---|---|
| Model | GLM-5.3-EXL3 (3.0 bpw, abliterated), TP=4 on 4× DGX Spark (GB10, arm64) |
| `max_model_len` | 200,000 tokens |
| KV cache | **257,472 tokens** (fp8, block 64, 4,023 GPU blocks) |
| `gpu_memory_utilization` | 0.75 |
| Prefix caching | **enabled** |
| Max concurrent max-length requests | ~1.29 |

## Root cause

The compactor sends the **entire session history** to the model to produce the
checkpoint (all 440–442 messages, ≈190 K tokens). With the provider context
limit configured at 200,000 (equal to `max_model_len`):

1. The compaction trigger only fires at ~150 K estimated tokens
   (`contextWindow − min(2×reserveTokens, contextWindow/4)`, `reserveTokens` = 16,384 —
   see `packages/agent-modules/context-manager/src/provider-budget.ts`).
2. The checkpoint request uses a **different system prompt** (checkpoint
   instructions), so it shares **zero prefix-cache blocks** with the resident
   session history. It needs its own ~190 K fresh KV blocks.
3. The session's own ~190 K blocks are still resident (prefix cache), so total
   demand is ≈ 2×190 K + 8 K output ≈ **388 K tokens against a 257 K cache**.
4. The server refuses/aborts the request after ~22 s → 0 output tokens →
   `INVALID_CHECKPOINT`. At a 200 K configured limit this failure is
   **structurally guaranteed** — the pair can never fit.

## Evidence: two-size adversarial probe

`ckpt-probe.py` sends checkpoint-style requests directly to the vLLM endpoint:

| Probe | Prompt tokens | Result |
|---|---|---|
| Small | 4,054 | **OK in 24.2 s** — model produced a valid structured checkpoint |
| Large, alone | 136,054 | **OK in 224.5 s** (~606 tok/s prefill) — valid checkpoint |

Neither the checkpoint prompt nor request size alone fails. The model cooperates
and a 144 K request fits the KV cache when it is the only large request. The
production failure is the **concurrency/pinning** case: checkpoint request +
resident session history > KV cache.

## Fix

Lower the provider context limit so the worst-case pair fits in the 257 K cache:

```yaml
# ~/.minimax/config.yaml
custom_provider:
  glm53:
    models:
      GLM-5.3-EXL3:
        limit:
          context: 128000   # was 200000
          output: 8192
```

Arithmetic with the new limit:

- Trigger: 128 K − min(2×16,384, 128 K/4) = **96 K** estimated tokens
- Worst case at trigger: 96 K (resident session) + 96 K + 8 K (checkpoint
  request) = **200 K < 257 K**, with 57 K headroom

Why 128 K specifically:

- It is the honest effective ceiling for a **self-compacting** agent on this
  server: any limit near 200 K makes the compaction pair (≈2×L) exceed the KV
  pool, so compaction can never succeed near the ceiling.
- It matches the runtime's own `contextWindowFallback` default (128,000) in
  `packages/agent-modules/context-manager/src/settings.ts`.
- Raising `gpu_memory_utilization` (server restart) grows the pool to ~330 K at
  best — still short of the ~390 K a 200 K dual-tenant pair needs. Documented
  as the server-side option; not required for this fix.

Apply it surgically (backs up the config first):

```bash
python3 set-glm53-context-limit.py --limit 128000
```

## Deployment note: the limit is cached per session

The provider context limit is read when a session **starts**. Changing
`config.yaml` does not affect an already-running session — verified on this
machine: a continuation session crossed the *new* 96 K trigger line (104 K
input tokens on its latest call) with **zero** compaction events in its runtime
log, proving it was still running on the old 200 K budget. Practical
consequences:

- Apply the fix, then **restart MCode**; new sessions pick up the 128 K limit.
- `check-status.sh` (this directory) prints the configured limit, the trigger
  math, and the latest compaction outcomes — run it after any config change.

## Verify

1. Config parses and only the intended number changed:
   `python3 -c "import yaml;print(yaml.safe_load(open('$HOME/.minimax/config.yaml'))['custom_provider']['glm53']['models']['GLM-5.3-EXL3']['limit'])"`
2. In a session started **after** the fix, on the next automatic compaction
   trigger the runtime log must flip from `outcome":"failed"` to
   `outcome":"succeeded"`:
   ```bash
   bash check-status.sh        # or:
   grep -h "context_compaction" ~/.minimax/v2/observability/logs/runtime-*.log | tail
   ```
3. With the companion context-meter patch (see `../patches/`) the status line
   shows remaining headroom recover after compaction instead of draining to 7%.

## Files

- `set-glm53-context-limit.py` — surgical, idempotent config editor (backup + verify)
- `ckpt-probe.py` — the two-size probe used to isolate the root cause
- `check-status.sh` — current limit, trigger math, and latest compaction outcomes

# keys-MiniMax-Code-CLI-Browser-Scroll-Context-Enhancement-Pack-with-Jev-Ultrafast-Integration

A pack of validated enhancements for the **MiniMax Code (MCode) CLI**, built and
battle-tested on a 4× NVIDIA DGX Spark (GB10, arm64) running a **local
GLM-5.3-EXL3 3.0 bpw (abliterated)** model through vLLM — no cloud API, $0
token cost.

## What's in the pack

| Component | What it does | Status |
|---|---|---|
| [`patches/0001`](patches/0001-tui-transcript-scrollbar.patch) | Interactive scrollbar for the fullscreen transcript viewport (three-column grab target, thumb-centering drags) | Validated on fork; upstream issue [#217](https://github.com/MiniMax-AI/minimax-code/issues/217) |
| [`patches/0002`](patches/0002-tui-context-meter-status-item.patch) | Opt-in status-line context gauge (`Context ▕██████░░▏ 77% left`) with thresholds + minimal fallback | Validated on fork; upstream issue [#216](https://github.com/MiniMax-AI/minimax-code/issues/216) |
| [`compaction-fix/`](compaction-fix/README.md) | Root cause + repair of the `INVALID_CHECKPOINT` auto-compaction failures on local vLLM (KV dual-tenancy); surgical config script + probe | **Applied and verified on this machine** |
| [`jev-ultrafast/`](jev-ultrafast/README.md) | Jev Ultrafast fast browser agent wired for arm64 (TypeSafe skill for the `minimax-code` agent target, snap Chromium + Playwright arm64, local text model) | Installed on this machine; TypeSafe key pending |
| [`playwright-mcp/`](playwright-mcp/README.md) | Microsoft Playwright MCP as MCode MCP tools (`~/.minimax/mcp.json` / `.mcp.json`), arm64 browser notes, security gates | Documented; ready to enable |
| [`performance/`](performance/ledger-2026-09-19.md) | Real usage ledger (the runtime's own sqlite accounting) + timed probes + a methodology for validating agent performance claims | Live data + reproducible collector |

## Why this pack exists

The two TUI patches were built as upstream contributions. PR creation from this
account is blocked on `MiniMax-AI/minimax-code`, so both shipped as **issues
#216/#217** with validated branches on the fork
(`drowzeys/minimax-code`: `feat/tui-context-meter`,
`feat/tui-transcript-scrollbar`). This pack makes all of the work — plus the
local-stack repairs that upstream will never need (arm64 browsers, local-vLLM
compaction, real usage data) — installable in one place, independent of
upstream timing.

## Apply

```bash
# 1. TUI patches (against the MiniMax Code source tree, MIT)
git am patches/0001-tui-transcript-scrollbar.patch
git am patches/0002-tui-context-meter-status-item.patch

# 2. Compaction repair for local vLLM serving (see compaction-fix/README.md)
python3 compaction-fix/set-glm53-context-limit.py --limit 128000

# 3. Playwright MCP (see playwright-mcp/README.md)
npx playwright install chromium   # arm64 real-Chromium path

# 4. Performance ledger, reproduced from your own runtime
python3 performance/collect-usage.py --day $(date +%F)
```

## Highlights

- **The compaction bug that kills long sessions on local vLLM is solved.**
  The compactor's checkpoint request (full history, different system prompt →
  zero prefix-cache sharing) plus the resident session history exceeded the
  257 K-token KV cache — structurally guaranteed to fail at a 200 K configured
  limit. Two-size adversarial probes proved it; the fix (128 K limit → trigger
  at 96 K → worst-case pair 200 K < 257 K) is applied and verified. Full
  analysis in [`compaction-fix/`](compaction-fix/README.md).
- **Real numbers, not claims.** 266 calls / 23.8 M input / 177 K output tokens
  across one day of heavy agent work, straight from the runtime's own ledger —
  including the 7.7-hour session that died at 7% context before the fix, and
  the ~606 tok/s prefill measurement for 136 K-token prompts.
- **arm64 honesty.** No Google Chrome on arm64 Linux; the pack documents the
  snap-Chromium + Playwright-arm64 reality and wires Jev Ultrafast and
  Playwright MCP accordingly.

See [`ATTRIBUTION.md`](ATTRIBUTION.md) for component provenance and licenses.

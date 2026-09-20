# MCode Continuous Context, Browser & Local Decision Enhancement Pack

Repository: `keys-mcode-continuous-context-browser-decision-enhancement-pack`

A pack of validated enhancements for the **MiniMax Code (MCode) CLI**, built and
battle-tested on a 4× NVIDIA DGX Spark (GB10, arm64) running a **local
GLM-5.3-EXL3 3.0 bpw (abliterated)** model through vLLM — no cloud API, $0
token cost.

## What's in the pack

| Component | What it does | Status |
|---|---|---|
| [`patches/0001`](patches/0001-tui-transcript-scrollbar.patch) | Interactive scrollbar for the fullscreen transcript viewport (three-column grab target, thumb-centering drags) | Validated on fork; upstream issue [#217](https://github.com/MiniMax-AI/minimax-code/issues/217) |
| [`patches/0002`](patches/0002-tui-context-meter-status-item.patch) | Opt-in status-line context gauge (`Context ▕██████░░▏ 77% left`) with thresholds + minimal fallback | Validated on fork; upstream issue [#216](https://github.com/MiniMax-AI/minimax-code/issues/216) |
| [`patches/0003`](patches/0003-continuous-context-renewal-25-percent.patch) | Continuous context renewal after 25% utilization, recurring compaction trigger, and regression coverage | Validated locally: 82 tests pass |
| [`compaction-fix/`](compaction-fix/README.md) | Root cause + repair of the `INVALID_CHECKPOINT` auto-compaction failures on local vLLM (KV dual-tenancy), now in **never-reset mode**: 64 K limit → trigger ~48 K → worst-case pair ~104 K vs the 257 K KV cache, enforced on **every launch** by the local mcode wrapper, plus an interval `keeper.sh` watchdog | Enforcement + math verified live 2026-09-20; **limit is cached per session — restart MCode to activate**; first post-restart successful auto-compaction pending |
| [`jev-ultrafast/`](jev-ultrafast/README.md) | Structured browser agent on the **verified arm64 CDP lane** — local djev-spark policy + local GLM-5.3-EXL3 text leg; Syntra client included for adaptive routing/feedback | djev-spark-compatible `/v1/systemone` wiring added; cloud TypeSafe is opt-in |
| [`Syntra`](https://github.com/ashhart/Syntra) + [`djev-spark`](https://github.com/mmastrac/djev-spark) | Local decision infrastructure and adaptive policy credits used by the browser/agent stack | Checked out for local integration; model serving remains separately deployable |
| [`playwright-mcp/`](playwright-mcp/README.md) | Microsoft Playwright MCP as MCode MCP tools (`~/.minimax/mcp.json` / `.mcp.json`), arm64 browser notes, security gates | Documented; ready to enable |
| [`browser-cdp/`](browser-cdp/README.md) | The measured CDP lane for `browser-harness` on arm64: Playwright Chromium 153 headless + `--no-sandbox` (AppArmor makes it mandatory) + `BU_CDP_URL` attach; snap Chromium ruled out — confinement blocks CDP entirely | **Verified on this machine 2026-09-20**; `smoke-test.sh` PASS |
| [`vision-tools/`](vision-tools/README.md) | Eyes for the text-only local lane: `analyze_image` (door 2, files on disk) + `vision_proxy` (door 1, chat attachments); local VLM only, the brain sees words never pixels; pattern from tonyd2wild/dsh (MIT) | Ported; failure paths verified live (endpoint-naming errors, degrade-not-throw, byte-identical pass-through); **no live VLM on this box yet — validate before use** |
| [`performance/`](performance/ledger-2026-09-19.md) | Real usage ledger (the runtime's own sqlite accounting) + timed probes + a methodology for validating agent performance claims | Live data + reproducible collector |
| [`container/`](container/README.md) + [`Dockerfile`](Dockerfile) | Pre-built arm64 GHCR image: official [@minimax-ai/code](https://www.npmjs.com/package/@minimax-ai/code) 0.4.12 overlaid with the patched bundles + arm64 Playwright Chromium + pack tooling | Built & smoke-tested on GitHub's arm64 runner → `ghcr.io/drowzeys/keys-mcode-continuous-context-browser-decision-enhancement-pack` |

## Why this pack exists

The TUI patches were built as upstream contributions. The pack also carries the
continuous-renewal patch and a maintained reapply hook, so an official MCode
update can be rebuilt with the enhancements automatically. This pack makes all
of the work — plus the
local-stack repairs that upstream will never need (arm64 browsers, local-vLLM
compaction, real usage data) — installable in one place, independent of
upstream timing.

## One-shot apply recipe

```bash
MCODE_SOURCE_TREE=/path/to/minimax-code ./install-one-shot.sh
```

The installer applies all compatible MCode patches, installs the durable
launch-time compaction enforcer, configures the 64K local-vLLM ceiling, and
installs `~/.local/bin/mcode-enhanced`. Launching through that wrapper checks
the active MCode release and automatically reapplies/rebuilds the pack after
an update. It preserves user config and does not install credentials.

For a nonstandard installation, set the official launcher and source paths:

```bash
MCODE_REAL_BIN=/path/to/official/mcode \
MCODE_SOURCE_TREE=/path/to/minimax-code \
  ~/.local/bin/mcode-enhanced
```

Manual steps, when needed:

```bash
# TUI + continuous context patches (against the MiniMax Code source tree, MIT)
git am patches/0001-tui-transcript-scrollbar.patch
git am patches/0002-tui-context-meter-status-item.patch
git apply patches/0003-continuous-context-renewal-25-percent.patch

# Compaction repair + never-reset mode for local vLLM serving
python3 compaction-fix/set-glm53-context-limit.py --limit 64000
bash compaction-fix/check-status.sh

# Playwright MCP (see playwright-mcp/README.md)
npx playwright install chromium   # arm64 real-Chromium path

# Verified browser CDP lane (see browser-cdp/README.md)
./browser-cdp/smoke-test.sh          # launches + verifies end-to-end, PASS/FAIL

# Vision tools for the text-only lane (needs a local VLM endpoint; see
#    vision-tools/README.md — read its Status section first)
./vision-tools/backends/ollama.sh    # then: python3 vision-tools/analyze_image.py <img>

# Performance ledger, reproduced from your own runtime
python3 performance/collect-usage.py --day $(date +%F)

# Or skip all of it — pull the pre-built image (arm64)
docker pull ghcr.io/drowzeys/keys-mcode-continuous-context-browser-decision-enhancement-pack:latest
```

Upstream MCode itself: [MiniMax-AI/minimax-code](https://github.com/MiniMax-AI/minimax-code)
(source, MIT) / [@minimax-ai/code on npm](https://www.npmjs.com/package/@minimax-ai/code)
(official releases). The pack's patches and image sit on top of 0.4.12.

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
  Playwright MCP accordingly. Measured further on 2026-09-20: snap Chromium
  is a **CDP dead end** (`browser-harness --doctor`: *Snap confinement
  prevents CDP binding*), so the browser lane is now settled by measurement —
  Playwright's arm64 Chromium, headless, `--no-sandbox` (mandatory under
  Ubuntu 24.04+ AppArmor), attached via `BU_CDP_URL`
  ([`browser-cdp/`](browser-cdp/README.md), verified end-to-end).

See [`ATTRIBUTION.md`](ATTRIBUTION.md) for component provenance and licenses.

## Credits and thanks

With sincere thanks to the original creators and maintainers whose work made
this pack possible: the [MiniMax Code team](https://github.com/MiniMax-AI/minimax-code),
[pi-mono](https://github.com/badlogic/pi-mono), [Syntra](https://github.com/ashhart/Syntra),
[djev-spark](https://github.com/mmastrac/djev-spark), [Jev Ultrafast](https://github.com/browser-use/jev-ultrafast),
[TypeSafe](https://github.com/typesafe-ai/skills), [Microsoft Playwright](https://github.com/microsoft/playwright),
[Playwright MCP](https://github.com/microsoft/playwright-mcp), [browser-harness](https://github.com/browser-use/browser-harness),
[DeepSeek-Harness-Browser](https://github.com/tonyd2wild/DeepSeek-Harness-Browser),
[DeepSeek-Harness-Vision-Tools](https://github.com/tonyd2wild/DeepSeek-Harness-Vision-Tools),
the [vLLM](https://github.com/vllm-project/vllm) project, and the maintainers of
Node.js, pnpm, Docker, GitHub Actions, and GHCR. Their licenses, source links,
and the specific methods used are documented in [`ATTRIBUTION.md`](ATTRIBUTION.md).

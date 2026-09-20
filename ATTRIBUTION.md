# Attribution and credits

This pack is an integration and documentation layer. It preserves upstream
licenses and names the projects, source repositories, and methods that made
each feature possible. No third-party credentials, model weights, or private
runtime data are redistributed.

- **MiniMax Code** (`minimax-code`) — MIT License, Copyright (c) 2026 MiniMax
  Code. The three patches in `patches/` are derived from this codebase and carry
  its license; the upstream project is
  https://github.com/MiniMax-AI/minimax-code (contribution issues #216, #217;
  validated branches on the `drowzeys` fork). Official distribution:
  [@minimax-ai/code on npm](https://www.npmjs.com/package/@minimax-ai/code)
  (v0.4.12 at the time of this pack). The container image overlays this
  pack's patched bundles onto that official release; no upstream binaries are
  modified beyond the two documented patches.
- **pi-mono** — https://github.com/badlogic/pi-mono, including the vendored
  `@earendil-works/pi-agent-core`, `pi-ai`, `pi-coding-agent`, and `pi-tui`
  package architecture used by MCode's agent/runtime layers. The compaction
  hook follows the existing before-LLM-call lifecycle and message-replacement
  contracts rather than replacing them.
- **Syntra** — https://github.com/ashhart/Syntra. Decision-engine concepts,
  capsule model, `/decide` + `/feedback` lifecycle, adaptive routing, delayed
  feedback, persistence, replay, and promotion-gate methods are credited to
  Syntra. Its source is not vendored into this pack; the local checkout is an
  optional deployment dependency.
- **djev-spark** — https://github.com/mmastrac/djev-spark. The local
  DiffusionGemma NVFP4 structured-decision server and its Jev-compatible
  `POST /v1/systemone` contract are credited to this project. The pack's
  browser adapter defaults to this local endpoint instead of the cloud Jev
  API; djev-spark itself is not copied into the image.
- **Jev Ultrafast** — https://github.com/browser-use/jev-ultrafast (browser-use).
  The indexed browser action-space, operation/target split, stale-page guards,
  one-decision-cycle loop, and text-helper handoff are credited to this
  project. The integration is documented in `jev-ultrafast/`; the upstream
  project is not redistributed here.
- **TypeSafe / typesafe-ai skills** — https://github.com/typesafe-ai/skills —
  installed through its official installer for the `minimax-code` agent target;
  not redistributed here.
- **Playwright MCP** — https://github.com/microsoft/playwright-mcp (Microsoft).
  Wired via configuration documented in `playwright-mcp/`; not redistributed
  here.
- **DeepSeek-Harness-Browser** — https://github.com/tonyd2wild/DeepSeek-Harness-Browser
  (MIT, Copyright (c) 2026 tonyd2wild). The tool-surface mapping and the
  no-iframe rationale documented in `browser-cdp/` are pattern-ported from it;
  no upstream code redistributed. The MCode-side CDP mechanics it maps onto
  come from browser-harness (below).
- **DeepSeek-Harness-Vision-Tools** — https://github.com/tonyd2wild/DeepSeek-Harness-Vision-Tools
  (MIT, Copyright (c) 2026 tonyd2wild). `vision-tools/` is a from-scratch
  adaptation of its two-door pattern (`analyze_image` + vision proxy) for the
  MCode stack; its architecture and safety rules are preserved and credited;
  no upstream code redistributed verbatim.
- **browser-harness** — https://github.com/browser-use/browser-harness
  (browser-use). The CDP control skill shipped with the local runtime;
  `browser-cdp/` documents attaching it on arm64 via its `BU_CDP_URL`
  endpoint mode; not redistributed here.
- **vLLM** — https://github.com/vllm-project/vllm. The local serving,
  OpenAI-compatible endpoint, KV-cache measurements, prefix-cache diagnosis,
  and arm64/DGX Spark deployment assumptions are based on vLLM and its
  documented runtime behavior. The model server is external to this pack.
- **Playwright** — https://github.com/microsoft/playwright. The arm64
  Chromium installation and CDP/browser validation path use Playwright's
  tooling; no Playwright source is redistributed.
- **Node.js, pnpm, Docker, GitHub Actions, and GHCR** — the build, patch,
  packaging, CI, and distribution mechanisms are provided by these projects'
  standard tooling and services.

## Methods and original pack work

- **Continuous context renewal** — this pack's implementation combines
  proactive compaction at 25% utilization, recurring message replacement,
  a safe local-vLLM ceiling, launch-time configuration enforcement, and a
  watchdog. The threshold and safety arithmetic are original integration work
  for this local deployment; it does not claim to be an upstream MCode default.
- **Context progress display** — the context percentage, remaining-headroom
  gauge, compaction-floor marker, and running/failed indicators are pack-level
  TUI integration work built on MCode's status-line contracts.
- **Transcript scrollbar** — pack-level TUI work documented in patches 0001 and
  0002, based on MCode's existing rendering and layout contracts.
- **Measurement and validation** — performance figures and smoke-test results
  were collected on the local machine from its own runtime accounting and
  local services; they are not claims made by the upstream projects.
- **GLM-5.3-EXL3 (abliterated)** — self-hosted via vLLM on 4× DGX Spark for
  all measurements in `performance/`; no vendor API was used (cost $0).
- All usage data in `performance/` was collected from this machine's own
  MCode runtime accounting, read-only.

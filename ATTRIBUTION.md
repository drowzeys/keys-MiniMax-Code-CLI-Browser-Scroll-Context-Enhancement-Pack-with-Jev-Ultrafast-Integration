# Attribution

- **MiniMax Code** (`minimax-code`) — MIT License, Copyright (c) 2026 MiniMax
  Code. The two patches in `patches/` are derived from this codebase and carry
  its license; the upstream project is
  https://github.com/MiniMax-AI/minimax-code (contribution issues #216, #217;
  validated branches on the `drowzeys` fork). Official distribution:
  [@minimax-ai/code on npm](https://www.npmjs.com/package/@minimax-ai/code)
  (v0.4.12 at the time of this pack). The container image overlays this
  pack's patched bundles onto that official release; no upstream binaries are
  modified beyond the two documented patches.
- **Jev Ultrafast** — https://github.com/browser-use/jev-ultrafast (browser-use).
  Referenced and integrated via its own project instructions; not redistributed
  here.
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
- **GLM-5.3-EXL3 (abliterated)** — self-hosted via vLLM on 4× DGX Spark for
  all measurements in `performance/`; no vendor API was used (cost $0).
- All usage data in `performance/` was collected from this machine's own
  MCode runtime accounting, read-only.

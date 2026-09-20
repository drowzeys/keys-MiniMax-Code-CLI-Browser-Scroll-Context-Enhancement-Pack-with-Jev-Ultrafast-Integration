# Attribution

- **MiniMax Code** (`minimax-code`) — MIT License, Copyright (c) 2026 MiniMax
  Code. The two patches in `patches/` are derived from this codebase and carry
  its license; the upstream project is
  https://github.com/MiniMax-AI/minimax-code (contribution issues #216, #217;
  validated branches on the `drowzeys` fork).
- **Jev Ultrafast** — https://github.com/browser-use/jev-ultrafast (browser-use).
  Referenced and integrated via its own project instructions; not redistributed
  here.
- **TypeSafe / typesafe-ai skills** — https://github.com/typesafe-ai/skills —
  installed through its official installer for the `minimax-code` agent target;
  not redistributed here.
- **Playwright MCP** — https://github.com/microsoft/playwright-mcp (Microsoft).
  Wired via configuration documented in `playwright-mcp/`; not redistributed
  here.
- **GLM-5.3-EXL3 (abliterated)** — self-hosted via vLLM on 4× DGX Spark for
  all measurements in `performance/`; no vendor API was used (cost $0).
- All usage data in `performance/` was collected from this machine's own
  MCode runtime accounting, read-only.

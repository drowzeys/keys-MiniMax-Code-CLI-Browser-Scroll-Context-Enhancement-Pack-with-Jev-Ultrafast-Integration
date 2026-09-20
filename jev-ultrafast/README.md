# Jev Ultrafast Integration (arm64 DGX Spark)

Wiring [browser-use/jev-ultrafast](https://github.com/browser-use/jev-ultrafast)
— the fast browser agent (TypeSafe policy layer + small text LLM driving a real
browser over CDP) — into the MCode agent stack on arm64 Linux, where the usual
"just install Chrome" instructions do not apply.

## What was set up on this machine (2026-09-19)

1. **TypeSafe skill installed for the MCode agent target.** The
   `typesafe-ai/skills` installer (`npx skills add typesafe-ai/skills --skill
   typesafe-ai`) supports a `--agent` flag; the correct target in its catalog
   is **`minimax-code`**. Result: the skill lands in
   `~/.minimax/skills/typesafe-ai` and is exposed to sessions as the
   `typesafe-ai` skill (System One typed judgments — used by Jev as its policy
   layer).
2. **Jev project cloned** to `~/jev-ultrafast`; Python dependencies installed
   per its project instructions.
3. **Browser reality on arm64 Linux:**
   - Google does not ship arm64 Linux Chrome — the common `install Chrome`
     prerequisite is impossible on GB10/DGX Spark.
   - **Snap Chromium 152 (Canonical)** provides the real desktop-class browser
     (`snap install chromium`; verified installed).
   - **Playwright's arm64 builds** (`chromium-1243` /
     `chromium_headless_shell-1243` via `npx playwright install chromium`)
     provide the CDP-automation path; Playwright ships real arm64 Linux
     Chromium, unlike Google.
4. **Text model**: the local vLLM endpoint serving GLM-5.3-EXL3
   (`max_model_len` 200,000) is alive and usable as Jev's small-LLM backend;
   point Jev's text-model config at the local OpenAI-compatible endpoint.

## Notes and caveats

- A live desktop exists on this box (`:0`), so headed browser flows are
  possible; headless CDP flows go through the Playwright arm64 build.
- The `browser-harness` skill (CDP control: click/type/navigate, logged-in
  sessions) is the MCode-side counterpart for interactive work; Jev is the
  policy/fast-path layer on top.
- TypeSafe API key: not yet configured on this machine — Jev's policy layer
  needs it for full operation (get one via the TypeSafe flow in the
  `typesafe-ai` skill).
- Related: `../playwright-mcp/` wires Microsoft's Playwright MCP server into
  MCode so the agent itself gets browser tools without Jev.
